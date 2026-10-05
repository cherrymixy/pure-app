/**
 * 재생 런타임.
 *
 * 원본(_ref/pure-web)에서는 이 로직 전체가 React 컴포넌트(LeLampProvider.tsx) 안에 있었다.
 * 엔진 쪽 .ts 파일들은 상태 기계를 하나도 갖고 있지 않다 — LampSim 은 MuJoCo 배열만,
 * LampViewer 는 three.js 씬만 소유한다. 시계·재생 슬롯·큐·대기 모션·얼굴 선택은 전부
 * 여기서 새로 구현한다.
 *
 * 원본에서 반드시 가져와야 했던 것들(빼면 조용히 깨진다):
 *  - wall clock 을 0.1초로 클램프: 탭이 멈췄다 돌아올 때 한 프레임에 동작을 통째로 건너뛰는 것 방지
 *  - 물리 스텝 250 상한: 멈췄다 돌아온 뒤 mj_step 폭주 방지
 *  - LEAD_IN 0.8초: 반복 동작은 사이클 '위'의 자세에서 시작하므로, 현재 자세에서 부드럽게 진입
 *  - 플레이어 시작 자세로 sim.targets 사용(HOME 아님): 재생 중 끊어도 안 튄다
 *  - 뷰어 생성 직후 수동 resize(): 안 하면 three 가 기본 300×150 버퍼를 늘려 그려서 전체가 흐려진다
 *
 * 원본과 달라진 것:
 *  - 재생 시계를 물리 시계에서 분리했다. 원본은 t = lamp.time - t0 라서 물리를 안 돌리면
 *    시간이 멈췄다. 여기서는 clock += wall × speed 누산기 하나가 speed 의 유일한 적용 지점이다.
 *  - 얼굴 영상을 blob 으로 미리 받는다. Flutter 의 InAppLocalhostServer 는 HTTP Range 를
 *    지원하지 않아서 <video src="http://localhost:8080/...">가 WKWebView 에서 재생 거부된다.
 */

import { createLamp, type LampSim, type LoadProgress } from './engine/lamp';
import { LampViewer } from './engine/viewer3d';
import {
  PURE_DESK_ROBOT,
  retargetMotion,
  type CameraView,
  type FaceManifest,
} from './engine/robots';
import { BEHAVIORS, getBehavior } from './engine/behaviors';
import {
  JOINT_NAMES,
  MotionPlayer,
  cycleTime,
  type JointName,
  type Motion,
  type PartialPose,
  type Pose,
} from './engine/motion';
import { sampleClip, type Clip } from './engine/clip';
import { assetUrl } from './engine/paths';

export const VERSION = '0.1.0';

const LEAD_IN = 0.8;
/** 탭이 멈췄다 돌아와도 한 프레임에 0.1초 이상 진행하지 않는다. */
const MAX_WALL = 0.1;
/** 한 프레임에 돌릴 물리 스텝 상한. */
const MAX_STEPS = 250;

// ------------------------------------------------------------------ 이벤트

export type SimEvent =
  | { type: 'ready'; limits: Record<string, [number, number]>; behaviors: string[]; faces: string[] }
  | { type: 'playing'; id: string; duration: number; behavior: string }
  | { type: 'ended'; id: string }
  | { type: 'error'; message: string };

declare global {
  interface Window {
    flutter_inappwebview?: { callHandler(name: string, ...args: unknown[]): Promise<unknown> };
  }
}

let onEvent: (e: SimEvent) => void = () => {};

/** 이벤트 싱크를 갈아끼운다 (api.ts 가 Flutter/postMessage 로 연결). */
export const setEventSink = (sink: (e: SimEvent) => void): void => {
  onEvent = sink;
};

const emit = (e: SimEvent): void => {
  try {
    onEvent(e);
  } catch {
    // 싱크가 던져도 재생은 계속한다.
  }
};

// ------------------------------------------------------------------ 모듈 상태

let sim: LampSim | null = null;
let viewer: LampViewer | null = null;
let canvasEl: HTMLCanvasElement | null = null;

let faceManifest: FaceManifest = {};
/** 얼굴 이름('smile') → blob URL. */
const faceBlobs = new Map<string, string>();
/** 얼굴 이름('smile') → 파일명('smile.mp4'). */
const faceFiles = new Map<string, string>();
let defaultFaceName = 'neutral';

interface Item {
  /** 동작 이름, 또는 클립이면 'clip' */
  label: string;
  /** 명시적 얼굴 지정. null 이면 동작 이름으로 고른다. */
  face: string | null;
  speed: number;
  /** 재생 직전에 sim.targets 로 플레이어를 만든다. */
  motion: Motion | null;
  clip: Clip | null;
  /** 이 아이템을 끝낼 로컬 시각(초). Infinity 면 끝나지 않는다(대기 모션). */
  budget: number;
  player: MotionPlayer | null;
}

let queue: Item[] = [];
let current: Item | null = null;
/** 현재 아이템 안에서 흐른 시간. speed 가 이미 반영된 값. */
let localT = 0;
let currentId: string | null = null;
let playSeq = 0;

let idleSpec = { behavior: 'idle', speed: 1, amplitude: 1 };
let idleItem: Item | null = null;

let rafHandle = 0;
let lastFrame = 0;

// ------------------------------------------------------------------ 포즈 보조

const scalePose = (pose: PartialPose, amp: number): PartialPose => {
  const out: PartialPose = {};
  for (const [k, v] of Object.entries(pose)) out[k as JointName] = (v as number) * amp;
  return out;
};

/**
 * 진폭 배율.
 *
 * HOME 이 영벡터(behaviors.ts)라 "HOME 기준 편차"가 곧 "값 그 자체"다. 리타겟이 선형이라
 * 리타겟 전후 어디서 곱해도 결과가 같다. 반드시 MotionPlayer 를 만들기 *전에* 적용한다 —
 * player.target() 의 출력에 곱하면 lead-in 구간(현재 자세에서 블렌드하는 구간)까지
 * 배율이 걸려서 동작 시작마다 팔이 튄다.
 */
function scaleMotion(motion: Motion, amp: number): Motion {
  if (amp === 1) return motion;
  return {
    ...motion,
    keyframes: motion.keyframes.map((kf) => ({ ...kf, pose: scalePose(kf.pose, amp) })),
    overlays: (motion.overlays ?? []).map((o) => ({ ...o, amplitude: o.amplitude * amp })),
  };
}

// ------------------------------------------------------------------ 얼굴

const faceNameOf = (file: string): string => file.replace(/\.[^.]+$/, '');

/** 동작 이름에 맞는 얼굴 이름. 매핑이 없으면 기본 얼굴. */
function faceForBehavior(behavior: string): string {
  const file = faceManifest.behaviors?.[behavior] ?? faceManifest.default;
  return file ? faceNameOf(file) : defaultFaceName;
}

export const knownFaces = (): string[] => [...faceFiles.keys()];
export const knownBehaviors = (): string[] => BEHAVIORS.map((b) => b.name);

/** 얼굴 영상을 바꾼다. 알 수 없는 이름이면 false. */
export function applyFace(name: string): boolean {
  const url = faceBlobs.get(name);
  if (!url) return false;
  viewer?.setFace(url);
  return true;
}

/**
 * 얼굴 영상 7개를 미리 받아 blob URL 로 만든다.
 *
 * Flutter 의 로컬 서버가 HTTP Range 를 지원하지 않아서 <video src=http://...> 가
 * WKWebView 에서 재생을 거부한다. 전부 합쳐 3.1MB 라 통째로 받아도 부담이 없고,
 * 오히려 전환이 즉각적이 된다.
 */
async function loadFaces(manifestPath: string): Promise<void> {
  const manifestUrl = assetUrl(manifestPath);
  faceManifest = (await fetch(manifestUrl).then((r) => {
    if (!r.ok) throw new Error(`얼굴 매니페스트를 받지 못했습니다 (${r.status})`);
    return r.json();
  })) as FaceManifest;

  const files = new Set<string>();
  for (const f of Object.values(faceManifest.behaviors ?? {})) files.add(f);
  if (faceManifest.default) {
    files.add(faceManifest.default);
    defaultFaceName = faceNameOf(faceManifest.default);
  }

  await Promise.all(
    [...files].map(async (file) => {
      const url = new URL(file, manifestUrl).href;
      const res = await fetch(url);
      if (!res.ok) throw new Error(`얼굴 영상을 받지 못했습니다: ${file} (${res.status})`);
      const blob = await res.blob();
      const name = faceNameOf(file);
      faceFiles.set(name, file);
      faceBlobs.set(name, URL.createObjectURL(blob));
    }),
  );
}

// ------------------------------------------------------------------ 재생

/** 동작 하나를 재생 아이템으로. repeat 은 완료 횟수가 아니라 시간 예산으로 환산한다. */
export function buildBehaviorItem(
  name: string,
  opts: { speed?: number; amplitude?: number; repeat?: number; face?: string | null } = {},
): Item {
  const base = getBehavior(name); // 알 수 없는 이름이면 던진다
  const amp = opts.amplitude ?? 1;
  const repeat = Math.max(1, Math.round(opts.repeat ?? 1));
  const retargeted = retargetMotion(PURE_DESK_ROBOT, base);
  const scaled = scaleMotion(retargeted, amp);

  /*
   * 15종 중 6종(idle doze sleep sad sweep focus)은 loop: true 라 MotionPlayer.finished()
   * 가 영구히 false 다. repeat 을 완료 횟수로 세면 영원히 안 끝난다. 반대로 한 번만 도는
   * 동작을 repeat 만큼 반복하려면 loop 를 켜서 사이클을 이어 붙이는 쪽이 매끄럽다
   * (아이템을 여러 개로 쪼개면 반복마다 0.8초 lead-in 이 끼어든다).
   * 그래서 양쪽 다 "loop 로 돌리고 시간으로 끊는다"로 통일한다.
   */
  const loop = scaled.loop === true || repeat > 1;
  const motion: Motion = loop === scaled.loop ? scaled : { ...scaled, loop };
  const budget = LEAD_IN + repeat * cycleTime(motion);

  return {
    label: name,
    face: opts.face ?? null,
    speed: opts.speed ?? 1,
    motion,
    clip: null,
    budget,
    player: null,
  };
}

function buildClipItem(clip: Clip, opts: { speed?: number; face?: string | null }): Item {
  return {
    label: 'clip',
    face: opts.face ?? null,
    speed: opts.speed ?? 1,
    motion: null,
    clip,
    // 클립은 loop 를 끄고 한 번만 재생한다 (계약에 loop 필드가 없다 — 명시적으로 1회).
    budget: clip.duration,
    player: null,
  };
}

/** 아이템을 실제로 시작한다. 플레이어는 여기서 만든다 — 시작 자세가 '지금'이어야 하므로. */
function startItem(item: Item): void {
  if (!sim) return;
  current = item;
  localT = 0;

  if (item.motion) {
    // 시작 자세는 sim.targets — 명령된 현재 자세. 재생 중 끊어도 튀지 않는다.
    item.player = new MotionPlayer(item.motion, sim.targets, LEAD_IN);
  }

  applyFace(item.face ?? faceForBehavior(item.label));
}

function startIdle(): void {
  if (!sim) return;
  try {
    idleItem = buildBehaviorItem(idleSpec.behavior, {
      speed: idleSpec.speed,
      amplitude: idleSpec.amplitude,
    });
  } catch {
    idleItem = buildBehaviorItem('idle', { speed: idleSpec.speed, amplitude: idleSpec.amplitude });
  }
  idleItem.budget = Infinity;
  idleItem.player = new MotionPlayer(
    idleItem.motion!.loop ? idleItem.motion! : { ...idleItem.motion!, loop: true },
    sim.targets,
    LEAD_IN,
  );
  applyFace(faceForBehavior(idleItem.label));
  current = null;
  localT = 0;
}

/** 현재 아이템이 끝났을 때 — 다음 아이템, 없으면 대기 모션으로. */
function advance(): void {
  const next = queue.shift();
  if (next) {
    startItem(next);
    return;
  }
  const finishedId = currentId;
  currentId = null;
  startIdle();
  if (finishedId) emit({ type: 'ended', id: finishedId });
}

/** 큐를 교체하고 첫 아이템을 시작한다. */
function play(items: Item[], behaviorLabel: string): string {
  if (!sim) throw new Error('시뮬레이터가 아직 준비되지 않았습니다');
  if (items.length === 0) throw new Error('재생할 것이 없습니다');

  queue = items.slice(1);
  const id = `p${++playSeq}`;
  currentId = id;
  startItem(items[0]);

  const total = items.reduce((sum, it) => sum + it.budget / Math.max(it.speed, 1e-6), 0);
  emit({ type: 'playing', id, duration: total, behavior: behaviorLabel });
  return id;
}

export const playBehavior = (
  name: string,
  p: { speed?: number; amplitude?: number } = {},
): string => play([buildBehaviorItem(name, p)], name);

export const playItems = (items: Item[], label: string): string => play(items, label);

export const playClipItem = (clip: Clip, p: { speed?: number; face?: string | null } = {}): string =>
  play([buildClipItem(clip, p)], 'clip');

/** 재생을 멈추고 대기 모션으로 돌아간다. (그 자리에 얼어붙지 않는다.) */
export function stop(): void {
  queue = [];
  const finishedId = currentId;
  currentId = null;
  startIdle();
  if (finishedId) emit({ type: 'ended', id: finishedId });
}

/** 대기 모션을 바꾼다. 재생 중이 아니면 즉시 반영. */
export function setIdle(p: { behavior?: string; speed?: number; amplitude?: number }): void {
  idleSpec = {
    behavior: p.behavior ?? idleSpec.behavior,
    speed: p.speed ?? idleSpec.speed,
    amplitude: p.amplitude ?? idleSpec.amplitude,
  };
  if (!current) startIdle();
}

// ------------------------------------------------------------------ 루프

function frame(now: number): void {
  rafHandle = requestAnimationFrame(frame);
  if (!sim || !viewer) return;

  const wall = Math.min((now - lastFrame) / 1000, MAX_WALL);
  lastFrame = now;

  const item = current ?? idleItem;
  if (item && wall > 0) {
    const dt = wall * item.speed;
    localT += dt;

    let pose: Pose | null = null;
    if (item.player) pose = item.player.target(localT);
    else if (item.clip) pose = sampleClip(item.clip, Math.min(localT, item.clip.duration));

    if (pose) sim.setPose(pose);

    const steps = Math.min(Math.round(dt / sim.dt), MAX_STEPS);
    if (steps > 0) sim.step(steps);

    if (current && localT >= current.budget) advance();
  }

  viewer.sync();
  viewer.render();
}

// ------------------------------------------------------------------ 부팅

export interface BootOptions {
  canvas: HTMLCanvasElement;
  onProgress?: (p: LoadProgress) => void;
}

let bootPromise: Promise<void> | null = null;

export function boot(opts: BootOptions): Promise<void> {
  bootPromise ??= (async () => {
    canvasEl = opts.canvas;
    const robot = PURE_DESK_ROBOT;

    sim = await createLamp(robot, opts.onProgress ?? (() => {}));

    if (robot.facesManifest) {
      opts.onProgress?.({ phase: '표정 영상 불러오는 중', loaded: 0, total: 1 });
      await loadFaces(robot.facesManifest);
    }

    // 뷰어는 모델이 컴파일된 뒤에만 만들 수 있다 — 생성자가 lamp.model 을 읽는다.
    viewer = new LampViewer(canvasEl, sim);

    /*
     * 생성 직후 수동 resize. 원본에도 같은 처리가 있다. ResizeObserver 는 뷰어가 생기기
     * 전에 이미 발화했고 크기가 그대로면 다시 발화하지 않는다. 이걸 빼면 three 가 기본
     * 300×150 드로잉 버퍼를 캔버스에 늘려 그려서 화면 전체가 흐려진다.
     */
    const box = canvasEl.getBoundingClientRect();
    viewer.resize(Math.max(box.width, 1), Math.max(box.height, 1));

    const ro = new ResizeObserver(() => {
      const r = canvasEl!.getBoundingClientRect();
      viewer?.resize(Math.max(r.width, 1), Math.max(r.height, 1));
    });
    ro.observe(canvasEl);

    startIdle();
    lastFrame = performance.now();
    rafHandle = requestAnimationFrame(frame);

    emit({
      type: 'ready',
      limits: publicLimits(),
      behaviors: knownBehaviors(),
      faces: knownFaces(),
    });
  })().catch((err: unknown) => {
    const message = err instanceof Error ? err.message : String(err);
    emit({ type: 'error', message });
    throw err;
  });
  return bootPromise;
}

// ------------------------------------------------------------------ 조회 / 기타

/**
 * 관절 범위를 계약 이름으로.
 *
 * robot.xml 의 액추에이터가 inheritrange="1" 이라 컴파일된 모델에서 바로 읽힌다.
 * Dart 쪽에 상수 파일을 따로 두지 않는 이유 — XML 을 고치면 자동으로 따라온다.
 */
function publicLimits(): Record<string, [number, number]> {
  const out: Record<string, [number, number]> = {};
  if (!sim) return out;
  // joints.ts 를 import 하면 순환이 되지 않지만, ready 페이로드만을 위해 여기서 직접 매핑한다.
  const map: Record<JointName, string> = {
    base_yaw: 'base_yaw',
    base_pitch: 'shoulder_pitch',
    elbow_pitch: 'elbow_pitch',
    wrist_roll: 'head_pan',
    wrist_pitch: 'head_tilt',
  };
  for (const j of JOINT_NAMES) out[map[j]] = sim.limits[j];
  return out;
}

export const getLimits = publicLimits;

/** 현재 명령 포즈를 계약 관절 이름으로. 개발 중 검증용. */
export function publicPose(): Record<string, number> {
  const out: Record<string, number> = {};
  if (!sim) return out;
  const map: Record<JointName, string> = {
    base_yaw: 'base_yaw',
    base_pitch: 'shoulder_pitch',
    elbow_pitch: 'elbow_pitch',
    wrist_roll: 'head_pan',
    wrist_pitch: 'head_tilt',
  };
  const targets = sim.targets;
  for (const j of JOINT_NAMES) out[map[j]] = targets[j];
  return out;
}

export function setView(v: Partial<CameraView>): void {
  if (!viewer) return;
  const base = PURE_DESK_ROBOT.heroView;
  viewer.setView({
    azimuth: v.azimuth ?? base.azimuth,
    elevation: v.elevation ?? base.elevation,
    distance: v.distance ?? base.distance,
    lookAt: v.lookAt ?? base.lookAt,
  });
}

export function enableOrbit(on: boolean): void {
  if (viewer) viewer.controls.enabled = on;
}

/** 현재 프레임 PNG dataURL. 라이브러리 썸네일이 이 경로를 쓴다. */
export function capture(): string {
  if (!viewer || !canvasEl) return '';
  // 같은 틱 안에서 그린 직후에 읽는다. renderer 는 preserveDrawingBuffer 로 만들어져 있다.
  viewer.sync();
  viewer.render();
  return canvasEl.toDataURL('image/png');
}

export const isReady = (): boolean => sim !== null && viewer !== null;

/**
 * 루프를 멈추고 자원을 놓는다. 앱에서는 WebView 인스턴스가 하나뿐이라 호출할 일이 없지만,
 * blob URL 과 영상 디코더를 쥔 채로 두면 핫 리로드 때 누수가 쌓인다.
 */
export function dispose(): void {
  if (rafHandle) cancelAnimationFrame(rafHandle);
  rafHandle = 0;
  for (const url of faceBlobs.values()) URL.revokeObjectURL(url);
  faceBlobs.clear();
  viewer?.dispose();
  viewer = null;
  sim = null;
  bootPromise = null;
}

if (import.meta.hot) import.meta.hot.dispose(() => dispose());
