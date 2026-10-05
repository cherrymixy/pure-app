/**
 * 클립 모델 — 관절별 독립 트랙 위에 절대 시각의 키프레임을 둔다.
 *
 * PURE 수정: 타임라인 에디터 전용 코드(emptyClip·cloneClip·trackOf·setKey·clearKeys·
 * removeKey·moveKey·sortTrack·setDuration·keyTimes·serializeClip·parseClip)를 제거했다.
 * 바깥에서 들어오는 클립의 검증은 api.ts 가 담당한다 — 원본 parseClip 은 모르는 관절을
 * 조용히 0 트랙으로 바꿔서, 이름이 틀리면 에러 없이 그냥 안 움직였다.
 *
 * 남긴 것: 샘플링(sampleTrack·sampleKeys·sampleClip)과 Motion→Clip 변환.
 *
 * `motion.ts` 의 Motion 은 "포즈 + 지속시간" 을 순서대로 나열하는 구조라
 * 관절마다 다른 타이밍을 줄 수 없다. 여기서는 애프터 이펙트처럼 관절 하나하나가
 * 자기 트랙을 갖고, 각 키는 "이 키에서 다음 키로 나갈 때" 쓸 이징을 들고 있다.
 */

import {
  EASINGS,
  JOINT_NAMES,
  type EasingName,
  type JointName,
  type Motion,
  type Oscillation,
  type Pose,
} from './motion';
import { HOME } from './behaviors';

export interface Key {
  /** 클립 시작부터의 절대 시각(초) */
  t: number;
  /** 각도(도) */
  value: number;
  /** 이 키에서 다음 키로 가는 구간에 쓰는 이징 */
  easing: EasingName;
}

export interface Track {
  joint: JointName;
  /** t 오름차순 */
  keys: Key[];
}

export interface Clip {
  name: string;
  label: string;
  description: string;
  /** 클립 전체 길이(초) */
  duration: number;
  loop: boolean;
  tracks: Track[];
  /** 키프레임 위에 더해지는 절차적 흔들림 (호흡 등) */
  overlays?: Oscillation[];
}

export const CLIP_FORMAT = 'lelamp.clip/1';

// ------------------------------------------------------------------ 샘플링

const oscValue = (osc: Oscillation, t: number): number => {
  if (osc.period <= 0) return 0;
  const x = (((t / osc.period + (osc.phase ?? 0)) % 1) + 1) % 1;
  if ((osc.waveform ?? 'sin') === 'triangle') return osc.amplitude * (4 * Math.abs(x - 0.5) - 1);
  return osc.amplitude * Math.sin(2 * Math.PI * x);
};

const ease = (name: EasingName, u: number): number => (EASINGS[name] ?? EASINGS.ease_in_out)(u);

/** 트랙 하나를 시각 t 에서 평가한다. t 는 이미 [0, duration) 으로 감긴 값이어야 한다. */
export function sampleTrack(track: Track, t: number, duration: number, loop: boolean): number {
  const keys = track.keys;
  if (keys.length === 0) return 0;
  if (keys.length === 1) return keys[0].value;

  const first = keys[0];
  const last = keys[keys.length - 1];

  // 마지막 키 이후 / 첫 키 이전 — 반복 클립이면 last → first 로 순환 보간한다.
  const wrapSpan = first.t + duration - last.t;
  if (t >= last.t) {
    if (!loop || wrapSpan <= 0) return last.value;
    const u = Math.min((t - last.t) / wrapSpan, 1);
    return last.value + (first.value - last.value) * ease(last.easing, u);
  }
  if (t <= first.t) {
    if (!loop || wrapSpan <= 0) return first.value;
    const u = Math.min((t + duration - last.t) / wrapSpan, 1);
    return last.value + (first.value - last.value) * ease(last.easing, u);
  }

  let i = 0;
  while (i < keys.length - 1 && keys[i + 1].t <= t) i++;
  const a = keys[i];
  const b = keys[i + 1];
  const span = b.t - a.t;
  if (span <= 0) return b.value;
  return a.value + (b.value - a.value) * ease(a.easing, (t - a.t) / span);
}

/**
 * 클립을 시각 t 에서 평가해 5축 자세를 만든다.
 *
 * 키프레임은 반복 클립이면 duration 으로 감아서 보고, 오버레이(호흡)는
 * `MotionPlayer` 와 똑같이 **감지 않은** t 로 계산한다.
 */
export const sampleKeys = (clip: Clip, t: number): Pose =>
  sampleClip({ ...clip, overlays: undefined }, t);

export function sampleClip(clip: Clip, t: number): Pose {
  const d = Math.max(clip.duration, 1e-6);
  const local = clip.loop ? ((t % d) + d) % d : Math.min(Math.max(t, 0), d);

  const pose = {} as Pose;
  for (const name of JOINT_NAMES) {
    const track = clip.tracks.find((tr) => tr.joint === name);
    pose[name] = track ? sampleTrack(track, local, d, clip.loop) : 0;
  }
  for (const osc of clip.overlays ?? []) pose[osc.joint] += oscValue(osc, t);
  return pose;
}

// ------------------------------------------------------------------ 변환

const posesEqual = (a: Pose, b: Pose): boolean =>
  JOINT_NAMES.every((n) => Math.abs(a[n] - b[n]) < 1e-9);

const mergeInto = (base: Pose, update: Partial<Record<JointName, number>>): Pose => {
  const out = { ...base };
  for (const [k, v] of Object.entries(update)) if (v !== undefined) out[k as JointName] = v;
  return out;
};

/**
 * 기존 Motion 을 편집 가능한 Clip 으로 바꾼다.
 *
 * 반복 동작은 사이클의 끝과 시작이 이어져 있어서, t=0 의 자세가 **마지막 키프레임**
 * 자세다 (MotionPlayer 와 같은 규칙). 그래서 t=0 키에는 마지막 절대 자세를 넣는다.
 * `hold` 는 같은 값의 키를 하나 더 찍어 표현한다.
 */
export function motionToClip(motion: Motion): Clip {
  const frames = motion.keyframes;

  // 키프레임의 부분 포즈는 "직전 값 유지" 라서 절대 자세가 시작 자세에 따라 달라진다.
  // 반복 동작은 사이클의 끝이 곧 시작이므로, 시작 자세 = 마지막 절대 자세가 되는
  // 고정점까지 몇 번 돌려서 정상 상태의 사이클을 구한다.
  let start: Pose = { ...HOME };
  let absolute: Pose[] = [];
  for (let iter = 0; iter < (motion.loop ? 5 : 1); iter++) {
    let current: Pose = { ...start };
    absolute = frames.map((kf) => {
      current = mergeInto(current, kf.pose);
      return { ...current };
    });
    if (!motion.loop || absolute.length === 0) break;
    const last = absolute[absolute.length - 1];
    if (posesEqual(last, start)) break;
    start = { ...last };
  }

  const duration = frames.reduce((sum, kf) => sum + kf.duration + (kf.hold ?? 0), 0);
  const startPose: Pose = motion.loop && absolute.length > 0 ? absolute[absolute.length - 1] : { ...HOME };

  const tracks: Track[] = JOINT_NAMES.map((joint) => ({ joint, keys: [] }));
  const push = (t: number, pose: Pose, easing: EasingName) => {
    for (const track of tracks) track.keys.push({ t: round3(t), value: round3(pose[track.joint]), easing });
  };

  push(0, startPose, frames[0]?.easing ?? 'ease_in_out');

  let cursor = 0;
  for (let i = 0; i < frames.length; i++) {
    const kf = frames[i];
    const nextEasing: EasingName =
      i + 1 < frames.length
        ? (frames[i + 1].easing ?? 'ease_in_out')
        : ((motion.loop ? frames[0].easing : 'linear') ?? 'linear');

    const arrival = cursor + kf.duration;
    const hold = kf.hold ?? 0;
    push(arrival, absolute[i], hold > 0 ? 'linear' : nextEasing);
    if (hold > 0) push(arrival + hold, absolute[i], nextEasing);
    cursor = arrival + hold;
  }

  return {
    name: motion.name,
    label: motion.label,
    description: motion.description,
    duration: round3(duration),
    loop: !!motion.loop,
    tracks,
    overlays: motion.overlays ? motion.overlays.map((o) => ({ ...o })) : undefined,
  };
}

// ------------------------------------------------------------------ 편집 연산

const round3 = (v: number): number => Math.round(v * 1000) / 1000;
