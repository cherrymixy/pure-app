/// 시뮬레이터가 아는 이름들 — **유일한 허용 목록**.
///
/// `sim/src/engine/behaviors.ts` 의 BEHAVIORS 와 `public/pure-desk/faces/faces.json`
/// 에서 그대로 옮겼다. STEP 3 자체 검사가 ready 이벤트로 받은 목록과 이 상수를
/// 대조하므로, 한쪽만 바뀌면 바로 드러난다.
///
/// GPT 출력은 반드시 이 목록을 통과해야 한다 (CLAUDE.md 규칙 10).
library;

/// 동작 15종.
const List<String> kBehaviors = [
  'idle',
  'doze',
  'sleep',
  'wake',
  'nod',
  'shake',
  'look_around',
  'curious',
  'happy',
  'sad',
  'alert',
  'greet',
  'sweep',
  'focus',
  'home',
];

/// 끝나지 않고 계속 도는 동작. 레시피의 repeat 은 완료 횟수가 아니라 시간으로
/// 환산된다 — sim 쪽 runtime.ts 가 처리하지만, 설명 문구나 길이 추정에 필요하다.
const Set<String> kLoopingBehaviors = {
  'idle',
  'doze',
  'sleep',
  'sad',
  'sweep',
  'focus',
};

/// 표정 7종.
const List<String> kFaces = [
  'neutral',
  'smile',
  'heart',
  'sad',
  'sleepy',
  'surprise',
  'tilt',
];

/// 동작 → 기본 표정. faces.json 의 매핑과 같다.
const Map<String, String> kDefaultFaceForBehavior = {
  'idle': 'neutral',
  'look_around': 'neutral',
  'sweep': 'neutral',
  'focus': 'neutral',
  'home': 'neutral',
  'wake': 'neutral',
  'shake': 'neutral',
  'curious': 'tilt',
  'alert': 'surprise',
  'sad': 'sad',
  'nod': 'smile',
  'greet': 'smile',
  'doze': 'sleepy',
  'sleep': 'sleepy',
  'happy': 'heart',
};

/// 동작 설명 — GPT 프롬프트에 그대로 들어간다.
///
/// `sim/src/engine/behaviors.ts` 의 한국어 description 을 영어로 옮긴 것. GPT 가
/// 동작을 고르는 유일한 단서이므로 **무엇이 다른지**가 드러나게 쓴다.
const Map<String, String> kBehaviorDescriptions = {
  'idle': 'at rest, breathing quietly',
  'doze': 'slowly drooping, half asleep',
  'sleep': 'fully settled down, asleep',
  'wake': 'stretches up and comes back to attention',
  'nod': 'a single agreeing nod',
  'shake': 'shakes the head side to side, saying no',
  'look_around': 'scans left and right, taking the room in',
  'curious': 'tilts the head to study something',
  'happy': 'bounces with delight',
  'sad': 'slumps down, low and slow',
  'alert': 'snaps upright, startled',
  'greet': 'leans forward and waves with the whole body',
  'sweep': 'sweeps slowly across the desk',
  'focus': 'leans in close and holds still',
  'home': 'returns to the neutral resting pose',
};

/// 표정 설명 — 프롬프트용.
const Map<String, String> kFaceDescriptions = {
  'neutral': 'plain eyes, no particular feeling',
  'smile': 'friendly, pleased',
  'heart': 'delighted, affectionate',
  'sad': 'downcast',
  'sleepy': 'drowsy, half-closed',
  'surprise': 'wide-eyed, startled',
  'tilt': 'quizzical, curious',
};

/// 클립 이징 7종 (sim 의 EASINGS 키).
const List<String> kEasings = [
  'linear',
  'ease_in_out',
  'ease_in',
  'ease_out',
  'ease_out_back',
  'ease_out_elastic',
  'ease_out_bounce',
];

/// 클립에서 쓰는 관절 이름 — **계약 이름**. sim 내부 채널명이 아니다.
const List<String> kJoints = [
  'base_yaw',
  'shoulder_pitch',
  'elbow_pitch',
  'head_pan',
  'head_tilt',
];

bool isKnownBehavior(String name) => kBehaviors.contains(name);
bool isKnownFace(String name) => kFaces.contains(name);
bool isKnownEasing(String name) => kEasings.contains(name);
bool isKnownJoint(String name) => kJoints.contains(name);

/// 동작의 기본 표정. 모르는 동작이면 neutral.
String defaultFaceFor(String behavior) => kDefaultFaceForBehavior[behavior] ?? 'neutral';
