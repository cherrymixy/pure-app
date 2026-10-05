import { defineConfig } from 'vite';

export default defineConfig({
  // Flutter 의 로컬 서버가 http://localhost:8080/assets/sim/ 하위에서 서빙하므로
  // 모든 참조가 문서 기준 상대여야 한다.
  base: './',
  build: {
    target: 'es2022',
    // mujoco.wasm(10MB)·표정 mp4 는 public/ 에 있어 번들에 안 들어간다.
    assetsInlineLimit: 0,
    chunkSizeWarningLimit: 2000,
  },
  server: { port: 5173, host: '127.0.0.1' },
});
