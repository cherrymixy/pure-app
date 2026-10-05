/**
 * 표현 동작 엔진 — 파이썬 쪽 lelamp_sim/motion.py 를 그대로 옮긴 것.
 * 키프레임(자세 + 시간 + 이징)에 절차적 오실레이션(호흡)을 얹는다.
 */

export const JOINT_NAMES = [
  'base_yaw',
  'base_pitch',
  'elbow_pitch',
  'wrist_roll',
  'wrist_pitch',
] as const;

export type JointName = (typeof JOINT_NAMES)[number];
export type Pose = Record<JointName, number>;
export type PartialPose = Partial<Record<JointName, number>>;

// ------------------------------------------------------------------ 이징

export type EasingName =
  | 'linear'
  | 'ease_in_out'
  | 'ease_in'
  | 'ease_out'
  | 'ease_out_back'
  | 'ease_out_elastic'
  | 'ease_out_bounce';

const easeOutBounce = (t: number): number => {
  const n1 = 7.5625;
  const d1 = 2.75;
  if (t < 1 / d1) return n1 * t * t;
  if (t < 2 / d1) {
    t -= 1.5 / d1;
    return n1 * t * t + 0.75;
  }
  if (t < 2.5 / d1) {
    t -= 2.25 / d1;
    return n1 * t * t + 0.9375;
  }
  t -= 2.625 / d1;
  return n1 * t * t + 0.984375;
};

export const EASINGS: Record<EasingName, (t: number) => number> = {
  linear: (t) => t,
  /** 부드러운 가감속 (코사인) */
  ease_in_out: (t) => 0.5 - 0.5 * Math.cos(Math.PI * t),
  /** 천천히 시작해 가속 — 스르르 무너지는 졸음 */
  ease_in: (t) => t * t,
  /** 빠르게 시작해 감속 — 화들짝 */
  ease_out: (t) => 1 - (1 - t) ** 2,
  /** 목표를 살짝 넘었다 돌아온다 (탄력) */
  ease_out_back: (t) => {
    const c1 = 1.70158;
    const c3 = c1 + 1;
    return 1 + c3 * (t - 1) ** 3 + c1 * (t - 1) ** 2;
  },
  /** 튕기는 느낌 */
  ease_out_elastic: (t) => {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    const c4 = (2 * Math.PI) / 3;
    return 2 ** (-10 * t) * Math.sin((t * 10 - 0.75) * c4) + 1;
  },
  ease_out_bounce: easeOutBounce,
};

// ------------------------------------------------------------ 데이터 모델

export interface Keyframe {
  pose: PartialPose;
  /** 이 자세까지 가는 데 걸리는 시간(초) */
  duration: number;
  easing?: EasingName;
  /** 도착 후 머무는 시간(초) */
  hold?: number;
}

export interface Oscillation {
  joint: JointName;
  /** 진폭(도) */
  amplitude: number;
  /** 주기(초) */
  period: number;
  /** 0~1 */
  phase?: number;
  waveform?: 'sin' | 'triangle';
}

export interface Motion {
  name: string;
  /** 한국어 표시 이름 */
  label: string;
  description: string;
  keyframes: Keyframe[];
  loop?: boolean;
  overlays?: Oscillation[];
}

const span = (kf: Keyframe) => Math.max(kf.duration, 1e-6) + Math.max(kf.hold ?? 0, 0);

export const cycleTime = (motion: Motion): number =>
  motion.keyframes.reduce((sum, kf) => sum + span(kf), 0);

const oscValue = (osc: Oscillation, t: number): number => {
  if (osc.period <= 0) return 0;
  const x = (t / osc.period + (osc.phase ?? 0)) % 1;
  if ((osc.waveform ?? 'sin') === 'triangle') return osc.amplitude * (4 * Math.abs(x - 0.5) - 1);
  return osc.amplitude * Math.sin(2 * Math.PI * x);
};

export const mergePose = (base: Pose, update?: PartialPose): Pose => {
  const out = { ...base };
  if (update) {
    for (const [k, v] of Object.entries(update)) out[k as JointName] = v as number;
  }
  return out;
};

// ------------------------------------------------------------------ 재생기

export class MotionPlayer {
  readonly motion: Motion;
  readonly startPose: Pose;
  readonly leadIn: number;
  private readonly absolute: Pose[];
  private readonly cycle: number;

  constructor(motion: Motion, startPose: Pose, leadIn = 0) {
    this.motion = motion;
    this.startPose = { ...startPose };
    this.leadIn = Math.max(leadIn, 0);

    let current = { ...startPose };
    this.absolute = motion.keyframes.map((kf) => {
      current = mergePose(current, kf.pose);
      return { ...current };
    });
    this.cycle = cycleTime(motion);
  }

  /** 한 번 재생하는 데 걸리는 시간 (반복이면 리드인 + 한 사이클) */
  get duration(): number {
    return this.leadIn + this.cycle;
  }

  finished(t: number): boolean {
    return !this.motion.loop && t >= this.duration;
  }

  /**
   * t 초 시점에 서보로 보낼 목표 각도.
   * 반복 동작은 사이클의 끝과 시작이 이어져 있어 t=0 에서 이미 사이클 위의 자세를
   * 요구한다. leadIn 을 주면 현재 자세에서 그 자세까지 부드럽게 진입한다.
   */
  target(t: number): Pose {
    if (this.leadIn > 0) {
      if (t < this.leadIn) {
        const entry = this.keyframePose(0);
        const eased = EASINGS.ease_in_out(Math.min(t / this.leadIn, 1));
        const out = {} as Pose;
        for (const n of JOINT_NAMES) out[n] = this.startPose[n] + (entry[n] - this.startPose[n]) * eased;
        return out;
      }
      t -= this.leadIn;
    }

    const pose = this.keyframePose(t);
    for (const osc of this.motion.overlays ?? []) pose[osc.joint] += oscValue(osc, t);
    return pose;
  }

  private keyframePose(t: number): Pose {
    const frames = this.motion.keyframes;
    if (frames.length === 0) return { ...this.startPose };

    if (this.motion.loop) t = this.cycle > 0 ? ((t % this.cycle) + this.cycle) % this.cycle : 0;
    else if (t >= this.cycle) return { ...this.absolute[this.absolute.length - 1] };

    let local = Math.max(t, 0);
    for (let i = 0; i < frames.length; i++) {
      const kf = frames[i];
      const s = span(kf);
      if (local < s || i === frames.length - 1) {
        // 반복 재생이면 마지막 키프레임 다음이 첫 키프레임으로 이어진다.
        const prev =
          i > 0
            ? this.absolute[i - 1]
            : this.motion.loop && this.absolute.length > 1
              ? this.absolute[this.absolute.length - 1]
              : this.startPose;
        const next = this.absolute[i];
        if (local <= kf.duration) {
          const u = kf.duration <= 0 ? 1 : Math.min(local / kf.duration, 1);
          const eased = EASINGS[kf.easing ?? 'ease_in_out'](u);
          const out = {} as Pose;
          for (const n of JOINT_NAMES) out[n] = prev[n] + (next[n] - prev[n]) * eased;
          return out;
        }
        return { ...next };
      }
      local -= s;
    }
    return { ...this.absolute[this.absolute.length - 1] };
  }
}
