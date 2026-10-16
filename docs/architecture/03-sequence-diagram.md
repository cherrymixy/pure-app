# 3. Sequence Diagram

핵심 시나리오 다섯 개를 시간 순서로 정리한다.

1. 앱 부팅과 시뮬레이터 준비
2. 상황 칩 → 질문 → 모션 생성 → 재생 (기본 시연 경로)
3. 영상 입력으로 생성
4. 생성 실패 시 3단 폴백
5. 피드백 재생성과 라이브러리 저장

---

## 3.1 앱 부팅과 시뮬레이터 준비

```mermaid
sequenceDiagram
  autonumber
  participant OS as iOS
  participant Main as main.dart
  participant Repo as LocalRepository
  participant Host as SimHost
  participant View as SimView
  participant Srv as InAppLocalhostServer
  participant WV as WKWebView
  participant Pure as window.pure (sim)
  participant Ctrl as SimController
  participant Splash as SplashScreen

  OS->>Main: 앱 실행
  Main->>Main: Wakelock 켜기 (전시 중 화면 유지)
  Main->>Repo: init() — pure_state.json 읽기
  Repo-->>Main: 메모리에 상태 적재 (없으면 시드 데이터)
  Main->>Host: runApp → MultiProvider + SimHost
  Host->>Splash: 스플래시 표시
  par 스플래시 뒤에서 시뮬 준비
    Host->>View: WebView 1개 생성 (화면 밖 슬롯)
    View->>Srv: start() :8080
    Srv-->>View: 준비 완료
    View->>WV: load localhost:8080/assets/sim/index.html
    WV->>Pure: main.ts → install(canvas)
    Pure->>Pure: MuJoCo wasm 컴파일 · robot.xml 로드 · 얼굴 mp4 프리페치
    Pure-->>Ctrl: callHandler('pureEvent', {type:'ready', limits, behaviors, faces})
    Ctrl->>Ctrl: ready Completer 완료
  end
  Splash->>Host: 홈으로 페이드 전환
  Host->>Host: 홈 화면의 SimSlot 위치로 WebView 이동
```

---

## 3.2 상황 칩 → 질문 → 생성 → 재생 (기본 경로)

```mermaid
sequenceDiagram
  autonumber
  actor U as 사용자
  participant Home as HomeScreen
  participant Chat as ChatProvider
  participant Gen as GenerationProvider
  participant Svc as GenerationService
  participant AI as OpenAIClient
  participant Eng as MotionEngine
  participant Ctrl as SimController
  participant Sim as window.pure
  participant Repo as LocalRepository
  participant Thumb as ThumbnailStore

  U->>Home: 칩 "Someone came home" 탭
  Home->>Chat: addUserMessage
  Home-->>U: 질문 1 "When should Purebot do this?" (data/question_tree)
  U->>Home: 언제 선택지
  Home-->>U: 질문 2 "How should it react?"
  U->>Home: 어떻게 선택지
  Home->>Chat: addPendingReply (타이핑 표시)
  Home->>Gen: generate(GenerationRequest{signature, text, chipId, when, how, situation})
  Gen->>Svc: generate(request, onDelay)
  Svc->>Svc: 이전 요청 취소, CancelToken 발급
  Svc->>AI: generate(request)
  AI->>AI: 시스템 프롬프트 + 시그니처 문장 + 상황 문장 조립
  AI->>AI: POST /v1/chat/completions (gpt-4o-mini, json_schema strict)
  Note over AI: 20초 경과 시 onDelay → "조금 더 걸려요" 안내<br/>60초 하드 타임아웃
  AI-->>Svc: GenerationResult{spec, source: openai, raw}
  Svc->>Eng: validateRecipe(recipe)
  Eng-->>Svc: 모르는 동작 제거, 범위 클램프, 사유 목록
  Svc->>Eng: signatureToParams(signature) → applySignature
  Eng-->>Svc: 속도·진폭 배율이 곱해진 Recipe
  Svc-->>Gen: 최종 GenerationResult (이름 ≤20자)
  Gen-->>Home: result
  Home->>Chat: completeReply(messageId, spec)
  Chat->>Repo: upsertChat → JsonStore.schedule (디바운스 저장)
  Home->>Ctrl: playRecipe(recipe.toJson())
  Ctrl->>Sim: evaluateJavascript("window.pure.playRecipe(...)")
  Sim->>Sim: 입력 검증 · 관절 이름 변환 · 재생 큐 등록
  Sim-->>Ctrl: pureEvent {type:'playing', id, duration}
  Home->>Ctrl: setFace(spec.face)
  Sim-->>U: 로봇이 움직이고 얼굴이 바뀜
  Home->>Home: 추정 재생 시간(0.6–4초) 대기
  Home->>Ctrl: capture()
  Ctrl->>Sim: window.pure.capture()
  Sim-->>Ctrl: PNG data URL (base64)
  Home->>Thumb: save(png) → thumbnails/{id}.png
  Sim-->>Ctrl: pureEvent {type:'ended', id}
  Sim->>Sim: 대기 모션(setIdle 값)으로 복귀
```

---

## 3.3 영상 입력으로 생성

```mermaid
sequenceDiagram
  autonumber
  actor U as 사용자
  participant Comp as Composer
  participant Vid as VideoInputService
  participant Pick as image_picker / 카메라
  participant FT as fc_native_video_thumbnail
  participant Home as HomeScreen
  participant Svc as GenerationService
  participant AI as OpenAIClient

  U->>Comp: + 버튼 → 영상 첨부
  Comp->>Vid: pickFromGallery() / recordVideo()
  Vid->>Pick: 영상 선택 (최대 30초)
  Pick-->>Vid: 파일 경로
  Vid->>Vid: 길이 읽기, 기본 구간 계산
  Vid-->>Comp: VideoAttachment
  Comp-->>U: 구간 선택 시트
  U->>Comp: 구간 확정 + (선택) 한 줄 설명
  Comp->>Home: send(text, video)
  Home->>Vid: extractFrames(video)
  loop 균등 간격 8개 시점
    Vid->>FT: 해당 ms 프레임 추출 (긴 변 512px, 품질 70)
    FT-->>Vid: 이미지 바이트
  end
  Vid-->>Home: data URL 8장
  Home->>Svc: generate(request{frames: 8, text})
  Svc->>AI: generate
  AI->>AI: user content = [텍스트 블록, image_url × 8]<br/>"프레임 사이의 변화로 속도와 크기를 읽어라"
  AI->>AI: POST (gpt-4o 비전 모델)
  AI-->>Svc: 레시피 JSON
  Note over Svc: 이후는 3.2와 동일<br/>(검증 → 시그니처 반영 → 재생 → 썸네일)
```

---

## 3.4 생성 실패 시 3단 폴백

```mermaid
sequenceDiagram
  autonumber
  participant Svc as GenerationService
  participant AI as OpenAIClient
  participant OL as OllamaClient
  participant Demo as DemoClient
  participant Eng as MotionEngine

  alt 강제 데모 모드 (사이드바 로봇 상태 5번 탭)
    Svc->>Demo: generate
  else 일반
    opt OpenAI 키가 있음 (isAvailable)
      Svc->>AI: generate
      AI--xSvc: 실패 (network / auth / quota / timeout / invalidResponse)
      Note over AI: 일시적 오류는 1s · 2s · 4s 간격으로 재시도 후 포기
    end
    opt OLLAMA_HOST 설정됨
      Svc->>OL: generate
      alt 영상 프레임이 있는 요청
        OL--xSvc: unsupported (텍스트 전용 모델)
      else 텍스트 요청
        OL-->>Svc: 레시피 JSON (qwen3:8b, 7–10초)
      end
    end
    opt 앞에서 결과를 못 얻음
      Svc->>Demo: generate
    end
  end
  Demo->>Eng: demoMatch(chipId, when, how, situation, 텍스트)
  Eng-->>Demo: 가장 가까운 데모 레시피
  Demo-->>Svc: GenerationResult{source: demo}
  Svc->>Eng: validateRecipe
  alt 검증 실패 (쓸 수 있는 단계 0개) 이고 source ≠ demo
    Svc->>Demo: 데모로 다시 생성
  end
  Note over Svc: 사용자가 새로 전송한 경우(cancelled)만 예외로 올리고<br/>그 외에는 절대 실패하지 않는다 → 화면에는 항상 움직임이 나온다
```

---

## 3.5 피드백 재생성과 라이브러리 저장

```mermaid
sequenceDiagram
  autonumber
  actor U as 사용자
  participant Home as HomeScreen
  participant Svc as GenerationService
  participant Save as SaveSheet
  participant Lib as LibraryProvider
  participant Repo as LocalRepository
  participant Robot as RobotProvider
  participant Ctrl as SimController

  Home-->>U: 질문 3 "Like this one?"
  U->>Home: "Softer" 선택
  Home->>Svc: soften(spec) — 재생성 없이 속도·진폭 ×0.85
  Home->>Ctrl: playRecipe

  U->>Home: 자유 피드백 "more gently, only the head"
  Home->>Svc: generate(request{previousSpec, feedback})
  Note over Svc: 직전 레시피 JSON + 수정 요청을 프롬프트에 넣어<br/>나머지는 유지하고 지적한 부분만 바꾸게 한다
  Svc-->>Home: 새 spec
  Home->>Ctrl: playRecipe

  U->>Home: Save
  Home->>Save: 저장 시트 (이름 · 반응 방식 · 상황)
  U->>Save: 이름, "Play without asking", 상황 "Someone comes home"
  Save->>Lib: save(spec, kind: auto, situation)
  alt 같은 상황에 이미 auto 모션이 있음
    Lib->>Repo: 기존 모션을 askFirst로 강등 (지우지 않음)
  end
  Lib->>Repo: upsertSavedMotion
  Repo->>Repo: JsonStore → pure_state.json (임시 파일 → rename)
  Lib-->>U: 저장 완료 토스트

  U->>Home: 라이브러리에서 모션 재생
  Home->>Ctrl: playRecipe(saved.spec.recipe)
  Note over Robot,Ctrl: 시그니처는 저장 시점의 값이 레시피에 이미 반영되어 있음<br/>(signatureSnapshot 보존)
```
