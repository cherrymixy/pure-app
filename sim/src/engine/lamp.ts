/**
 * MuJoCo WASM 위에서 도는 LeLamp.
 * 파이썬 쪽 lelamp_sim/robot.py 와 같은 API 를 브라우저에서 제공한다.
 */

import { loadMujoco, type MjData, type MjModel, type MujocoModule } from './mujoco';
import {
  JOINT_NAMES,
  type JointName,
  type PartialPose,
  type Pose,
} from './motion';
import type { RobotSpec } from './robots';
import { assetUrl } from './paths';

const DEG = Math.PI / 180;
const RAD = 180 / Math.PI;

/** 이름 → 서보 ID. MuJoCo 모델 안의 조인트/액추에이터 이름이 곧 서보 ID 문자열이다. */
export const SERVO_ID: Record<JointName, number> = {
  base_yaw: 1,
  base_pitch: 2,
  elbow_pitch: 3,
  wrist_roll: 4,
  wrist_pitch: 5,
};

// Joint labels, hints, body names and model paths are per robot — see lib/lelamp/robots.ts.

// MuJoCo 쿼터니언은 (w, x, y, z) 순서다.
type Quat = ArrayLike<number>;

const quatConj = (q: Quat): number[] => [q[0], -q[1], -q[2], -q[3]];

const quatMul = (a: Quat, b: Quat): number[] => [
  a[0] * b[0] - a[1] * b[1] - a[2] * b[2] - a[3] * b[3],
  a[0] * b[1] + a[1] * b[0] + a[2] * b[3] - a[3] * b[2],
  a[0] * b[2] - a[1] * b[3] + a[2] * b[0] + a[3] * b[1],
  a[0] * b[3] + a[1] * b[2] - a[2] * b[1] + a[3] * b[0],
];

const quatRotate = (q: Quat, v: readonly number[]): number[] => {
  const [w, x, y, z] = [q[0], q[1], q[2], q[3]];
  // t = 2 * (q_vec × v);  v' = v + w*t + q_vec × t
  const tx = 2 * (y * v[2] - z * v[1]);
  const ty = 2 * (z * v[0] - x * v[2]);
  const tz = 2 * (x * v[1] - y * v[0]);
  return [
    v[0] + w * tx + (y * tz - z * ty),
    v[1] + w * ty + (z * tx - x * tz),
    v[2] + w * tz + (x * ty - y * tx),
  ];
};

export interface LoadProgress {
  phase: string;
  loaded: number;
  total: number;
}

interface Manifest {
  xml: string[];
  meshes: string[];
}

/** 엔진과 모델 파일을 받아 시뮬레이터를 만든다. */
export async function createLamp(
  robot: RobotSpec,
  onProgress: (p: LoadProgress) => void,
): Promise<LampSim> {
  onProgress({ phase: 'MuJoCo 엔진(WASM) 불러오는 중', loaded: 0, total: 1 });
  const mj = await loadMujoco();

  // MuJoCo 모델(XML + STL)은 public/<robot.modelBase> 에 그대로 복사해 두었다.
  const base = robot.modelBase;
  const manifest: Manifest = await fetch(assetUrl(`${base}/manifest.json`)).then((r) => r.json());
  // 로봇마다 가상 파일시스템의 자기 폴더에 푼다 — 엔진은 탭에 하나뿐이라, 로봇을
  // 바꿔 끼워도 다른 로봇의 XML·메시와 섞이지 않게 한다.
  const dir = `/models/${robot.id}`;
  const files = [
    ...manifest.xml.map((f) => ({ url: assetUrl(`${base}/${f}`), dest: `${dir}/${f}` })),
    ...manifest.meshes.map((f) => ({ url: assetUrl(`${base}/assets/${f}`), dest: `${dir}/assets/${f}` })),
  ];

  for (const path of ['/models', dir, `${dir}/assets`]) {
    try {
      mj.FS.mkdir(path);
    } catch {
      // 이미 있으면 무시
    }
  }

  let loaded = 0;
  onProgress({ phase: '3D 모델 내려받는 중', loaded, total: files.length });
  await Promise.all(
    files.map(async ({ url, dest }) => {
      const buf = await fetch(url).then((r) => {
        if (!r.ok) throw new Error(`모델 파일을 받지 못했습니다: ${url} (${r.status})`);
        return r.arrayBuffer();
      });
      mj.FS.writeFile(dest, new Uint8Array(buf));
      loaded += 1;
      onProgress({ phase: '3D 모델 내려받는 중', loaded, total: files.length });
    }),
  );

  onProgress({ phase: '모델 컴파일 중', loaded: files.length, total: files.length });
  const model = mj.MjModel.from_xml_path(`${dir}/scene_sim.xml`);
  const data = new mj.MjData(model);
  mj.mj_forward(model, data);
  return new LampSim(mj, model, data, robot);
}

export class LampSim {
  readonly mj: MujocoModule;
  readonly robot: RobotSpec;
  readonly model: MjModel;
  readonly data: MjData;
  readonly dt: number;
  readonly limits: Record<JointName, [number, number]>;
  readonly headBodyId: number;
  readonly baseBodyId: number;

  /** 우리가 직접 누적하는 시뮬레이션 시각(초). 바인딩의 data.time 의미에 의존하지 않는다. */
  private simTime = 0;
  private readonly actId: Record<JointName, number>;
  private readonly qposAdr: Record<JointName, number>;
  /** freejoint 의 qpos 시작 주소 (없으면 -1) */
  private readonly freeAdr: number;
  /** 홈 상태에서 베이스 바디의 월드 포즈 — 기구학 프리뷰의 기준 */
  private readonly homeBasePos = new Float64Array(3);
  private readonly homeBaseQuat = new Float64Array(4);

  constructor(mj: MujocoModule, model: MjModel, data: MjData, robot: RobotSpec) {
    this.mj = mj;
    this.robot = robot;
    this.model = model;
    this.data = data;
    const dt = Number(model.opt?.timestep);
    if (!Number.isFinite(dt) || dt <= 0) {
      throw new Error(`모델 타임스텝을 읽지 못했습니다 (timestep=${model.opt?.timestep})`);
    }
    this.dt = dt;

    const objAct = mj.mjtObj.mjOBJ_ACTUATOR.value;
    const objJnt = mj.mjtObj.mjOBJ_JOINT.value;
    const objBody = mj.mjtObj.mjOBJ_BODY.value;

    this.actId = {} as Record<JointName, number>;
    this.qposAdr = {} as Record<JointName, number>;
    this.limits = {} as Record<JointName, [number, number]>;

    for (const name of JOINT_NAMES) {
      const mjName = String(SERVO_ID[name]);
      const aid = mj.mj_name2id(model, objAct, mjName);
      const jid = mj.mj_name2id(model, objJnt, mjName);
      if (aid < 0 || jid < 0) throw new Error(`모델에서 관절 '${name}'(id ${mjName})을 찾을 수 없습니다`);
      this.actId[name] = aid;
      this.qposAdr[name] = model.jnt_qposadr[jid];
      this.limits[name] = [
        model.actuator_ctrlrange[aid * 2] * RAD,
        model.actuator_ctrlrange[aid * 2 + 1] * RAD,
      ];
    }

    this.headBodyId = mj.mj_name2id(model, objBody, robot.headBody);
    this.baseBodyId = mj.mj_name2id(model, objBody, robot.baseBody);

    // mjJNT_FREE === 0
    let freeAdr = -1;
    for (let j = 0; j < model.njnt; j++) {
      if (model.jnt_type[j] === 0) {
        freeAdr = model.jnt_qposadr[j];
        break;
      }
    }
    this.freeAdr = freeAdr;

    // 홈 자세에서의 베이스 포즈를 기억해 둔다.
    mj.mj_resetData(model, data);
    mj.mj_forward(model, data);
    this.homeBasePos.set(data.xpos.subarray(this.baseBodyId * 3, this.baseBodyId * 3 + 3));
    this.homeBaseQuat.set(data.xquat.subarray(this.baseBodyId * 4, this.baseBodyId * 4 + 4));
  }

  /** 시뮬레이션 경과 시간(초) */
  get time(): number {
    return this.simTime;
  }

  /** MuJoCo 가 들고 있는 시각 — 디버깅용 */
  get engineTime(): number {
    return this.data.time;
  }

  /** 현재 서보에 지령된 목표 각도(도) */
  get targets(): Pose {
    const ctrl = this.data.ctrl;
    const out = {} as Pose;
    for (const n of JOINT_NAMES) out[n] = ctrl[this.actId[n]] * RAD;
    return out;
  }

  /** 실제로 측정된 관절 각도(도) */
  get pose(): Pose {
    const qpos = this.data.qpos;
    const out = {} as Pose;
    for (const n of JOINT_NAMES) out[n] = qpos[this.qposAdr[n]] * RAD;
    return out;
  }

  clamp(joint: JointName, degrees: number): number {
    const [lo, hi] = this.limits[joint];
    return Math.min(Math.max(degrees, lo), hi);
  }

  /** 관절 하나의 목표 각도를 설정한다. 리밋을 넘으면 잘라낸 값을 돌려준다. */
  setJoint(joint: JointName, degrees: number): number {
    const value = this.clamp(joint, degrees);
    this.data.ctrl[this.actId[joint]] = value * DEG;
    return value;
  }

  setPose(pose: PartialPose): void {
    for (const [k, v] of Object.entries(pose)) {
      if (v !== undefined) this.setJoint(k as JointName, v);
    }
  }

  /**
   * 물리 없이 즉시 자세를 만든다 — 타임라인 스크러빙용.
   *
   * 이 모델은 트리 루트가 아래팔이고 베이스가 그 자식이라, 관절 qpos 만 넣고
   * forward 하면 팔이 아니라 베이스가 움직인다 (평소엔 weld 구속이 물리로 풀어 준다).
   * 그래서 forward 후 베이스를 홈 포즈로 되돌리는 강체 보정을 freejoint 에 적용한다.
   * 결과적으로 베이스는 정확히 고정되고 관절각은 지령값 그대로가 된다.
   */
  poseKinematic(pose: PartialPose): void {
    const { mj, model, data } = this;
    mj.mj_resetData(model, data);
    for (const [key, value] of Object.entries(pose)) {
      if (value === undefined) continue;
      const name = key as JointName;
      data.qpos[this.qposAdr[name]] = this.clamp(name, value) * DEG;
      data.ctrl[this.actId[name]] = this.clamp(name, value) * DEG;
    }
    mj.mj_forward(model, data);

    if (this.freeAdr >= 0) {
      const b = this.baseBodyId;
      const bp = data.xpos.subarray(b * 3, b * 3 + 3);
      const bq = data.xquat.subarray(b * 4, b * 4 + 4);

      // corr = homeQuat * baseQuat⁻¹  (베이스를 홈 방향으로 되돌리는 회전)
      const corr = quatMul(this.homeBaseQuat, quatConj(bq));
      const rootP = data.qpos.subarray(this.freeAdr, this.freeAdr + 3);
      const rootQ = data.qpos.subarray(this.freeAdr + 3, this.freeAdr + 7);

      const rel = quatRotate(corr, [rootP[0] - bp[0], rootP[1] - bp[1], rootP[2] - bp[2]]);
      const newQ = quatMul(corr, rootQ);
      for (let i = 0; i < 3; i++) data.qpos[this.freeAdr + i] = this.homeBasePos[i] + rel[i];
      for (let i = 0; i < 4; i++) data.qpos[this.freeAdr + 3 + i] = newQ[i];

      data.qvel.fill(0);
      mj.mj_forward(model, data);
    }
  }

  /** 기구학 프리뷰 후 물리 재생으로 돌아갈 때 — 현재 자세를 지령으로 삼고 속도를 지운다. */
  freezeIntoPhysics(): void {
    this.data.qvel.fill(0);
    this.mj.mj_forward(this.model, this.data);
  }

  step(n = 1): void {
    if (!Number.isFinite(n) || n <= 0) return;
    const count = Math.min(Math.floor(n), 2000);
    for (let i = 0; i < count; i++) this.mj.mj_step(this.model, this.data);
    this.simTime += count * this.dt;
  }

  reset(pose?: PartialPose): void {
    this.mj.mj_resetData(this.model, this.data);
    this.simTime = 0;
    const ctrl = this.data.ctrl;
    for (let i = 0; i < ctrl.length; i++) ctrl[i] = 0;
    if (pose) this.setPose(pose);
    this.mj.mj_forward(this.model, this.data);
  }
}
