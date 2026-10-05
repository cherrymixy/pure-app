# 결정 로그 (decisions.md)

> STEP 하나 끝날 때마다 한 줄. 형식: `YYYY-MM-DD · STEP n · 결정/결과`

| 날짜 | STEP | 결정 · 결과 |
|---|---|---|
| 2026-10-06 | 0 | 시작 전 세팅 완료. 폴더 구조 플레이북대로 정리(CLAUDE.md 루트, `_ref/pure-web`), git init(main), .gitignore에 `_ref/` 제외. Figma MCP 연결 확인(whoami OK, 파일 `xp0RmyE9WwsNFAF5kE88OX` 3개 페이지 접근 가능). iOS 시뮬레이터 iPhone 17 Pro / iOS 26.2 부팅. Flutter 3.44.2 · Dart 3.12.2 · Xcode 26.2 · CocoaPods 1.16.2 · Node 25.9.0. |
| 2026-10-06 | 0 | 전시 기기 확정: iPhone 14 Pro(393×852pt), 개발자 모드 ON, 무료 서명 사용(7일 만료 → 전시 전날 재설치). OpenAI 키 확보 완료(STEP 7에서 사용). 시뮬레이터도 14 Pro로 교체. |
| 2026-10-06 | 0 | 부록 D 13개 항목 전부 추천대로 승인. 신규 6건 포함: Clip 모양은 부록 B(관절별 트랙) 채택 / reasoning 영어 / Figma 402 vs 기기 393은 비율 번역 / stop()은 setIdle 전환 / joint_ranges.dart 폐기. |
| 2026-10-06 | 0 | 부록 B 계약 수정 3건 승인: (가) Clip 어댑터 + loop 기본값 명시 (나) setFace 유효 이름을 faces.json 값에서 도출 (다) ready 이벤트에 limits 실어 관절 범위를 런타임 전달. |
| 2026-10-06 | 0 | 범위 초과 포즈 4개(STRETCH +36° / SLEEP −12° / DROOP_DEEP −9° / DROOP −1°, 모두 head_tilt) → 옵션 (b) 채택. STEP 2에서 범위 안으로 리스케일. 사유: 현재는 한계에서 클램프되어 동작이 멈칫함. 영향 동작 wake·sleep·doze, 특히 doze는 Calm 성격의 대기 모션. |
| 2026-10-06 | 0 | 영상 프레임 추출: `video_thumbnail` → **`fc_native_video_thumbnail` ^3.0.1** 교체. 사유: 임의 타임스탬프 정확 추출을 실측 검증(단일 키프레임 8초 영상에서 8/8 정확, 246ms, 512px 긴 변 맞춤·회전 보정 자동). 기존 패키지는 SwiftPM 미지원으로 Flutter가 향후 에러 예고, 열린 이슈 65건. 비용: 최소 iOS 13 → **14.0**(전시 기기 14 Pro라 영향 없음). |
| 2026-10-06 | 0 | 음성 인식: `speech_to_text ^7.5.0` 유지하되 **`onDevice: true`를 쓰지 않는다**. 사유: iOS에서 미지원 기기일 때 에러 후에도 마이크가 살아남아 프로세스 수명 내내 재시작 불가(issue #673). 수정본은 7.6.0-beta.4에만 존재. 정식 출시 후 재검토. PRD §9 "기기 내 인식 우선"을 이 건에 한해 보류. |
| 2026-10-06 | 0 | Info.plist는 권한 4개(Camera/PhotoLibrary/Microphone/SpeechRecognition)만. **`NSAppTransportSecurity`/`NSAllowsLocalNetworking`은 넣지 않는다** — 무설정 상태로 WebView의 http://localhost:8080 로드 성공을 실측 확인. 플레이북 STEP 1 프롬프트에서 해당 줄 제외. |
| 2026-10-06 | 0 | **핵심 전제 검증 완료**: flutter_inappwebview 안에서 WebGL 2.0 + WASM 동작 확인(iOS 26.2 시뮬 / iPhone 14 Pro). 실측 — 셰이더 컴파일·링크 OK, readPixels 바이트 정확 일치, glGetError 0, UNMASKED_RENDERER=Apple GPU(소프트웨어 폴백 아님), MAX_TEXTURE_SIZE 8192, WASM instantiateStreaming OK. |
| 2026-10-06 | 0 | MuJoCo wasm은 공유 메모리/스레드 미사용 확인(wasm memory 섹션 flags=0x01, SHARED=false; 글루 코드에 SharedArrayBuffer·pthread_create·worker 참조 0건). → COOP/COEP 헤더 불필요, crossOriginIsolated=false가 문제되지 않음. |
| 2026-10-06 | 0 | **InAppLocalhostServer는 HTTP Range를 지원하지 않아 `<video src=http://localhost:8080/...>`가 WKWebView에서 재생 거부됨**(실측: Range 요청에 200+전체 파일 응답, MEDIA_ERR_SRC_NOT_SUPPORTED). → STEP 2에서 얼굴 mp4를 fetch + Blob URL로 로드하도록 viewer3d의 setFace 수정. 7개 3.1MB라 전량 프리페치가 오히려 전환 지연을 줄임. |
| 2026-10-06 | 0 | flutter_inappwebview ^6.1.5 유지(실측 동작). 리스크: 2024-10 이후 발행 없음, 열린 이슈 133건. 실제 기한은 iOS가 아니라 SwiftPM 전환(Flutter가 CocoaPods 전용 플러그인에 에러 예고). 완화: WebView 호출을 lib/sim/ 얇은 인터페이스 뒤에 격리, useShouldOverrideUrlLoading 사용 금지. 대안 경로는 webview_flutter + shelf_static(미검증). |
| 2026-10-06 | 0 | sim 번들 URL 규약: assets/sim/ 아래 배치 시 `http://localhost:8080/assets/sim/index.html` (asset key 그대로, assets/ 접두사 유지). pubspec에 `- assets/sim/` 선언 + 서버 start() 완료 후 WebView 로드. |
| 2026-10-06 | 1 | Flutter 스캐폴드 완료. Bundle ID `app.purebot.pure`, 최소 iOS **14.0**(Podfile·pbxproj 3곳), 세로 고정. 패키지 9개 설치, Info.plist 권한 4개(PRD §9 영문 그대로) + UIViewControllerBasedStatusBarAppearance=false, ATS 키 없음. `lib/config/env.dart`가 --dart-define 3개를 읽고 키 부재 시 데모 모드. iOS 시뮬(iPhone 14 Pro/26.2)에서 키 없음·있음 양쪽 실행 확인. analyze 0건, test 3개 통과. |
| 2026-10-06 | 2 | **앞선 "범위 초과 포즈 4개" 판단 정정.** behaviors.ts 의 값은 LeLamp 좌표계 원본이고 PURE Desk 로 가기 전 retarget(robots.ts PURE_DESK_RETARGET)을 거친다. 예: STRETCH wrist_pitch 78 → 리타겟 후 head_tilt −17.9°로 범위 안. 15종을 리타겟·오버레이 포함 1/120초 샘플링해 재측정한 결과, **amplitude 1.0 에서 초과는 `focus` 하나뿐(head_tilt −35.7°, 2.7° 초과)**. doze·sleep·wake 는 정상. |
| 2026-10-06 | 2 | 위 정정에 따라 (b)안 축소 적용: `focus` 의 FOCUS.wrist_pitch −20 → −12 한 값만 수정(게인 0.45 → head_tilt −31.7°). 나머지 behaviors.ts 는 원본 그대로 복사. 재측정 결과 amplitude 1.0 에서 15종 전부 범위 안. |
| 2026-10-06 | 2 | amplitude 1.5(시그니처 최대)에서는 wake(shoulder_pitch 12.4° 초과)·happy(head_tilt 4.5°)·focus(15.2°)가 범위를 넘는다. 원본 데이터 문제가 아니라 배율 정책 문제이므로 **STEP 6 validateRecipe/시그니처 매핑에서 처리**한다. 검증 스크립트는 sim/tools/check-ranges.ts 로 보존(번들 제외). |
| 2026-10-06 | 2 | `sim/` 모듈 추출 완료 (Vite + TS 독립 번들). 가져옴: motion·behaviors·robots·clip·mujoco·lamp·viewer3d. 버림: state-motion·exporters·React 컴포넌트 4개. 새로 씀: runtime.ts(rAF 루프·재생 슬롯·큐·대기모션·얼굴), api.ts(window.pure 계약·관절 이름 변환·클립 어댑터·검증), joints.ts, main.ts, paths.ts. |
| 2026-10-06 | 2 | 경로 3곳을 base-relative 로 바꾸고 `assetUrl()`(document.baseURI 기준)로 해석. mujoco.js 동적 import 에 `@vite-ignore`(원본의 webpackIgnore 는 Vite 에서 무효). viewer3d 에 `preserveDrawingBuffer: true` — 없으면 capture() 가 투명 PNG. |
| 2026-10-06 | 2 | 얼굴 mp4 7개를 부팅 시 fetch → Blob URL 로 프리로드(3.1MB). InAppLocalhostServer 의 Range 미지원 우회이자 전환 지연 제거. |
| 2026-10-06 | 2 | repeat 처리: loop 동작 6종은 finished() 가 영구 false 이고, 1회 동작을 아이템 분할로 반복하면 매번 0.8s lead-in 이 낀다. 양쪽 다 `loop=true + 시간 예산(leadIn + repeat×cycle)` 으로 통일. |
| 2026-10-06 | 2 | 재생 시계를 물리 시계에서 분리(`localT += wall × speed`). 원본은 `t = lamp.time - t0` 라 물리를 안 돌리면 재생이 t=0 에 멈췄다. speed 의 유일한 적용 지점. amplitude 는 retargetMotion 직후 MotionPlayer 생성 전에 Motion 을 미리 스케일. |
| 2026-10-06 | 2 | 검증: `tools/smoke.ts`(설치된 Chrome 헤드리스, 13건) + `tools/check-ranges.ts`. **운영 빌드를 `/assets/sim/` 하위 경로로 서빙한 상태에서 13건 전부 통과** — WebGL 2.0 err 0, 동작 15·얼굴 7 일치, limits 계약 이름, capture 313KB·817색, head_pan 클립 72.4° 이동(이름 변환 확인), 알 수 없는 동작·관절은 throw, stop 후 대기 모션 복귀. 포즈 프로브는 `?probe=1` 로만 열린다(앱에서는 닫힘). |
| 2026-10-06 | 3 | Sim ↔ Flutter 브리지 완료. `lib/sim/sim_controller.dart`(부록 B 거울 + Stream<SimEvent> + 호출 예외 전달), `lib/sim/sim_view.dart`(InAppWebView + InAppLocalhostServer 8080, 인스턴스 1개), `scripts/build_sim.sh`. 임시 확인 화면 `screens/sim_debug_screen.dart`는 STEP 10 에서 제거. |
| 2026-10-06 | 3 | **함정 1 — Flutter 의 폴더 에셋 선언은 하위 폴더를 포함하지 않는다.** `- assets/sim/` 만 적어서 index.html 만 번들에 들어가고 JS·wasm·모델·mp4 가 전부 빠졌다. 로컬 서버는 그래도 **200 에 0바이트**를 돌려줘서 에러 없이 로딩 화면에 멈춘다. 7개 폴더를 모두 선언하고, build_sim.sh 가 매 빌드마다 `find` 결과와 pubspec 을 대조해 빠진 줄을 출력하고 실패하도록 했다. |
| 2026-10-06 | 3 | 함정 2 — iOS 시뮬레이터는 맥의 네트워크를 공유하므로 맥에서 8080 을 쓰는 프로세스(종료 안 된 이전 빌드 포함)와 충돌한다. 실기기에서는 안 생긴다. `start()` 실패를 "이미 떠 있음"으로 뭉뚱그리지 않고, 그 포트에서 실제로 우리 번들(`id="stage"`)이 나오는지 확인해 가른다. 아니면 포트 번호를 적어 실패를 표시. |
| 2026-10-06 | 3 | 검증: `--dart-define=SIM_SELFTEST=true` 로 빌드하면 ready 직후 브리지 전체를 자동 실행하고 로그로 결과를 낸다. **iPhone 14 Pro / iOS 26.2 시뮬레이터에서 15건 전부 통과** — 동작 15·얼굴 7, head_tilt (-33,42), playBehavior→ended, playRecipe, setFace, capture 138KB, setIdle, 허용목록 밖 이름 throw, playClip(head_pan) 동작, 내부 이름(wrist_roll) 거부, 표정 mp4 readyState=4·480px·currentTime 0.00→0.82s 흐름, stop. |
| 2026-10-06 | 3 | **`sim/` 봉인** (CLAUDE.md 규칙 3). 이후 외부와의 계약은 `sim/src/api.ts` 의 window.pure 하나이며 변경은 사람 승인 사항. |
| 2026-10-06 | 4 | 데이터 모델 11개 (`models/`) — PRD §7 그대로, 전부 toJson/fromJson. Recipe·Clip 의 toJson 은 **window.pure 계약 모양 그대로**라 sim_controller 가 변환 없이 넘긴다. Clip 의 관절 키는 계약 이름(head_pan 등)이며 sim 내부 채널명을 쓰면 api.ts 가 거부한다. 선택 필드는 null 일 때 키 자체를 빼서 보낸다. |
| 2026-10-06 | 4 | 콘텐츠 8개 (`data/`) — behaviors(허용 목록 15·7·이징 7·관절 5·동작→표정 매핑), chips(5), situations(4), question_tree(칩별 when/how 각 3 + 폴백), signature_options(성격·관계·표현 3×3 + 축 매핑), strings(영어 문구 키), demo_recipes(칩 5 + 리프 15 + 폴백), seed(프로필·로봇·라이브러리 3·알림 3·행동기록 4·로봇탭 더미). |
| 2026-10-06 | 4 | 🟡 질문 트리 문구는 PRD 에 패턴과 예시 하나만 있어 나머지를 작성했다. 전시 대본 확정 시 `data/question_tree.dart` 만 고치면 된다. 데모 레시피는 조합 45개를 다 쓰지 않고 **2단계 답(how) 기준 15개**로 두고 없으면 칩 기본으로 폴백한다. |
| 2026-10-06 | 4 | 테스트 40건 통과. 핵심: 데모 레시피·시드·질문 트리의 모든 동작·표정이 허용 목록 안인지, PRD 범위(speed 0.5~1.6 등)를 지키는지, 칩 5개와 how 선택지 15개에 레시피가 다 있는지, 시드 라이브러리에 같은 상황의 auto 가 둘 이상 없는지, JSON 왕복에서 시그니처 스냅샷이 보존되는지. |
