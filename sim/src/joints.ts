/**
 * 관절 이름 변환 — 계약(바깥) ↔ 엔진 내부 채널.
 *
 * 이 번들에는 관절 이름이 세 층으로 존재한다:
 *   계약(부록 B)  base_yaw  shoulder_pitch  elbow_pitch  head_pan    head_tilt
 *   엔진 내부     base_yaw  base_pitch      elbow_pitch  wrist_roll  wrist_pitch
 *   robot.xml     "1"       "2"             "3"          "4"         "5"
 *
 * 가운데 층은 behaviors.ts 가 LeLamp 용으로 작성됐기 때문에 남아 있다. robot.xml 쪽은
 * lamp.ts 의 SERVO_ID 가 이미 처리한다. 여기서는 첫 번째 ↔ 두 번째만 다룬다.
 *
 * 이 변환을 빼먹으면 조용히 실패한다 — 원본 parseClip 은 모르는 관절 이름을 0 트랙으로
 * 바꿔서, 에러 없이 그냥 그 축이 안 움직였다.
 */

import { JOINT_NAMES, type JointName } from './engine/motion';

/** 계약에서 쓰는 관절 이름. 순서는 내부 JOINT_NAMES 와 1:1 대응. */
export const PUBLIC_JOINTS = [
  'base_yaw',
  'shoulder_pitch',
  'elbow_pitch',
  'head_pan',
  'head_tilt',
] as const;

export type PublicJoint = (typeof PUBLIC_JOINTS)[number];

export const TO_INTERNAL: Record<PublicJoint, JointName> = {
  base_yaw: 'base_yaw',
  shoulder_pitch: 'base_pitch',
  elbow_pitch: 'elbow_pitch',
  head_pan: 'wrist_roll',
  head_tilt: 'wrist_pitch',
};

export const TO_PUBLIC: Record<JointName, PublicJoint> = {
  base_yaw: 'base_yaw',
  base_pitch: 'shoulder_pitch',
  elbow_pitch: 'elbow_pitch',
  wrist_roll: 'head_pan',
  wrist_pitch: 'head_tilt',
};

export const isPublicJoint = (v: unknown): v is PublicJoint =>
  typeof v === 'string' && (PUBLIC_JOINTS as readonly string[]).includes(v);

/** 내부 이름 키 객체 → 계약 이름 키 객체. */
export function toPublicRecord<T>(input: Record<JointName, T>): Record<PublicJoint, T> {
  const out = {} as Record<PublicJoint, T>;
  for (const j of JOINT_NAMES) out[TO_PUBLIC[j]] = input[j];
  return out;
}
