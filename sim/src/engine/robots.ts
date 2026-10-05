/**
 * Robot registry — every simulated robot shares the same five command channels
 * (`JointName`), but each robot gives them its own meaning, labels, model files and
 * camera.
 *
 * The behaviour library (`behaviors.ts`) and the state driver (`state-motion.ts`) were
 * authored for LeLamp. A robot whose joints mean something different declares a
 * `retarget`: a linear map from LeLamp channels to its own channels. Because the map is
 * linear, retargeting each keyframe's *full* pose and each oscillation's amplitude gives
 * exactly the same trajectory as retargeting every sampled frame — easing and
 * interpolation commute with it.
 *
 * Pure module: no React, no three, no I/O. (The face manifest is fetched by the runtime.)
 *
 * PURE 수정: LeLamp 로봇과 toLamp(상태 드라이버 전용 역행렬)를 제거했다. retarget 은
 * 유지한다 — behaviors.ts 의 모든 키프레임이 LeLamp 좌표계로 작성돼 있어서, 이게 없으면
 * 동작이 전혀 다른 관절로 간다. 경로는 base-relative 로 바꿔 assetUrl() 로 해석한다.
 */

import { JOINT_NAMES, type JointName, type Motion, type Oscillation, type Pose } from './motion';
import { HOME } from './behaviors';

export type RobotId = 'pure-desk';

export interface CameraView {
  azimuth: number;
  elevation: number;
  distance: number;
  lookAt: [number, number, number];
}

/**
 * A flat face display on the head body (drawn by the web viewer, not by MuJoCo).
 * All lengths in metres, in the head body's frame; the display faces −Y.
 */
export interface FaceDisplay {
  /** Centre of the visible opening */
  center: [number, number, number];
  /** Half width / half height of the visible opening (the video is fitted to this) */
  halfWidth: number;
  halfHeight: number;
  /** Corner radius of the opening */
  radius: number;
  /** Extra size hidden behind the bezel, so no gap shows at the edges */
  bleed: number;
}

/**
 * Which expression video plays when. Loaded at runtime from `RobotSpec.facesManifest`
 * (JSON next to the videos), so videos can be swapped without touching code:
 *   { "default": "idle.mp4", "behaviors": { "nod": "nod.mp4", "sleep": "sleep.mp4" } }
 * Paths are relative to the manifest. `default` plays while no behaviour runs.
 */
export interface FaceManifest {
  default?: string;
  behaviors?: Record<string, string>;
}

/** out[channel] = Σ gain · lelamp[source] */
export type RetargetMatrix = Record<JointName, Partial<Record<JointName, number>>>;

export interface RobotSpec {
  id: RobotId;
  /** Short name for the robot picker */
  label: string;
  /** Folder under /public holding manifest.json, the scene XML and assets/ */
  modelBase: string;
  /** Body the head-mounted light / glow follows */
  headBody: string;
  /** Body that stays fixed on the table (used by the kinematic preview) */
  baseBody: string;
  /** Channel name shown in the UI, per command channel */
  jointKeys: Record<JointName, string>;
  jointLabels: Record<JointName, string>;
  jointHints: Record<JointName, string>;
  heroView: CameraView;
  /** Spot light inside the head (LeLamp's shade). null = the robot has no beam. */
  beam: { pos: [number, number, number]; dir: [number, number, number] } | null;
  /** Face display on the head. null = no display (LeLamp). */
  display: FaceDisplay | null;
  /** URL of the FaceManifest JSON. null = no expression videos. */
  facesManifest: string | null;
  /** LeLamp → this robot. null = the robot *is* LeLamp (identity). */
  retarget: RetargetMatrix | null;
}

// ------------------------------------------------------------- PURE desk robot

/**
 * PURE desk robot (5-DOF, rigged from the Rhino model).
 *   1 base yaw · 2 shoulder · 3 elbow · 4 head pan · 5 head tilt
 * Channel 4 is our own head-pan axis — it is *not* LeLamp's wrist roll, so the
 * `wrist_roll` channel carries head pan on this robot.
 *
 * Retarget rationale (gains are provisional, tuned to the model's joint ranges):
 * - Gaze (LeLamp base_yaw) is split 65 / 35 between base yaw and head pan, so the head
 *   leads the body — overlapping action — while the total heading stays the same.
 * - Shoulder and elbow keep LeLamp's sign convention (+ leans forward) 1 : 1; LeLamp's
 *   behaviour range (−26…34°, −62…18°) fits inside this robot's (−35…55°, −120…33°).
 * - Head tilt takes LeLamp's head nod plus part of its wrist roll, which on LeLamp folds
 *   the head down/up (gains 0.45 / 0.25). On this robot shoulder, elbow and tilt share
 *   one axis direction, so the screen's world pitch is J5 − J2 − J3: without help, raising
 *   the arm (PERK: −14°, −20°) would also throw the screen ~34° up. Tilt therefore adds
 *   back 0.75 × (shoulder + elbow) — the head mostly holds its gaze while the arm moves,
 *   with a quarter of the arm's swing left in for follow-through. Every library keyframe
 *   then lands inside the −33…42° tilt range except `focus` (−35.2°, clamped by 2.2°).
 */
const PURE_DESK_RETARGET: RetargetMatrix = {
  base_yaw: { base_yaw: 0.65 },
  base_pitch: { base_pitch: 1 },
  elbow_pitch: { elbow_pitch: 1 },
  wrist_roll: { base_yaw: 0.35 },
  wrist_pitch: { wrist_pitch: 0.45, wrist_roll: 0.25, base_pitch: 0.75, elbow_pitch: 0.75 },
};

const PURE_DESK: RobotSpec = {
  id: 'pure-desk',
  label: 'PURE Desk',
  modelBase: 'pure-desk/model',
  headBody: 'head',
  baseBody: 'base',
  jointKeys: {
    base_yaw: 'base_yaw',
    base_pitch: 'shoulder_pitch',
    elbow_pitch: 'elbow_pitch',
    wrist_roll: 'head_pan',
    wrist_pitch: 'head_tilt',
  },
  jointLabels: {
    base_yaw: 'Base yaw',
    base_pitch: 'Shoulder',
    elbow_pitch: 'Elbow',
    wrist_roll: 'Head pan',
    wrist_pitch: 'Head tilt',
  },
  jointHints: {
    base_yaw: 'Turns everything above the base split line',
    base_pitch: 'Swings the lower arm in the dome slot (+ leans forward)',
    elbow_pitch: 'Bends the upper arm (+ folds forward-down)',
    wrist_roll: 'Turns the head left / right on the neck',
    wrist_pitch: 'Tilts the screen (− looks down)',
  },
  // Smaller than LeLamp (≈36 cm tall) — closer camera, aimed at the arm.
  // The screen faces −Y, so the camera sits in front (azimuth ≈ 60° looks toward +Y).
  heroView: { azimuth: 62, elevation: -8, distance: 0.95, lookAt: [0, -0.02, 0.2] },
  beam: null,
  /*
   * Measured from the CAD bezel (part 4): the opening is a 108 × 64.8 mm rounded
   * rectangle (r ≈ 6 mm, 5 : 3) whose back face sits 44.2 mm in front of the tilt axis.
   * The panel sits just behind that face and bleeds 1 mm under the bezel.
   */
  display: {
    center: [0.00132, -0.0440, 0.00909],
    halfWidth: 0.054,
    halfHeight: 0.0324,
    radius: 0.006,
    bleed: 0.001,
  },
  facesManifest: 'pure-desk/faces/faces.json',
  retarget: PURE_DESK_RETARGET,
};

export const ROBOTS: Record<RobotId, RobotSpec> = {
  'pure-desk': PURE_DESK,
};

/** 이 번들에는 로봇이 하나뿐이다. */
export const PURE_DESK_ROBOT = PURE_DESK;

export const ROBOT_IDS = Object.keys(ROBOTS) as RobotId[];

export const isRobotId = (value: unknown): value is RobotId =>
  typeof value === 'string' && value in ROBOTS;

// ------------------------------------------------------------------ retarget

/** Apply a channel map to a full pose. `null` = identity. */
export function mapPose(matrix: RetargetMatrix | null, pose: Pose): Pose {
  if (!matrix) return { ...pose };
  const out = {} as Pose;
  for (const joint of JOINT_NAMES) {
    let value = 0;
    for (const [source, gain] of Object.entries(matrix[joint])) {
      value += (gain ?? 0) * pose[source as JointName];
    }
    out[joint] = value;
  }
  return out;
}

export const retargetPose = (robot: RobotSpec, pose: Pose): Pose => mapPose(robot.retarget, pose);

/**
 * LeLamp-authored motion → this robot's channels.
 *
 * Keyframes hold "previous value" for joints they omit, and the map mixes channels, so
 * each keyframe is first resolved to an absolute LeLamp pose (starting from HOME, the
 * same start `motionToClip` uses) and then mapped. The result has full poses only.
 */
export function retargetMotion(robot: RobotSpec, motion: Motion): Motion {
  const matrix = robot.retarget;
  if (!matrix) return motion;

  let current: Pose = { ...HOME };
  // Looping motions start from their own last pose — resolve that first so the first
  // keyframe's omitted joints match what the loop actually holds.
  if (motion.loop) {
    for (const kf of motion.keyframes) current = { ...current, ...kf.pose } as Pose;
  }
  const keyframes = motion.keyframes.map((kf) => {
    current = { ...current, ...kf.pose } as Pose;
    return { ...kf, pose: mapPose(matrix, current) };
  });

  const overlays: Oscillation[] = [];
  for (const osc of motion.overlays ?? []) {
    for (const joint of JOINT_NAMES) {
      const gain = matrix[joint][osc.joint];
      if (gain) overlays.push({ ...osc, joint, amplitude: osc.amplitude * gain });
    }
  }
  return { ...motion, keyframes, overlays };
}
