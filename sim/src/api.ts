/**
 * window.pure — Flutter 와 시뮬레이터 사이의 유일한 문 (PRD 부록 B).
 *
 * STEP 3 이후 sim/ 내부는 봉인된다. 바깥에서 보이는 것은 이 파일이 노출하는 것뿐이고,
 * 계약 변경은 사람이 승인한다.
 *
 * 이 파일이 지는 책임:
 *  1. 관절 이름 변환 (계약 head_tilt ↔ 내부 wrist_pitch). 빼먹으면 조용히 안 움직인다.
 *  2. 클립 모양 어댑터. 계약은 tracks 가 Record<Joint, Key[]> 인데 엔진 내부는 Track[] 이다.
 *  3. 들어오는 값 검증. 틀리면 던진다 — 조용히 0 으로 만들지 않는다.
 *  4. 이벤트를 Flutter(callHandler) 또는 postMessage(브라우저 테스트) 로 송출.
 */

import {
  VERSION,
  boot,
  capture,
  enableOrbit,
  getLimits,
  knownBehaviors,
  knownFaces,
  applyFace,
  buildBehaviorItem,
  playBehavior,
  playClipItem,
  playItems,
  setEventSink,
  setIdle,
  setView,
  stop,
  type SimEvent,
} from './runtime';
import { EASINGS, JOINT_NAMES, type EasingName, type JointName } from './engine/motion';
import type { Clip, Key, Track } from './engine/clip';
import { PUBLIC_JOINTS, TO_INTERNAL, isPublicJoint, type PublicJoint } from './joints';

// ------------------------------------------------------------------ 계약 타입

export interface PlaybackParams {
  speed?: number;
  amplitude?: number;
}

export interface PublicRecipeStep {
  behavior: string;
  speed?: number;
  amplitude?: number;
  repeat?: number;
  face?: string | null;
}

export interface PublicRecipe {
  steps: PublicRecipeStep[];
  loop?: boolean;
}

export interface PublicKey {
  t: number;
  value: number;
  easing?: EasingName;
}

export interface PublicClip {
  format: 'lelamp.clip/1';
  duration: number;
  tracks: Partial<Record<PublicJoint, PublicKey[]>>;
  face?: string | null;
}

export interface IdleParams extends PlaybackParams {
  behavior?: string;
}

// ------------------------------------------------------------------ 검증 보조

const fail = (msg: string): never => {
  throw new Error(`[pure] ${msg}`);
};

function num(value: unknown, name: string, lo: number, hi: number, fallback?: number): number {
  if (value === undefined || value === null) {
    if (fallback !== undefined) return fallback;
    return fail(`${name} 가 필요합니다`);
  }
  if (typeof value !== 'number' || !Number.isFinite(value)) return fail(`${name} 는 숫자여야 합니다`);
  if (value < lo || value > hi) return fail(`${name} 는 ${lo}~${hi} 범위여야 합니다 (받은 값: ${value})`);
  return value;
}

function checkBehavior(name: unknown): string {
  if (typeof name !== 'string') return fail('behavior 는 문자열이어야 합니다');
  if (!knownBehaviors().includes(name)) {
    return fail(`알 수 없는 동작: ${name} (허용: ${knownBehaviors().join(', ')})`);
  }
  return name;
}

function checkFace(name: unknown): string | null {
  if (name === undefined || name === null) return null;
  if (typeof name !== 'string') return fail('face 는 문자열이어야 합니다');
  if (!knownFaces().includes(name)) {
    return fail(`알 수 없는 얼굴: ${name} (허용: ${knownFaces().join(', ')})`);
  }
  return name;
}

// ------------------------------------------------------------------ 클립 어댑터

/**
 * 계약 모양 → 엔진 내부 Clip.
 *
 * 계약:   { format, duration, tracks: { head_tilt: [{t, value, easing}] } }
 * 내부:   { name, label, description, duration, loop, tracks: [{joint:'wrist_pitch', keys}] }
 *
 * 원본 parseClip 은 모르는 관절 이름을 조용히 0 트랙으로 바꿨다. 여기서는 던진다.
 */
function adaptClip(input: unknown): Clip {
  if (!input || typeof input !== 'object') return fail('clip 이 객체가 아닙니다');
  const c = input as Partial<PublicClip>;

  if (c.format !== 'lelamp.clip/1') {
    return fail(`지원하지 않는 clip format: ${String(c.format)} (기대: lelamp.clip/1)`);
  }
  const duration = num(c.duration, 'clip.duration', 0.1, 60);

  if (!c.tracks || typeof c.tracks !== 'object') return fail('clip.tracks 가 없습니다');

  for (const key of Object.keys(c.tracks)) {
    if (!isPublicJoint(key)) {
      return fail(`알 수 없는 관절: ${key} (허용: ${PUBLIC_JOINTS.join(', ')})`);
    }
  }

  const byInternal = new Map<JointName, Key[]>();
  for (const pub of PUBLIC_JOINTS) {
    const raw = c.tracks[pub];
    if (raw === undefined) continue;
    if (!Array.isArray(raw)) return fail(`clip.tracks.${pub} 는 배열이어야 합니다`);

    const keys: Key[] = raw.map((k, i) => {
      if (!k || typeof k !== 'object') return fail(`clip.tracks.${pub}[${i}] 가 객체가 아닙니다`);
      const easing = (k as PublicKey).easing ?? 'ease_in_out';
      if (!(easing in EASINGS)) {
        return fail(`알 수 없는 easing: ${easing} (허용: ${Object.keys(EASINGS).join(', ')})`);
      }
      return {
        t: num((k as PublicKey).t, `clip.tracks.${pub}[${i}].t`, 0, duration),
        value: num((k as PublicKey).value, `clip.tracks.${pub}[${i}].value`, -360, 360),
        easing: easing as EasingName,
      };
    });
    keys.sort((a, b) => a.t - b.t);
    byInternal.set(TO_INTERNAL[pub], keys);
  }

  if (byInternal.size === 0) return fail('clip.tracks 가 비었습니다');

  /*
   * 내부 Clip 은 다섯 관절 트랙이 전부 있어야 한다. 계약에서 생략된 관절은 "움직이지 않는다"
   * 는 뜻이므로 0 한 점을 둔다 — 원본의 조용한 0 트랙과 값은 같지만, 여기서는 생략이
   * 명시적 의도일 때만 그렇게 되고 이름 오타는 위에서 이미 걸린다.
   */
  const tracks: Track[] = JOINT_NAMES.map((joint) => ({
    joint,
    keys: byInternal.get(joint) ?? [{ t: 0, value: 0, easing: 'ease_in_out' as EasingName }],
  }));

  return {
    name: 'clip',
    label: 'clip',
    description: '',
    duration,
    // 계약에 loop 필드가 없다. 내부에서는 필수이고 샘플링의 wrap/clamp 를 바꾸므로 명시한다.
    loop: false,
    tracks,
  };
}

// ------------------------------------------------------------------ 이벤트 송출

function sendEvent(e: SimEvent): void {
  const handler = window.flutter_inappwebview;
  if (handler?.callHandler) {
    void handler.callHandler('pureEvent', e);
    return;
  }
  // 브라우저 테스트 — 같은 페이로드를 postMessage 로.
  window.postMessage(e, '*');
}

// ------------------------------------------------------------------ 공개 API

export interface PureApi {
  readonly ready: Promise<void>;
  playBehavior(name: string, p?: PlaybackParams): string;
  playRecipe(recipe: PublicRecipe, p?: PlaybackParams): string;
  playClip(clip: PublicClip, p?: PlaybackParams): string;
  setIdle(p: IdleParams): void;
  setFace(name: string): void;
  stop(): void;
  setView(v: { azimuth?: number; elevation?: number; distance?: number }): void;
  enableOrbit(on: boolean): void;
  capture(): string;
  limits(): Record<string, [number, number]>;
  behaviors(): string[];
  faces(): string[];
  readonly version: string;
}

export function install(canvas: HTMLCanvasElement, onProgress?: (p: unknown) => void): PureApi {
  setEventSink(sendEvent);

  const ready = boot({
    canvas,
    onProgress: onProgress as never,
  });

  const api: PureApi = {
    ready,

    playBehavior(name, p = {}) {
      return playBehavior(checkBehavior(name), {
        speed: num(p.speed, 'speed', 0.1, 4, 1),
        amplitude: num(p.amplitude, 'amplitude', 0.1, 3, 1),
      });
    },

    playRecipe(recipe, p = {}) {
      if (!recipe || !Array.isArray(recipe.steps)) return fail('recipe.steps 가 배열이 아닙니다');
      if (recipe.steps.length === 0) return fail('recipe.steps 가 비었습니다');
      if (recipe.steps.length > 6) return fail(`recipe.steps 는 6개 이하여야 합니다 (받은 수: ${recipe.steps.length})`);

      // 시그니처 배율 × 스텝 배율.
      const gSpeed = num(p.speed, 'speed', 0.1, 4, 1);
      const gAmp = num(p.amplitude, 'amplitude', 0.1, 3, 1);

      const items = recipe.steps.map((s, i) =>
        buildBehaviorItem(checkBehavior(s.behavior), {
          speed: gSpeed * num(s.speed, `steps[${i}].speed`, 0.5, 1.6, 1),
          amplitude: gAmp * num(s.amplitude, `steps[${i}].amplitude`, 0.4, 1.5, 1),
          repeat: num(s.repeat, `steps[${i}].repeat`, 1, 4, 1),
          face: checkFace(s.face),
        }),
      );
      return playItems(items, recipe.steps[0].behavior);
    },

    playClip(clip, p = {}) {
      const adapted = adaptClip(clip);
      const face = checkFace((clip as PublicClip)?.face);
      // 클립은 절대 각도라 amplitude 를 적용하지 않는다 (PRD 부록 D 결정). speed 만.
      return playClipItem(adapted, { speed: num(p.speed, 'speed', 0.1, 4, 1), face });
    },

    setIdle(p = {}) {
      setIdle({
        behavior: p.behavior === undefined ? undefined : checkBehavior(p.behavior),
        speed: p.speed === undefined ? undefined : num(p.speed, 'speed', 0.1, 4),
        amplitude: p.amplitude === undefined ? undefined : num(p.amplitude, 'amplitude', 0.1, 3),
      });
    },

    setFace(name) {
      const face = checkFace(name);
      if (face && !applyFace(face)) fail(`얼굴을 적용하지 못했습니다: ${name}`);
    },

    stop,

    setView(v) {
      setView({
        azimuth: v?.azimuth,
        elevation: v?.elevation,
        distance: v?.distance,
      });
    },

    enableOrbit,
    capture,
    limits: getLimits,
    behaviors: knownBehaviors,
    faces: knownFaces,
    version: VERSION,
  };

  return api;
}
