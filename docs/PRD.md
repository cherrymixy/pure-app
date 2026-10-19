# PURE App — 졸전 시뮬레이션 MVP PRD

> 로봇에게 말하거나 영상을 보여주면, **GPT가 그 상황에 맞는 움직임을 만들고 PURE Desk 시뮬레이터가 실시간으로 재생**하는 모바일 앱.
> 졸업전시 시연용(배포 X, 실제 로봇 연동 X). Flutter + 시뮬레이터 WebView 모듈. 아이폰 실기기에 설치해 시연.
> 태그라인: **"Motion, made uniquely yours."**

---

## 0. 작업 방식 (FITZY 하네스 그대로)

1. **로직 먼저 동결.** 상태(프로필/시그니처/채팅/모션/라이브러리)·데이터·생성 규칙을 UI와 분리해 먼저 동결. 콘텐츠(칩·질문 트리·반응 상황·더미 데이터·데모 레시피)는 `data/`로 외부화.
2. **시뮬레이터는 봉인 모듈.** zip(feat/pure-desk-robot)의 엔진을 `sim/`으로 떼어내 독립 웹 번들로 만들고, **JS API(부록 B) 하나로만** Flutter와 통신. 브리지가 붙은 뒤 `sim/` 내부는 안 건드린다.
3. **디자인은 두 층.** 토큰·셸은 초반, 화면별 비주얼·연출은 로직 동결 후 마지막 패스. 비주얼 SSOT는 **Figma MCP로 직접** 읽는다(Codex 분업 없음).
4. **빌드는 복붙 단계별 프롬프트.** 규칙은 `docs/conventions.md`에 정리. 한 번에 하나 → 확인 → 다음.
5. **시각 조정은 모호한 말 금지.** 값/Figma 노드로 정확히. 측정 스크립트 금지.
6. **실험은 동결 뒤에, 플래그 아래에.** 영상→키프레임 직접 생성(5장 Tier 2)은 레시피 경로가 초록이 된 다음, 기능 플래그로 켜고 끈다. 실패해도 시연 경로는 안 깨진다.
7. **UI 문구는 영어.** 모든 문구는 `data/strings.dart` 키로 관리(설계서 12장 문구 표 기준).

---

## 1. 개요

- **한 줄 정의:** 상황을 말하거나 영상을 보여주면 로봇이 그에 맞는 움직임을 만들어 시뮬레이터로 보여주고, 마음에 들면 반응 상황과 함께 라이브러리에 저장하는 앱.
- **핵심 루프:** 입력(칩/텍스트/음성/영상) → 생성(GPT) → 재생(실시간 시뮬레이터) → 피드백/저장 → 라이브러리.
- **시연 목표(해피패스):** 홈에서 "Someone came home" → 질문 3단계 → 로봇 카드에서 새 인사 모션 재생 → Save it → "When someone comes home" 자동 반응으로 저장 → 라이브러리에 남는다.

---

## 2. 범위

**포함**
- 00 스플래시 / M 사이드바(햄버거, 하단 탭바 없음)
- 06 홈: 인사말 + 상황 칩 5개 + 입력창(텍스트 / + 영상 첨부 / 마이크)
  - 06-2 영상 첨부(촬영·갤러리, 30초 구간 선택), 음성 입력(파형·실시간 자막)
  - 06-3 생성 중 → 06-4 로봇 답장(시뮬 카드 4:3, Play on Purebot / Save) → 06-5 피드백으로 재생성(버전 누적)
  - 06-6 재생 상태 바(Playing… / Stop) — 버튼 유지
  - 06-7 저장 시트(이름 자동 제안, 반응 상황, 대체 경고) → "Saved to Library" 토스트
  - 06-8 대화 기록 / 전체 화면 미리보기(드래그 회전, 반복)
  - 06-9 질문형 생성 3단계(언제 / 어떻게 / 확인) + 예시 원형 버튼 3개 + 음성 응답
- 05 모션 시그니처 4단계(성격 / 관계 방식 / 움직임 표현 / 미리보기) + 편집 모드(08-2에서 진입). 답을 고르면 **대기 모션이 바로 바뀜**
- 07 라이브러리: 목록(All / Auto / Manual, 자동 재생 그룹), 상세(미리보기·반응 상황·Play·Edit in chat·Rename·Delete), 검색
- 09 마이: 프로필(SeungA / seunga@purebot.app, Edit → 이름 수정), Notifications(토글 로컬 저장), Account, Help & FAQ, Terms & Privacy, Version 1.0.0 — **하위 화면 전부 UI 그대로 껍데기, 탭 반응 O**
- 08 로봇 / 10 알림: **UI 그대로 더미**(시드 데이터). 단 08-2 모션 시그니처 재설정은 실제 동작(05 편집 모드 연결)
- C 공통: 토스트, 바텀시트, 빈 화면, 삭제 확인
- **데모 모드:** 네트워크/GPT 실패 시 미리 만든 레시피로 대체 재생
- GPT 생성 **Tier 1 레시피 / Tier 2 키프레임 직접 생성(플래그)**

**제외**
- 01 앱 권한 안내 화면(OS 권한은 사용 시점에만 요청), 02 로그인, 03 회원가입, 04 로봇 연결, 펌웨어 실제 동작, 푸시, 세션/오프라인 공통 상태(C-1·C-7·C-8·C-9), 다크 테마, LeLamp 로봇, 실제 로봇 통신, 서버(계정·동기화)

---

## 3. 유저 플로우 (시연 해피패스, 영어 UI)

```
[Splash 2s] → [Home] "Hi SeungA, what's happening?"  chips: Someone came home / I'm so tired… / Thank you / That startled me! / What is this?
   │
   ├─ chip 탭 or 마이크 → [06-9 Question flow]
   │     Step 1/3 "When should Purebot do this?"  (Someone comes home / I say good night / A loud noise)  ← 예시 모션 카드 재생
   │     Step 2/3 "How should it react?"          (상황별 예시 3개)                                    ← 초안 재생 "Playing on Purebot…"
   │     Step 3/3 "Like this one?"                (Save it / Softer / Try again)
   │
   ├─ 텍스트 or 영상(+) 전송 → [06-2 Sent] → [06-3 typing dots] → [06-4 Robot reply: 시뮬 카드 4:3]
   │     입력창에 피드백("more gently, arms not legs") → 새 버전 답장 추가(이전 버전 유지)
   │
   ▼
[06-7 Save sheet] Name "Welcome home" · How should it play? (Play without asking: Someone comes home / I say I'm tired / Something startles me · Ask before playing · Only when I ask)
   ▼
"Saved to Library" toast → [M sidebar → Library] 자동 재생 그룹에 "Welcome home · When someone comes home"
```

모션 시그니처(05)는 사이드바 → Robot → Motion signature에서 진입(또는 첫 실행 플래그로 홈 전에 1회).

---

## 4. 화면 정의 (ID = 화면 설계서 기준)

공통: 좌상단 햄버거(사이드바 280ms, 딤 40%) / 상단 로봇 상태 "Purebot · PUREBOT / LIVELY, BOUNCY" / 우상단 알림 종.

| ID | 화면 | 핵심 동작 |
|---|---|---|
| 00 | Splash | 로고 0.6s 페이드인, 2s 뒤 홈 |
| M-1 | Sidebar | New motion / Home / Library / Robot / Activity history / Recent chats(See all) / Me · Settings |
| 06-1 | Home | 인사말(이름 반영), 칩 5개(탭 → 입력창 채움), 입력창(텍스트 / + / 마이크) |
| 06-2 | Composer | + → Record a video(30s) / Choose from library(videos only) → 30초 넘으면 Trim 시트 → 첨부 칩(X 취소). 마이크 → Listening… 파형 + 실시간 자막, 2초 무음 자동 종료, 입력창에 채움(자동 전송 X) |
| 06-3 | Generating | 로봇 말풍선 자리에 점 3개 바운스. 20초부터 지연 안내, 60초 실패(06-E1). 생성 중 새 전송 시 이전 취소 |
| 06-4 | Robot reply | 시뮬 카드(채팅 폭 4:3) 자동 재생·반복, 도착 시 중앙으로 스크롤. Play on Purebot / Save. 탭 → 전체 화면 |
| 06-5 | Feedback | 가장 최근 답장을 기준으로 재생성, 새 답장 버전 추가. 각 버전에서 Play/Save 가능 |
| 06-6 | Playing bar | Play on Purebot 탭 → 입력창 위 "Purebot is moving 0:03" + Stop, 카드 재생. 끝나면 자동 사라짐 |
| 06-7 | Save sheet | 이름 자동 제안(1~20자), 반응 상황 1개, 같은 상황에 기존 모션 있으면 노란 경고 + "Replace and save" |
| 06-8 | Chat history | Today / Earlier, 답장 수·시간·저장 수, 현재 대화 테두리, 스와이프 삭제 |
| 06-9 | Question flow | Step n/3, 예시 카드(1단계 예시 모션, 2단계부터 초안) + Play again, 원형 버튼 3개(2줄), 질문, 마이크. 뒤로 가기 = 이전 질문 |
| 06-FS | Full-screen preview | 드래그 회전, 반복 토글(기본 켜짐), 재생 바, X/아래 스와이프 닫기 |
| 05-1~4 | Motion signature | 성격 → 관계 방식 → 움직임 표현(A/B 번갈아 재생, 상태 칩) → 미리보기(Looks good / A bit softer / Start over). Skip 시 기본값. 편집 모드: 진행 바·Skip 숨김, 현재 답 강조, 고르면 바로 저장 |
| 07-1 | Library | 검색 / All·Auto·Manual / Plays automatically 그룹(블루+번개) / 카드(썸네일·이름·상황) / 카드 우측 재생 / 빈 화면 |
| 07-2 | Motion detail | 미리보기(시뮬), Saved {date} · Edited n times, Plays automatically when …, Play on Purebot / Edit in chat, 더보기(Rename / Delete) |
| 07-3 | Search | 즉시 포커스, 이름·상황 검색, 일치 글자 블루, 결과 없음 → Make it on Home |
| 08-1 | Robot (더미) | Purebot Arm · Connected · Home_5G · Plugged in / 성격 모드(Family·Partner·Focus) / Motion signature(실제 값) / Activity history / My robots / Firmware 1.3.0 ready |
| 08-2 | Signature reset | 항목 탭 → 05 편집 모드. Preview on Purebot / Reset to default(확인 시트) |
| 08-3~5 | 로봇 목록 / 펌웨어 / 행동 기록 | UI 그대로 더미(시드) |
| 09-1 | Me | SeungA / seunga@purebot.app / Edit / Notifications / Account / Help & FAQ / Terms & Privacy / Version 1.0.0 |
| 09-1a | Your name | 1~20자, 같거나 비면 Save 비활성, "Saved" 토스트, 홈 인사말 즉시 반영 |
| 09-2~4 | Notifications / Account / Help | UI 그대로. 토글은 로컬 저장, Log out·Delete는 확인 시트만(닫기) |
| 10-1 | Notifications | 시드 목록 + "You're all caught up" 빈 화면 |

---

## 5. 콘텐츠 (`data/`로 외부화)

- **상황 칩(홈):** Someone came home · I'm so tired… · Thank you · That startled me! · What is this?
- **질문 트리(06-9):** 칩/상황별 Step1·Step2 예시 3개씩(예: Step1 Someone comes home / I say good night / A loud noise, Step2 Act casual / Turn away / Cover the shelf). 자유 입력은 GPT가 예시 3개 생성(🟡)
- **반응 상황:** `comesHome` "Someone comes home" · `tired` "I say I'm tired" · `startled` "Something startles me" · `onlyWhenAsked` "Only when I ask"
- **시그니처 선택지:** Personality(Calm & gentle / Lively / Bold & curious) · Relationship(Comes to me first / Waits till I'm near / Only when needed) · Motion(A Quick & bouncy / B Slow & smooth / In between)
- **시뮬 동작 15종(zip):** idle, doze, sleep, wake, nod, shake, look_around, curious, happy, sad, alert, greet, sweep, focus, home
- **얼굴 7종(zip mp4):** neutral, smile, heart, sad, sleepy, surprise, tilt
- **시드:** 프로필(SeungA / seunga@purebot.app), 로봇(Purebot / Purebot Arm / Lively · Responds when near · Quick & bouncy), 라이브러리 샘플 3개(🟡), 알림·행동 기록·로봇 탭 더미
- **데모 레시피:** 칩 5개 × 질문 트리 리프마다 레시피 1개 + "Softer" 변형

---

## 6. 생성 규칙 (*동결 대상*)

1. **입력:** 텍스트 / 영상(최대 30초, 8프레임 추출) / 둘 다. 음성은 기기 내 인식 후 텍스트로.
2. **시그니처 스냅샷:** 생성 요청마다 현재 로봇의 시그니처를 함께 보내고, 결과 `MotionSpec`에 저장(나중에 시그니처를 바꿔도 저장된 모션은 그대로).
3. **Tier 1 — 레시피 모드(기본):** GPT는 동작 15종을 조합한 `Recipe {steps[≤6]{behavior, speed 0.5~1.6, amplitude 0.4~1.5, repeat 1~4, face}, name, reasoning}`만 낸다. 앱이 검증(허용 목록·범위 클램프)하고 시뮬에서 재생.
4. **Tier 2 — 클립 모드(플래그 `directClip`):** 영상 입력일 때 GPT가 5관절 키프레임 `Clip`을 직접 낸다. 앱이 관절 범위(`robot.xml`)·최대 각속도·길이(1~8s)·키프레임 수(≤24)로 검증·클램프. 검증 실패 시 Tier 1로 자동 폴백. **같은 요청의 Tier 1 결과를 항상 같이 받아 둔다.**
5. **피드백 재생성:** 직전 `MotionSpec` + 피드백 문장을 보내 새 버전 생성. 이전 버전은 유지.
6. **타임아웃:** 20초 지연 안내, 60초 실패(06-E1 "Couldn't make this motion"). 네트워크 오류 1·2·4초 자동 재시도.
7. **데모 모드:** 오프라인·실패·강제 토글(로봇 이름 5번 탭) 시 입력을 칩/상황 키워드로 매칭해 가장 가까운 데모 레시피 재생. 생성 중 연출 1.5초 유지. 피드백 "softer/slower/gently" → Softer 변형, 그 외 → 같은 레시피.
8. **저장:** 같은 반응 상황에 기존 모션이 있으면 기존 모션은 `askFirst`로 바꾸고 새 모션이 `auto`. Edit in chat 후 다시 저장하면 같은 모션을 새 버전으로 덮어씀(editCount+1).
9. **시그니처 → 재생 파라미터(초안, STEP 6에서 튜닝):** speed = lerp(0.7, 1.4, lively) × {A 1.2 / B 0.8 / between 1.0}, amplitude = lerp(0.6, 1.3, bold) × lerp(0.85, 1.15, richness), idle = calm→doze·idle / lively→look_around / bold→curious, relationship = comesFirst→인사 앞에 앞으로 기울기 / waitsNear→greet / onlyNeeded→작은 nod.
10. **테스트:** 생성 서비스는 `GenerationClient` 인터페이스 뒤에 두고 목(mock)으로 전체 루프 테스트. 시계(`now`) 주입.

---

## 7. 데이터 모델 (Dart, 순수 데이터)

```dart
class UserProfile { String name; final String email; }                       // 시드: SeungA / seunga@purebot.app

enum Relationship { comesFirst, waitsNear, onlyNeeded }
enum Expression { quickBouncy, slowSmooth, inBetween }
class MotionSignature { int lively; int bold; Relationship relationship; Expression expression; int richness; String sound; } // 0~100, 기본 Lively/waitsNear/quickBouncy

class Robot { final String id; String name; final String model; MotionSignature signature; }  // 시드: Purebot / Purebot Arm

class RecipeStep { String behavior; double speed; double amplitude; int repeat; String? face; }
class Recipe { List<RecipeStep> steps; bool loop; }
class Clip { String format; double duration; Map<String, List<Key>> tracks; }                 // lelamp.clip/1, pure-desk 채널

enum SpecMode { recipe, clip }
class MotionSpec { final String id; String name; String face; SpecMode mode; Recipe recipe; Clip? clip; String reasoning; MotionSignature signatureSnapshot; int version; String? thumbnailPath; }

enum Sender { user, robot }
enum MessageStatus { sent, generating, done, failed }
class VideoAttachment { String path; String thumbPath; double durationSec; double trimStart; double trimEnd; }
class Message { final String id; Sender sender; String? text; VideoAttachment? video; MessageStatus status; MotionSpec? spec; DateTime createdAt; }
class Chat { final String id; List<Message> messages; DateTime createdAt; DateTime lastActiveAt; }

enum ReactionKind { auto, askFirst, manual }
enum Situation { comesHome, tired, startled, onlyWhenAsked }
class SavedMotion { final String id; String name; MotionSpec spec; ReactionKind kind; Situation? situation; DateTime savedAt; int editCount; String chatId; }

class QuestionSession { String chatId; int step; List<String> answers; MotionSpec? draft; }   // 06-9 진행 상태

class NotificationItem { ... }  class ActivityItem { ... }                                   // 더미 시드
```

- 저장: 로컬만(JSON 파일 or shared_preferences). 영상은 **원본 경로 + 썸네일 + 구간**만. 라이브러리 썸네일은 시뮬 `capture()` PNG.
- 모든 접근은 `repositories/data_repository.dart` 인터페이스 → `LocalRepository` 구현(나중에 서버로 교체 가능).

---

## 8. 시뮬레이터 모듈 (`sim/`)

- zip에서 가져오는 것: `lib/lelamp/{motion,clip,behaviors,robots,state-motion}.ts`, `components/lelamp/{viewer3d,mujoco,lamp}.ts` 중 런타임(React UI·타임라인 에디터 제외), `public/mujoco/`(wasm 10MB), `public/pure-desk/model/`, `public/pure-desk/faces/`.
- 빼는 것: LeLamp 모델·에셋, Studio/Lab UI, Next.js.
- 빌드: Vite + TS → 단일 `index.html` + 에셋. Flutter `assets/sim/`에 넣고 `flutter_inappwebview`의 로컬 서버(`http://localhost:8080`)로 서빙.
- 계약: **부록 B의 `window.pure` API만** 외부에 노출. 이벤트는 `flutter_inappwebview.callHandler('pureEvent', …)`.
- 시그니처는 `setIdle(params)` / `playRecipe(recipe, params)`의 speed·amplitude로 반영(재생 속도 배율, HOME 기준 키프레임 진폭 배율).

---

## 9. 입력 처리

- **영상:** `image_picker`(videos only, 촬영·갤러리). 30초 초과 시 Trim 시트에서 구간 선택 — 파일은 자르지 않고 **구간 값만** 저장. 프레임 추출은 구간 안에서 8장(≤512px JPEG) → base64로 GPT 비전 입력.
- **음성:** `speech_to_text`(iOS 기기 내 인식, 영어). 2초 무음 자동 종료. 홈 입력창은 채우기만, 06-9에서는 바로 답으로 전송.
- **권한 문구(iOS Info.plist, 설계서 3장):** NSCameraUsageDescription "PURE uses the camera to record a video that shows your robot how to move." / NSPhotoLibraryUsageDescription "PURE uses your photos to pick a video that shows your robot how to move." / NSMicrophoneUsageDescription "PURE uses the microphone so you can tell your robot what's happening." / NSSpeechRecognitionUsageDescription "PURE turns what you say into text for your robot."
- 거부 시: 01-E1 형식 시트(Open Settings / Not now).

---

## 10. GPT 연결

- 서버 없음. 앱에서 OpenAI API 직접 호출. 키는 `--dart-define=OPENAI_API_KEY=…`로 빌드 시 주입(코드·git에 넣지 않음).
- 모델: 기본 `gpt-4o-mini`, 영상 입력은 `OPENAI_VISION_MODEL`(기본 `gpt-4o`)로 분리 가능.
- 구조화 출력(`response_format: json_schema, strict`). 프롬프트는 zip `app/api/analyze/route.ts`의 시스템 프롬프트 골격(제품 고정, 상태 추론, 프레임 시퀀스 읽기)을 계승하되 출력은 레시피/클립 스키마.

---

## 11. 디자인 방향

- Figma **Design System 페이지(70:1520)**: F/Color(Primitives + Semantic Light), F/Typography, F/Spacing & Radius, F/Effect, F/Icon → `theme/` 토큰. 컴포넌트 C/Actions(Button·Icon Button·Mic Button), C/Selection & Status(Chip·Status Pill·Count Badge·Toggle·Check Item·Progress Bar), C/Input(Text Field·Composer), C/Navigation(Top Bar·Sidebar·Menu Item·Avatar), C/List(Section Label·List Row·List Group·Mode Row·History Item), C/Feedback(Bottom Sheet·Toast·Banner·Empty State), C/Motion & Chat(Robot Card·Question Block·Answer Set·Chat Bubble) → `widgets/`.
- 화면 SSOT: **[앱] UI 페이지(449:9318) Light 섹션**. 다크 제외.
- 홈 배경의 블루 라디얼 글로우, 흰 라운드 카드, 원형 답안 버튼 3개, 블루 원형 마이크.

---

## 12. 빌드 워크플로우

1. 승아: 결정 회신 → 플레이북 STEP 순서대로 복붙.
2. 개발: 로직 패스(STEP 1~11) → v0.1-logic 동결 → 실험(STEP 12, 플래그) → 디자인 패스(STEP 20~25, Figma MCP 직접) → 마감.
3. 시뮬레이터(`sim/`)는 STEP 2~3에서만 수정. 이후엔 부록 B API 바깥을 건드리지 않는다.

---

## 13. 마일스톤

```
로직: 1 Flutter 스캐폴드 → 2 sim/ 모듈 추출 → 3 브리지 → 4 모델·콘텐츠 → 5 저장·상태(Repository)
     → 6 시그니처·모션 엔진(Dart) → 7 GPT 생성 서비스(레시피) + 데모 모드 → 8 영상 입력 → 9 음성 입력
     → 10 회색박스 화면(6슬라이스) → 11 통합테스트(동결 v0.1-logic)
실험: 12 영상→키프레임 직접 생성(플래그 directClip)
디자인(Figma MCP→Flutter): 20 토큰 → 21 폰트·아이콘·에셋 → 22 화면별 번역 → 23 폴리시 → 24 연출 → 25 마감·실기기(v0.2)
```

---

## 부록 D — 열린 결정

| 항목 | 값 | 상태 |
|---|---|---|
| 스택 | Flutter + `sim/` WebView(flutter_inappwebview, 로컬 서버) | ✅ |
| 기기 | iPhone 실기기, Mac + Xcode 있음. 무료 서명은 7일 만료 → 전시 전날 재설치(또는 유료 계정) | ✅ |
| 로봇 | PURE Desk만, LeLamp 제외 | ✅ |
| 로그인/가입/연결 | 제외. 프로필·로봇은 시드 | ✅ |
| 생성 흐름 | 채팅(06-2~06-5) + 질문형(06-9) 둘 다 | ✅ |
| 채팅 ↔ 질문형 관계 | 하나의 Chat 모델 위에 두 UI 모드. 칩·음성 → 질문형, 텍스트·영상 전송 → 채팅. 질문형의 답은 채팅 메시지로도 기록 | 🟡 추천 |
| GPT 출력 | Tier 1 레시피(기본) + Tier 2 키프레임(플래그, 영상 입력) | ✅ |
| 데모 모드 | 오프라인/실패/강제 토글 시 데모 레시피 | ✅ |
| 음성 인식 | 기기 내(speech_to_text), 영어 | ✅ |
| Play on Purebot | 버튼 유지. 탭 → 06-6 재생 상태 바 + 카드 재생(실제 로봇 없음) | ✅ |
| 테마 | Light만 | ✅ |
| 08 로봇 / 10 알림 | UI 그대로 더미(08-2만 실제) | ✅ |
| 09 마이 하위 | UI 그대로 껍데기, 탭 반응 O | ✅ |
| 자유 입력 시 06-9 예시 답안 | 칩은 고정 트리, 자유 텍스트는 GPT가 예시 3개 생성(실패 시 기본 트리) | 🟡 추천 |
| 대체 시 기존 모션 | `askFirst`("Ask before playing")로 전환 | 🟡 추천 |
| 라이브러리 시드 | 샘플 3개 미리 저장(전시용) + 숨은 "Reset demo data" | 🟡 추천 |
| 05 첫 실행 진입 | 첫 실행에 05 1회 → 홈. 이후 08-2에서 편집 | 🟡 추천 |
| 폰트 | Figma F/Typography에서 확인 후 STEP 21에 기입 | 🟡 |

---

## 한 줄 요약
**말·영상 → GPT가 레시피(또는 키프레임) → PURE Desk 시뮬레이터가 실시간 재생 → 저장·라이브러리. 로직 먼저 동결, 시뮬은 봉인 모듈, 비주얼은 Figma MCP로 직접 번역, 와이파이가 죽어도 데모 레시피로 시연은 돈다.**
