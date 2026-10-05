/**
 * 표현 동작 라이브러리 — lelamp_sim/behaviors.py 와 같은 값을 쓴다.
 * 자세 값은 전부 도(degree), 0도는 캘리브레이션 영점이다.
 */

import type { Motion, Oscillation, PartialPose, Pose } from './motion';

export const HOME: Pose = {
  base_yaw: 0,
  base_pitch: 0,
  elbow_pitch: 0,
  wrist_roll: 0,
  wrist_pitch: 0,
};

/** 정신 차린 자세 — 팔을 세우고 고개를 든다 */
export const PERK: PartialPose = { base_pitch: -14, elbow_pitch: -20, wrist_roll: 14, wrist_pitch: 22 };
/** 졸음 1단계 */
const DROWSY: PartialPose = { base_pitch: 6, elbow_pitch: 4, wrist_roll: -16, wrist_pitch: -10 };
/** 졸음 2단계 — 고개가 확 꺾인다 */
const DROOP: PartialPose = { base_pitch: 24, elbow_pitch: 14, wrist_roll: -56, wrist_pitch: -34 };
/** 졸음 3단계 — 거의 무너진다 */
const DROOP_DEEP: PartialPose = { base_pitch: 34, elbow_pitch: 18, wrist_roll: -72, wrist_pitch: -42 };
/** 완전히 잠든 자세 */
const SLEEP: PartialPose = { base_pitch: 30, elbow_pitch: 16.5, wrist_roll: -95, wrist_pitch: -45 };
/** 기지개 */
const STRETCH: PartialPose = { base_pitch: -26, elbow_pitch: -62, wrist_roll: 52, wrist_pitch: 78 };
/** 시무룩 */
export const SLUMP: PartialPose = { base_pitch: 18, elbow_pitch: 12, wrist_roll: -38, wrist_pitch: -24 };
/**
 * 집중 — 책상 위를 비춘다.
 *
 * PURE 수정: wrist_pitch -20 → -12.
 * 리타겟 후 head_tilt 가 -35.7° 로 robot.xml 범위(-33…42°)를 2.7° 넘어 조용히 클램프되고,
 * 그만큼 동작이 끝에서 멈칫했다. 0.45 게인이라 8° 올리면 -31.7° 로 범위 안에 들어온다.
 * 아래로 향하는 각도가 약 10% 줄지만 눈에 띄지 않는다. (원본 주석도 이 초과를 알고 있었다 — robots.ts:141)
 */
const FOCUS: PartialPose = { base_pitch: -10, elbow_pitch: -15, wrist_roll: -30, wrist_pitch: -12 };

/** 어떤 자세 위에도 얹을 수 있는 미세한 호흡 */
const breathing = (amplitude = 1.2, period = 4): Oscillation[] => [
  { joint: 'base_pitch', amplitude, period },
  { joint: 'elbow_pitch', amplitude: -amplitude * 0.7, period, phase: 0.02 },
  { joint: 'wrist_pitch', amplitude: amplitude * 1.3, period, phase: 0.08 },
];

export const BEHAVIORS: Motion[] = [
  {
    name: 'idle',
    label: '대기',
    description: '가만히 숨만 쉬면서 아주 가끔 시선을 옮긴다',
    loop: true,
    keyframes: [
      { pose: HOME, duration: 1.5, hold: 2.5 },
      { pose: { base_yaw: 9, wrist_pitch: 4 }, duration: 2.2, hold: 2.0 },
      { pose: { base_yaw: -7, wrist_roll: 5 }, duration: 2.4, hold: 2.6 },
    ],
    overlays: breathing(1.0, 4.6),
  },
  {
    name: 'doze',
    label: '졸기',
    description: '고개가 스르르 떨어지다 화들짝 깨어나길 반복',
    loop: true,
    keyframes: [
      // 1) 꾸벅꾸벅 시작
      { pose: DROWSY, duration: 1.6, easing: 'ease_in_out', hold: 0.6 },
      // 2) 스르르 무너진다
      { pose: DROOP, duration: 2.4, easing: 'ease_in', hold: 0.45 },
      // 3) 더 깊이 꺾인다
      { pose: DROOP_DEEP, duration: 1.5, easing: 'ease_in', hold: 0.3 },
      // 4) 화들짝! 짧고 빠르게, 살짝 오버슛
      {
        pose: { base_pitch: -12, elbow_pitch: -18, wrist_roll: 12, wrist_pitch: 20 },
        duration: 0.32,
        easing: 'ease_out_back',
        hold: 0.55,
      },
      // 5) 다시 눈이 감긴다
      {
        pose: { base_pitch: -2, elbow_pitch: -4, wrist_roll: -4, wrist_pitch: 2 },
        duration: 1.1,
        hold: 0.35,
      },
    ],
    overlays: [
      { joint: 'base_pitch', amplitude: 1.1, period: 5 },
      { joint: 'wrist_pitch', amplitude: 1.6, period: 5, phase: 0.1 },
    ],
  },
  {
    name: 'sleep',
    label: '숙면',
    description: '팔을 접고 머리를 파묻은 채 느리게 숨만 쉰다',
    loop: true,
    keyframes: [{ pose: SLEEP, duration: 2.6, easing: 'ease_in', hold: 4.0 }],
    overlays: [
      { joint: 'base_pitch', amplitude: 1.6, period: 6.5 },
      { joint: 'elbow_pitch', amplitude: -1.0, period: 6.5 },
      { joint: 'wrist_roll', amplitude: 2.4, period: 6.5, phase: 0.12 },
    ],
  },
  {
    name: 'wake',
    label: '기상',
    description: '잠에서 깨서 기지개를 켜고 자세를 잡는다',
    keyframes: [
      { pose: SLEEP, duration: 1.0, hold: 0.4 },
      { pose: { wrist_roll: -66, wrist_pitch: -30 }, duration: 0.6, easing: 'ease_out', hold: 0.25 },
      { pose: STRETCH, duration: 1.3, easing: 'ease_out_back', hold: 0.7 },
      {
        pose: { base_yaw: 14, base_pitch: -22, elbow_pitch: -34, wrist_roll: 20, wrist_pitch: 34 },
        duration: 0.9,
        hold: 0.3,
      },
      { pose: PERK, duration: 0.8, easing: 'ease_out_back', hold: 0.5 },
      { pose: HOME, duration: 1.0, hold: 0.5 },
    ],
  },
  {
    name: 'nod',
    label: '끄덕끄덕',
    description: '긍정 · 수긍',
    keyframes: [
      { pose: { wrist_pitch: 10, wrist_roll: 6 }, duration: 0.35, easing: 'ease_out' },
      { pose: { wrist_pitch: -20, wrist_roll: -12 }, duration: 0.28 },
      { pose: { wrist_pitch: 8, wrist_roll: 4 }, duration: 0.3 },
      { pose: { wrist_pitch: -18, wrist_roll: -10 }, duration: 0.26 },
      { pose: HOME, duration: 0.6, easing: 'ease_out_back', hold: 0.3 },
    ],
  },
  {
    name: 'shake',
    label: '도리도리',
    description: '부정 · 거절',
    keyframes: [
      { pose: { base_pitch: -6, wrist_pitch: 8 }, duration: 0.3, easing: 'ease_out' },
      { pose: { base_yaw: 20, wrist_roll: 8 }, duration: 0.28 },
      { pose: { base_yaw: -20, wrist_roll: -8 }, duration: 0.36 },
      { pose: { base_yaw: 16, wrist_roll: 6 }, duration: 0.34 },
      { pose: { base_yaw: -12, wrist_roll: -5 }, duration: 0.3 },
      { pose: HOME, duration: 0.7, easing: 'ease_out_back', hold: 0.3 },
    ],
  },
  {
    name: 'look_around',
    label: '두리번',
    description: '주변을 훑어본다',
    keyframes: [
      { pose: { base_pitch: -10, elbow_pitch: -14, wrist_pitch: 16 }, duration: 1.0, hold: 0.4 },
      { pose: { base_yaw: 42, wrist_roll: 10 }, duration: 1.4, hold: 0.8 },
      { pose: { base_yaw: -38, wrist_roll: -8 }, duration: 2.0, hold: 0.8 },
      { pose: { base_yaw: 6, wrist_roll: 0, wrist_pitch: 8 }, duration: 1.2, hold: 0.5 },
      { pose: HOME, duration: 1.0 },
    ],
    overlays: [{ joint: 'wrist_pitch', amplitude: 1.0, period: 3.4 }],
  },
  {
    name: 'curious',
    label: '갸웃',
    description: '호기심에 고개를 기울인다',
    keyframes: [
      { pose: { base_pitch: -12, elbow_pitch: -16, wrist_pitch: 18 }, duration: 0.7, easing: 'ease_out', hold: 0.2 },
      { pose: { wrist_roll: 34, base_yaw: -10 }, duration: 0.55, easing: 'ease_out_back', hold: 0.9 },
      { pose: { wrist_roll: -22, base_yaw: 12 }, duration: 0.8, hold: 0.7 },
      { pose: HOME, duration: 1.0, hold: 0.3 },
    ],
  },
  {
    name: 'happy',
    label: '신남',
    description: '통통 튀며 좋아한다',
    keyframes: [
      { pose: PERK, duration: 0.45, easing: 'ease_out_back', hold: 0.1 },
      { pose: { base_pitch: 6, elbow_pitch: -6, wrist_pitch: -4 }, duration: 0.22, easing: 'ease_in' },
      {
        pose: { base_pitch: -20, elbow_pitch: -26, wrist_pitch: 30 },
        duration: 0.3,
        easing: 'ease_out_bounce',
      },
      { pose: { base_yaw: 18, wrist_roll: 16 }, duration: 0.26, easing: 'ease_out' },
      { pose: { base_yaw: -18, wrist_roll: -16 }, duration: 0.3 },
      { pose: { base_yaw: 10, wrist_roll: 8 }, duration: 0.26 },
      { pose: HOME, duration: 0.8, easing: 'ease_out_elastic', hold: 0.3 },
    ],
  },
  {
    name: 'sad',
    label: '시무룩',
    description: '어깨가 처지고 고개를 떨군다',
    loop: true,
    keyframes: [
      { pose: { wrist_pitch: 6 }, duration: 0.5, easing: 'ease_out' },
      { pose: SLUMP, duration: 2.2, easing: 'ease_in', hold: 1.6 },
      { pose: { base_yaw: -12 }, duration: 1.6, hold: 1.0 },
      { pose: { base_yaw: 8 }, duration: 1.8, hold: 1.2 },
    ],
    overlays: [
      { joint: 'base_pitch', amplitude: 1.4, period: 5.5 },
      { joint: 'wrist_pitch', amplitude: 1.0, period: 5.5 },
    ],
  },
  {
    name: 'alert',
    label: '주목',
    description: '무언가를 발견하고 번쩍 고개를 든다',
    keyframes: [
      { pose: { wrist_pitch: -6 }, duration: 0.18, easing: 'ease_in' },
      {
        pose: { base_pitch: -20, elbow_pitch: -28, wrist_roll: 18, wrist_pitch: 32 },
        duration: 0.3,
        easing: 'ease_out_back',
        hold: 1.1,
      },
      { pose: { base_yaw: 10 }, duration: 0.5, hold: 0.4 },
      { pose: PERK, duration: 0.7, hold: 0.6 },
    ],
    overlays: [{ joint: 'wrist_roll', amplitude: 0.8, period: 2.2 }],
  },
  {
    name: 'greet',
    label: '인사',
    description: '고개 숙여 인사한다',
    keyframes: [
      { pose: PERK, duration: 0.6, easing: 'ease_out', hold: 0.2 },
      {
        pose: { base_pitch: 16, elbow_pitch: 10, wrist_roll: -30, wrist_pitch: -24 },
        duration: 0.75,
        hold: 0.45,
      },
      { pose: PERK, duration: 0.8, easing: 'ease_out_back', hold: 0.3 },
      { pose: HOME, duration: 0.8 },
    ],
  },
  {
    name: 'sweep',
    label: '스윕',
    description: '베이스를 크게 돌려 방 전체를 비춘다',
    loop: true,
    keyframes: [
      { pose: { base_pitch: -16, elbow_pitch: -20, wrist_pitch: 24 }, duration: 1.0 },
      { pose: { base_yaw: 65 }, duration: 2.6, hold: 0.4 },
      { pose: { base_yaw: -65 }, duration: 4.0, hold: 0.4 },
      { pose: { base_yaw: 0 }, duration: 2.2, hold: 0.3 },
    ],
  },
  {
    name: 'focus',
    label: '집중',
    description: '책상 위를 정면으로 비추고 가만히 있는다',
    loop: true,
    keyframes: [{ pose: FOCUS, duration: 1.6, hold: 3.0 }],
    overlays: breathing(0.6, 6),
  },
  {
    name: 'home',
    label: '기본 자세',
    description: '홈 포지션으로 복귀',
    keyframes: [{ pose: HOME, duration: 1.2 }],
  },
];

export const getBehavior = (name: string): Motion => {
  const found = BEHAVIORS.find((b) => b.name === name);
  if (!found) throw new Error(`알 수 없는 동작: ${name}`);
  return found;
};
