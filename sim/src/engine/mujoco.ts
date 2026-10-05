/**
 * MuJoCo WASM 로더.
 *
 * 엔진(`@mujoco/mujoco`)은 emscripten 이 뽑아낸 번들이라 브라우저 번들러에 그대로
 * 태울 수 없다 — 노드 분기에서 `await import('module')` / `require('fs')` 를 부르고,
 * 10MB 짜리 wasm 을 `new URL('mujoco.wasm', import.meta.url)` 으로 자기 옆에서 찾는다.
 * 그래서 엔진 파일 두 개를 `public/mujoco/` 에 그대로 두고 런타임에 URL 로 import 한다.
 * 번들러는 이 import 를 건드리지 않고(@vite-ignore), wasm 은 정적 파일로 서빙되며
 * 자바스크립트 번들에는 아무것도 들어가지 않는다.
 *
 * PURE 수정: 원본의 webpackIgnore/turbopackIgnore 주석은 Vite 에서 아무 효력이 없다.
 * 또 URL 을 모듈 상수로 두면 Vite 가 빌드 타임에 해석하려 들기 때문에 호출 시점에 만든다.
 * mujoco.js 와 mujoco.wasm 은 반드시 같은 폴더에 있어야 한다 — wasm 은 엔진이 자기
 * import.meta.url 기준으로 직접 찾는다.
 */

import { assetUrl } from './paths';

/** 바인딩이 노출하는 필드는 전부 TypedArray 라 느슨하게 둔다 (파이썬 쪽과 같은 이름). */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type MjModel = Record<string, any>;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type MjData = Record<string, any>;

export interface MujocoModule {
  FS: {
    mkdir(path: string): void;
    writeFile(path: string, data: Uint8Array): void;
  };
  MjModel: { from_xml_path(path: string): MjModel };
  MjData: new (model: MjModel) => MjData;
  mjtObj: Record<string, { value: number }>;
  mj_forward(model: MjModel, data: MjData): void;
  mj_step(model: MjModel, data: MjData): void;
  mj_resetData(model: MjModel, data: MjData): void;
  mj_name2id(model: MjModel, type: number, name: string): number;
}

type MujocoFactory = () => Promise<MujocoModule>;

let engine: Promise<MujocoModule> | null = null;

/** 엔진은 탭 하나에 한 번만 올린다 (10MB wasm 컴파일 비용). */
export function loadMujoco(): Promise<MujocoModule> {
  engine ??= import(/* @vite-ignore */ assetUrl('mujoco/mujoco.js')).then(
    (mod: { default: MujocoFactory }) => mod.default(),
  );
  return engine;
}
