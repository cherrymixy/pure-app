/** 15개 동작을 리타겟 후 실제 관절 범위와 대조한다. (STEP 2 검증용, 번들 제외) */
import { BEHAVIORS } from '../src/engine/behaviors';
import { ROBOTS, retargetMotion } from '../src/engine/robots';
import { MotionPlayer, JOINT_NAMES, type JointName } from '../src/engine/motion';
import { HOME } from '../src/engine/behaviors';

// robot.xml 의 관절 범위 (deg). 내부 채널명 기준.
const LIMITS: Record<JointName, [number, number]> = {
  base_yaw: [-150, 150],
  base_pitch: [-35, 55],
  elbow_pitch: [-120, 33],
  wrist_roll: [-160, 160],
  wrist_pitch: [-33, 42],
};
const DISPLAY: Record<JointName, string> = {
  base_yaw: 'base_yaw', base_pitch: 'shoulder_pitch', elbow_pitch: 'elbow_pitch',
  wrist_roll: 'head_pan', wrist_pitch: 'head_tilt',
};

const robot = ROBOTS['pure-desk'];
const AMPS = [1.0, 1.5];

for (const amp of AMPS) {
  console.log(`\n===== amplitude ${amp.toFixed(1)} =====`);
  let anyViolation = false;
  for (const motion of BEHAVIORS) {
    const rt = retargetMotion(robot, motion);
    const scaled = amp === 1 ? rt : {
      ...rt,
      keyframes: rt.keyframes.map((kf) => ({
        ...kf,
        pose: Object.fromEntries(Object.entries(kf.pose).map(([k, v]) => [k, (v as number) * amp])),
      })),
      overlays: (rt.overlays ?? []).map((o) => ({ ...o, amplitude: o.amplitude * amp })),
    };
    const player = new MotionPlayer(scaled as any, HOME, 0.8);
    const end = player.leadIn + (motion.loop ? 1 : 0) + player.duration;
    const ext: Record<string, [number, number]> = {};
    for (const n of JOINT_NAMES) ext[n] = [Infinity, -Infinity];
    for (let t = 0; t <= end; t += 1 / 120) {
      const p = player.target(t);
      for (const n of JOINT_NAMES) {
        if (p[n] < ext[n][0]) ext[n][0] = p[n];
        if (p[n] > ext[n][1]) ext[n][1] = p[n];
      }
    }
    const bad: string[] = [];
    for (const n of JOINT_NAMES) {
      const [lo, hi] = LIMITS[n];
      const [mn, mx] = ext[n];
      if (mn < lo - 1e-6) bad.push(`${DISPLAY[n]} ${mn.toFixed(1)}° < ${lo}° (${(lo - mn).toFixed(1)}° 초과)`);
      if (mx > hi + 1e-6) bad.push(`${DISPLAY[n]} ${mx.toFixed(1)}° > ${hi}° (${(mx - hi).toFixed(1)}° 초과)`);
    }
    if (bad.length) { anyViolation = true; console.log(`  ✗ ${motion.name.padEnd(12)} ${bad.join(' / ')}`); }
  }
  if (!anyViolation) console.log('  ✓ 15종 전부 범위 안');
}
