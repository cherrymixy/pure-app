/**
 * 에셋 경로 해석.
 *
 * 원본(Next.js)은 모든 에셋을 `/mujoco/...` 같은 절대 경로로 찾았다. Vite 를 `base: './'`
 * 로 빌드해 Flutter 의 로컬 서버가 `http://localhost:8080/assets/sim/` 같은 하위 경로에서
 * 서빙하면 그 절대 경로는 전부 404 가 된다.
 *
 * 선행 슬래시를 떼는 것만으로는 부족하다 — 소비처들이 `${base}/manifest.json` 처럼 문자열을
 * 이어 붙이기 때문에, 문서 위치를 기준으로 정식 URL 을 만들어 돌려준다.
 */
export const assetUrl = (path: string): string =>
  new URL(path.replace(/^\/+/, ''), document.baseURI).href;
