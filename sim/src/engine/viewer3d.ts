/**
 * MuJoCo 모델을 Three.js 로 그린다.
 *
 * 지오메트리는 MuJoCo 가 컴파일한 메시 데이터(mesh_vert/mesh_face)에서 직접 만든다.
 * STL 을 따로 파싱하지 않으므로 물리와 렌더가 항상 같은 형상을 쓴다.
 * 매 프레임 data.geom_xpos / geom_xmat(월드 변환)을 그대로 옮긴다.
 */

import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import type { LampSim } from './lamp';
import type { CameraView, FaceDisplay } from './robots';

export type { CameraView };

/** MuJoCo 는 Z-up, Three.js 는 Y-up. 루트 그룹을 눕혀서 맞춘다. */
const MJ_TO_WORLD = -Math.PI / 2;

/** 스테이지 색 — 페이지 배경(--color-bg)보다 살짝 밝게 두어 캔버스 경계가 보이게 한다. */
const STAGE = '#0a0a0d';
/** 브랜드 마젠타 (--color-accent) */
const ACCENT = '#f0126b';
/** 앰비언트 글로우의 바이올렛 */
const VIOLET = '#785cff';

const GEOM = {
  PLANE: 0,
  HFIELD: 1,
  SPHERE: 2,
  CAPSULE: 3,
  ELLIPSOID: 4,
  CYLINDER: 5,
  BOX: 6,
  MESH: 7,
} as const;

// 카메라 기본 시점과 전등갓 빔 위치는 로봇마다 다르다 — lib/lelamp/robots.ts 의
// heroView · beam 을 쓴다.

/** 둥근 사각형 외곽선 (원점 중심, 반폭 w · 반높이 h · 모서리 r) */
function roundedRect(w: number, h: number, r: number): THREE.Shape {
  const shape = new THREE.Shape();
  shape.moveTo(-w + r, -h);
  shape.lineTo(w - r, -h);
  shape.quadraticCurveTo(w, -h, w, -h + r);
  shape.lineTo(w, h - r);
  shape.quadraticCurveTo(w, h, w - r, h);
  shape.lineTo(-w + r, h);
  shape.quadraticCurveTo(-w, h, -w, h - r);
  shape.lineTo(-w, -h + r);
  shape.quadraticCurveTo(-w, -h, -w + r, -h);
  return shape;
}

/** 꺼진 화면 색 */
const SCREEN_OFF = '#000000';

/** MuJoCo 좌표 → Three 월드 좌표 (루트를 눕힌 것과 같은 변환) */
const toWorld = (x: number, y: number, z: number) => new THREE.Vector3(x, z, -y);

export class LampViewer {
  readonly scene = new THREE.Scene();
  readonly camera: THREE.PerspectiveCamera;
  readonly renderer: THREE.WebGLRenderer;
  readonly controls: OrbitControls;
  /** MuJoCo 좌표계를 그대로 쓰는 그룹 */
  readonly root = new THREE.Group();

  private readonly lamp: LampSim;
  private readonly geomNodes: { geomId: number; node: THREE.Object3D }[] = [];
  private readonly headGroup = new THREE.Group();
  private beam: THREE.SpotLight | null = null;
  /** 얼굴 디스플레이 — 머리 바디를 따라다니고 표정 영상을 띄운다. */
  private screen: { material: THREE.MeshBasicMaterial; spec: FaceDisplay } | null = null;
  private video: HTMLVideoElement | null = null;
  private videoTexture: THREE.VideoTexture | null = null;
  private faceUrl: string | null = null;
  private readonly tmpMat = new THREE.Matrix4();

  constructor(canvas: HTMLCanvasElement, lamp: LampSim) {
    this.lamp = lamp;

    // PURE 수정: preserveDrawingBuffer. 없으면 합성 후 드로잉 버퍼가 비워져서
    // 렌더 프레임 밖에서 호출하는 capture()(= canvas.toDataURL)가 투명 PNG를 돌려준다.
    // 라이브러리 썸네일이 이 경로를 쓴다. 대가는 약간의 fill-rate.
    this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true, preserveDrawingBuffer: true });
    this.renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.5;

    // PURE 다크 팔레트에 맞춘 스테이지 색 (globals.css 의 --color-bg 계열).
    this.scene.background = new THREE.Color(STAGE);
    this.scene.fog = new THREE.Fog(STAGE, 2.2, 6);

    this.camera = new THREE.PerspectiveCamera(38, 1, 0.01, 50);
    this.root.rotation.x = MJ_TO_WORLD;
    this.scene.add(this.root);
    this.root.add(this.headGroup);

    this.addLights();
    this.addFloor();
    this.buildGeoms();
    this.buildScreen();

    this.controls = new OrbitControls(this.camera, this.renderer.domElement);
    this.controls.enableDamping = true;
    this.controls.dampingFactor = 0.08;
    this.controls.minDistance = 0.3;
    this.controls.maxDistance = 4;
    this.controls.maxPolarAngle = Math.PI * 0.495;
    this.setView(lamp.robot.heroView);
    this.sync();
  }

  // ---------------------------------------------------------------- 장면 구성

  private addLights(): void {
    this.scene.add(new THREE.HemisphereLight('#9aa2c2', '#141419', 2.1));

    const key = new THREE.DirectionalLight('#fff2e0', 3.0);
    key.position.set(1.2, 2.0, 1.1);
    key.castShadow = true;
    key.shadow.mapSize.set(2048, 2048);
    key.shadow.camera.near = 0.4;
    key.shadow.camera.far = 6;
    const d = 1.0;
    key.shadow.camera.left = -d;
    key.shadow.camera.right = d;
    key.shadow.camera.top = d;
    key.shadow.camera.bottom = -d;
    key.shadow.bias = -0.0012;
    this.scene.add(key);

    // 브랜드 림 — 홈 화면의 앰비언트 글로우(마젠타 + 바이올렛)와 같은 색을 쓴다.
    const rim = new THREE.DirectionalLight(ACCENT, 0.55);
    rim.position.set(-1.4, 0.9, -1.2);
    this.scene.add(rim);

    const fill = new THREE.DirectionalLight(VIOLET, 0.35);
    fill.position.set(1.5, 0.6, -1.4);
    this.scene.add(fill);

    // 램프가 실제로 쏘는 빔 — 전등갓 바디를 따라다닌다. 빔이 없는 로봇은 건너뛴다.
    const spec = this.lamp.robot.beam;
    if (!spec) return;
    const beamPos = new THREE.Vector3(...spec.pos);
    const beamDir = new THREE.Vector3(...spec.dir).normalize();
    const beam = new THREE.SpotLight('#ffe6b0', 26, 3.2, THREE.MathUtils.degToRad(30), 0.45, 1.4);
    beam.position.copy(beamPos);
    beam.castShadow = true;
    beam.shadow.mapSize.set(1024, 1024);
    beam.shadow.camera.near = 0.02;
    beam.shadow.camera.far = 3.2;
    const target = new THREE.Object3D();
    target.position.copy(beamPos).addScaledVector(beamDir, 2);
    this.headGroup.add(beam, target);
    beam.target = target;
    this.beam = beam;
  }

  private addFloor(): void {
    const floor = new THREE.Mesh(
      new THREE.CircleGeometry(3.2, 64),
      new THREE.MeshStandardMaterial({ color: '#141419', roughness: 0.9, metalness: 0.04 }),
    );
    floor.receiveShadow = true;
    this.root.add(floor);

    const grid = new THREE.GridHelper(4, 40, 0x33333a, 0x212127);
    grid.rotation.x = Math.PI / 2;
    grid.position.z = 0.001;
    (grid.material as THREE.Material).opacity = 0.45;
    (grid.material as THREE.Material).transparent = true;
    this.root.add(grid);
  }

  private geomColor(geomId: number): THREE.Color {
    const { model } = this.lamp;
    const matId: number = model.geom_matid[geomId];
    const rgba = matId >= 0 ? model.mat_rgba : model.geom_rgba;
    const base = matId >= 0 ? matId * 4 : geomId * 4;
    // MuJoCo 의 rgba 는 화면에 그대로 찍히는(sRGB) 값이라, 선형 작업 색공간으로 변환해 넣는다.
    return new THREE.Color().setRGB(rgba[base], rgba[base + 1], rgba[base + 2], THREE.SRGBColorSpace);
  }

  private meshGeometry(dataId: number): THREE.BufferGeometry {
    const { model } = this.lamp;
    const vertAdr: number = model.mesh_vertadr[dataId];
    const faceAdr: number = model.mesh_faceadr[dataId];
    const faceNum: number = model.mesh_facenum[dataId];

    // 면마다 정점을 펼쳐(non-indexed) 각지게 셰이딩한다 — MuJoCo 렌더와 같은 인상.
    const positions = new Float32Array(faceNum * 9);
    for (let f = 0; f < faceNum; f++) {
      for (let k = 0; k < 3; k++) {
        const vi: number = model.mesh_face[(faceAdr + f) * 3 + k];
        const src = (vertAdr + vi) * 3;
        const dst = f * 9 + k * 3;
        positions[dst] = model.mesh_vert[src];
        positions[dst + 1] = model.mesh_vert[src + 1];
        positions[dst + 2] = model.mesh_vert[src + 2];
      }
    }
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    geometry.computeVertexNormals();
    return geometry;
  }

  private primitiveGeometry(geomId: number): THREE.BufferGeometry | null {
    const { model } = this.lamp;
    const s = (i: number) => model.geom_size[geomId * 3 + i] as number;
    switch (model.geom_type[geomId]) {
      case GEOM.SPHERE:
        return new THREE.SphereGeometry(s(0), 24, 16);
      case GEOM.BOX:
        return new THREE.BoxGeometry(s(0) * 2, s(1) * 2, s(2) * 2);
      case GEOM.CYLINDER:
        return new THREE.CylinderGeometry(s(0), s(0), s(1) * 2, 24).rotateX(Math.PI / 2);
      case GEOM.CAPSULE:
        return new THREE.CapsuleGeometry(s(0), s(1) * 2, 6, 16).rotateX(Math.PI / 2);
      case GEOM.ELLIPSOID: {
        const g = new THREE.SphereGeometry(1, 24, 16);
        g.scale(s(0), s(1), s(2));
        return g;
      }
      default:
        return null;
    }
  }

  private buildGeoms(): void {
    const { model } = this.lamp;
    for (let g = 0; g < model.ngeom; g++) {
      // group 3 은 충돌 전용 지오메트리 — 그리지 않는다. 바닥은 직접 만든 걸 쓴다.
      if (model.geom_group[g] === 3) continue;
      if (model.geom_type[g] === GEOM.PLANE || model.geom_type[g] === GEOM.HFIELD) continue;

      const geometry =
        model.geom_type[g] === GEOM.MESH
          ? this.meshGeometry(model.geom_dataid[g])
          : this.primitiveGeometry(g);
      if (!geometry) continue;

      const mesh = new THREE.Mesh(
        geometry,
        new THREE.MeshStandardMaterial({
          color: this.geomColor(g),
          roughness: 0.5,
          metalness: 0.18,
        }),
      );
      mesh.castShadow = true;
      mesh.receiveShadow = true;
      mesh.matrixAutoUpdate = false;
      this.root.add(mesh);
      this.geomNodes.push({ geomId: g, node: mesh });
    }
  }

  /**
   * 머리의 화면 패널. MuJoCo 메시는 UV 가 없어 영상을 입힐 수 없으므로 뷰어가 직접
   * 만든다. 보이는 개구부(halfWidth × halfHeight)에 UV 0..1 을 맞추고, bleed 만큼
   * 베젤 아래로 더 키워 가장자리 틈이 보이지 않게 한다.
   */
  private buildScreen(): void {
    const spec = this.lamp.robot.display;
    if (!spec) return;
    const { halfWidth: w, halfHeight: h, radius: r, bleed: b } = spec;
    const geometry = new THREE.ShapeGeometry(roundedRect(w + b, h + b, r + b), 16);
    const pos = geometry.attributes.position;
    const uv = new Float32Array(pos.count * 2);
    for (let i = 0; i < pos.count; i++) {
      uv[i * 2] = pos.getX(i) / (2 * w) + 0.5;
      uv[i * 2 + 1] = pos.getY(i) / (2 * h) + 0.5;
    }
    geometry.setAttribute('uv', new THREE.BufferAttribute(uv, 2));
    // ShapeGeometry 는 XY 평면에서 +Z 를 본다 → X 축으로 90° 돌려 XZ 평면에서 −Y 를 보게.
    geometry.rotateX(Math.PI / 2);
    geometry.translate(...spec.center);

    // 화면은 스스로 빛나므로 조명·톤매핑을 받지 않는다.
    const material = new THREE.MeshBasicMaterial({ color: SCREEN_OFF, toneMapped: false });
    const mesh = new THREE.Mesh(geometry, material);
    this.headGroup.add(mesh);
    this.screen = { material, spec };
  }

  /** 표정 영상을 바꾼다. null 이면 화면을 끈다. 같은 URL 이면 그대로 이어서 재생한다. */
  setFace(url: string | null): void {
    if (!this.screen || url === this.faceUrl) return;
    this.faceUrl = url;
    const { material } = this.screen;

    if (!url) {
      this.video?.pause();
      material.map = null;
      material.color.set(SCREEN_OFF);
      material.needsUpdate = true;
      return;
    }

    if (!this.video) {
      const video = document.createElement('video');
      video.muted = true;
      video.loop = true;
      video.playsInline = true;
      video.crossOrigin = 'anonymous';
      video.preload = 'auto';
      // 새 영상의 첫 프레임이 준비된 뒤에 바꿔 끼워 검은 깜빡임을 줄인다.
      video.addEventListener('loadeddata', () => this.attachVideo());
      this.video = video;
    }
    this.video.src = url;
    this.video.play().catch(() => {
      // 자동 재생이 막힌 경우 — 음소거 영상이라 보통은 막히지 않는다.
    });
  }

  private attachVideo(): void {
    const video = this.video;
    if (!this.screen || !video || !this.faceUrl) return;
    const { material, spec } = this.screen;
    if (!this.videoTexture) {
      this.videoTexture = new THREE.VideoTexture(video);
      this.videoTexture.colorSpace = THREE.SRGBColorSpace;
    }
    // 영상 비율이 화면(5:3 등)과 달라도 꽉 채우고 넘치는 쪽을 잘라낸다 (cover).
    const tex = this.videoTexture;
    const screenAspect = spec.halfWidth / spec.halfHeight;
    const videoAspect = video.videoWidth / Math.max(video.videoHeight, 1);
    if (videoAspect > screenAspect) {
      const k = screenAspect / videoAspect;
      tex.repeat.set(k, 1);
      tex.offset.set((1 - k) / 2, 0);
    } else {
      const k = videoAspect / screenAspect;
      tex.repeat.set(1, k);
      tex.offset.set(0, (1 - k) / 2);
    }
    material.map = tex;
    material.color.set('#ffffff');
    material.needsUpdate = true;
  }

  /** 뷰어를 버릴 때 — 영상 디코더와 GPU 자원을 놓는다. */
  dispose(): void {
    if (this.video) {
      this.video.pause();
      this.video.removeAttribute('src');
      this.video.load();
    }
    this.videoTexture?.dispose();
    this.renderer.dispose();
  }

  // ---------------------------------------------------------------- 매 프레임

  /** 시뮬레이션 상태를 3D 씬에 반영한다. */
  sync(): void {
    const { data } = this.lamp;
    const xpos = data.geom_xpos;
    const xmat = data.geom_xmat;

    for (const { geomId, node } of this.geomNodes) {
      const p = geomId * 3;
      const m = geomId * 9;
      // geom_xmat 은 행 우선(row-major). Matrix4.set 도 행 우선 인자를 받는다.
      this.tmpMat.set(
        xmat[m], xmat[m + 1], xmat[m + 2], xpos[p],
        xmat[m + 3], xmat[m + 4], xmat[m + 5], xpos[p + 1],
        xmat[m + 6], xmat[m + 7], xmat[m + 8], xpos[p + 2],
        0, 0, 0, 1,
      );
      node.matrix.copy(this.tmpMat);
      node.matrixWorldNeedsUpdate = true;
    }

    // 전등갓 바디를 따라가는 빔
    const b = this.lamp.headBodyId;
    if (b >= 0) {
      this.headGroup.position.set(data.xpos[b * 3], data.xpos[b * 3 + 1], data.xpos[b * 3 + 2]);
      // MuJoCo 쿼터니언은 (w,x,y,z), Three 는 (x,y,z,w)
      this.headGroup.quaternion.set(
        data.xquat[b * 4 + 1],
        data.xquat[b * 4 + 2],
        data.xquat[b * 4 + 3],
        data.xquat[b * 4],
      );
    }
  }

  setBeamEnabled(on: boolean): void {
    if (this.beam) this.beam.visible = on;
  }

  setView(view: CameraView): void {
    const az = THREE.MathUtils.degToRad(view.azimuth);
    const el = THREE.MathUtils.degToRad(view.elevation);
    // MuJoCo 자유 카메라와 같은 정의: forward = (cos el cos az, cos el sin az, sin el)
    const fx = Math.cos(el) * Math.cos(az);
    const fy = Math.cos(el) * Math.sin(az);
    const fz = Math.sin(el);
    const [lx, ly, lz] = view.lookAt;
    const target = toWorld(lx, ly, lz);
    const pos = toWorld(
      lx - view.distance * fx,
      ly - view.distance * fy,
      lz - view.distance * fz,
    );
    this.camera.position.copy(pos);
    this.controls.target.copy(target);
    this.controls.update();
  }

  resize(width: number, height: number): void {
    this.camera.aspect = width / Math.max(height, 1);
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(width, height, false);
  }

  render(): void {
    this.controls.update();
    this.renderer.render(this.scene, this.camera);
  }
}
