# PURE App — 개발 규칙

코드 주석의 "규칙 N"은 아래 번호를 가리킨다.

## 스택
Flutter / Dart · Provider · flutter_inappwebview(InAppLocalhostServer) · image_picker · video_thumbnail · speech_to_text · path_provider · shared_preferences · wakelock_plus · http.
`sim/`은 Vite + TypeScript 웹 모듈이고 MuJoCo wasm을 런타임에 불러온다. 외부와의 계약은 `sim/src/api.ts`(`window.pure`) 하나.
생성은 `services/generation/GenerationClient`(OpenAI / Demo / Fake), 데이터는 `repositories/` 인터페이스.

## 규칙
1. 요청 범위만 바꾼다. 다른 화면·파일을 미리 만들지 않는다.
2. 디자인 단계에서는 models / services / repositories / providers / data / sim을 바꾸지 않는다. theme / screens / widgets만.
3. 시뮬 봉인: `sim/` 내부는 바꾸지 않는다. 계약은 `sim/src/api.ts`(window.pure) 하나.
4. 로직 단계는 회색 박스로 동작만 만든다.
5. 큰 단계(스캐폴드 · sim 추출 · 브리지 · 생성 서비스 · 화면 번역)는 코드 전에 계획부터.
6. 한 번에 하나. `flutter run` / `flutter test` 후 커밋하고 `docs/decisions.md`에 한 줄.
7. 픽셀·색·간격은 Figma 값 그대로. 추측하지 않는다.
8. 콘텐츠(칩 · 질문 · 상황 · 문구 · 더미 · 데모 레시피)는 `data/`에. 하드코딩하지 않는다. 문구는 영어, `strings.dart` 키.
9. 색·타이포는 `theme/` 토큰. 위젯에 hex를 쓰지 않는다.
10. GPT 출력은 반드시 `motion_engine` 검증(허용 목록 · 범위 클램프)을 거친다. 동작 · 얼굴 이름은 `data/behaviors.dart` 허용 목록만.
11. 생성 실패 · 오프라인 · 키 없음은 항상 데모 모드로 폴백한다. 시연 경로가 죽는 변경은 하지 않는다.
12. OpenAI 키는 `--dart-define`으로만 넘긴다. 코드 · .env · 커밋 · 로그에 남기지 않는다. 영상 · 프레임은 앱 밖으로 나가지 않는다(API 전송 제외).
13. 실험 기능(directClip 등)은 기능 플래그 아래, 기본 off. off일 때 기존 테스트가 모두 통과해야 한다.
14. `sim/`은 WebView 인스턴스 1개(wasm 컴파일 비용). 화면마다 새로 만들지 않는다.
