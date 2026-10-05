/**
 * 진입점 — 캔버스를 전체 화면으로 깔고 window.pure 를 설치한다.
 * 로딩/오류 표시 외에 UI 는 없다. 화면은 Flutter 가 그린다.
 */

import { install, type PureApi } from './api';
import { publicPose } from './runtime';

declare global {
  interface Window {
    pure: PureApi;
  }
}

const canvas = document.getElementById('stage') as HTMLCanvasElement | null;
const status = document.getElementById('status') as HTMLElement | null;

if (!canvas) throw new Error('#stage 캔버스를 찾을 수 없습니다');

const setStatus = (text: string | null): void => {
  if (!status) return;
  status.textContent = text ?? '';
  status.style.display = text ? 'flex' : 'none';
};

setStatus('Loading…');

window.pure = install(canvas, (p: unknown) => {
  const prog = p as { phase?: string; loaded?: number; total?: number };
  if (!prog?.phase) return;
  const total = prog.total ?? 0;
  setStatus(total > 1 ? `${prog.phase} ${prog.loaded ?? 0}/${total}` : prog.phase);
});

/*
 * 검증용 통로. 계약(window.pure)에는 들어가지 않는다.
 * 개발 서버에서는 항상, 운영 빌드에서는 ?probe=1 일 때만 열린다 — 실제 배포 산출물을
 * 그대로 자동 검사하기 위해서다. Flutter 는 이 쿼리를 붙이지 않으므로 앱에서는 닫혀 있다.
 */
if (import.meta.env.DEV || new URLSearchParams(location.search).has('probe')) {
  (window as unknown as { __simPose: () => Record<string, number> }).__simPose = publicPose;
}

window.pure.ready.then(
  () => setStatus(null),
  (err: unknown) => setStatus(err instanceof Error ? err.message : String(err)),
);
