/// 데모 레시피 — 네트워크·키 없이도 시연이 도는 길.
///
/// 오프라인·생성 실패·강제 토글일 때 입력을 키워드로 매칭해 가장 가까운 걸 재생한다
/// (매칭 로직은 STEP 6 의 motion_engine.demoMatch). 전시장 와이파이가 죽어도
/// 시연 경로는 살아 있어야 한다 (CLAUDE.md 규칙 11).
///
/// 동작·표정 이름은 전부 data/behaviors.dart 허용 목록 안이다.
library;

import '../models/recipe.dart';

/// 데모 레시피 하나.
class DemoRecipe {
  const DemoRecipe({
    required this.id,
    required this.name,
    required this.face,
    required this.reasoning,
    required this.keywords,
    required this.recipe,
    this.chipId,
    this.whenOptionId,
    this.howOptionId,
  });

  final String id;

  /// 저장 시트의 이름 제안으로 쓰인다.
  final String name;

  /// 기본 표정.
  final String face;

  /// 로봇 답장에 함께 보이는 설명. UI 가 영어라 영어로.
  final String reasoning;

  /// 매칭 점수를 매길 키워드. 소문자로 적는다.
  final List<String> keywords;

  final Recipe recipe;

  /// 어느 칩에서 왔는지 (칩 경로 매칭에 가산점).
  final String? chipId;

  /// 질문 트리 리프 — 1단계·2단계 답 조합.
  final String? whenOptionId;
  final String? howOptionId;

  bool get isLeaf => whenOptionId != null && howOptionId != null;
}

/// 칩 5개의 기본 레시피 — 질문형을 거치지 않고 바로 보낼 때.
const List<DemoRecipe> _chipRecipes = [
  DemoRecipe(
    id: 'demo.cameHome',
    chipId: 'cameHome',
    name: 'Welcome home',
    face: 'smile',
    reasoning: 'Someone arriving is good news, so Purebot looks up and greets them warmly.',
    keywords: ['home', 'came home', 'back', 'arrive', 'door', 'welcome', 'hello', 'hi'],
    recipe: Recipe(steps: [
      RecipeStep(behavior: 'wake', speed: 1.1),
      RecipeStep(behavior: 'greet', speed: 1.15, amplitude: 1.1, repeat: 2, face: 'smile'),
      RecipeStep(behavior: 'happy', speed: 1.1, face: 'heart'),
    ]),
  ),
  DemoRecipe(
    id: 'demo.tired',
    chipId: 'tired',
    name: 'Gentle cheer-up',
    face: 'sad',
    reasoning: 'You sound worn out, so Purebot slows down and settles close instead of bouncing.',
    keywords: ['tired', 'exhausted', 'sleepy', 'worn', 'long day', 'rest', 'good night'],
    recipe: Recipe(steps: [
      RecipeStep(behavior: 'sad', speed: 0.8, amplitude: 0.9, face: 'sad'),
      RecipeStep(behavior: 'nod', speed: 0.75, amplitude: 0.7, face: 'sleepy'),
      RecipeStep(behavior: 'doze', speed: 0.8, amplitude: 0.85),
    ]),
  ),
  DemoRecipe(
    id: 'demo.thankYou',
    chipId: 'thankYou',
    name: 'Pleased wiggle',
    face: 'heart',
    reasoning: 'Being thanked is a small delight — a quick bounce, then a shy look away.',
    keywords: ['thank', 'thanks', 'good job', 'well done', 'proud', 'nice'],
    recipe: Recipe(steps: [
      RecipeStep(behavior: 'happy', speed: 1.2, amplitude: 1.1, repeat: 2, face: 'heart'),
      RecipeStep(behavior: 'nod', speed: 1.0, amplitude: 0.8, face: 'smile'),
    ]),
  ),
  DemoRecipe(
    id: 'demo.startled',
    chipId: 'startled',
    name: 'Startled hop',
    face: 'surprise',
    reasoning: 'A sudden noise snaps Purebot upright, then it checks where the sound came from.',
    keywords: ['startle', 'scared', 'loud', 'noise', 'bang', 'sudden', 'surprise', 'fell'],
    recipe: Recipe(steps: [
      RecipeStep(behavior: 'alert', speed: 1.4, amplitude: 1.2, face: 'surprise'),
      RecipeStep(behavior: 'shake', speed: 1.2, amplitude: 0.9),
      RecipeStep(behavior: 'look_around', speed: 1.0),
    ]),
  ),
  DemoRecipe(
    id: 'demo.whatIsThis',
    chipId: 'whatIsThis',
    name: 'Curious lean',
    face: 'tilt',
    reasoning: 'Something new on the desk — Purebot tilts in to read it before deciding.',
    keywords: ['what', 'this', 'new', 'curious', 'look at', 'show', 'see'],
    recipe: Recipe(steps: [
      RecipeStep(behavior: 'curious', speed: 1.0, amplitude: 1.1, face: 'tilt'),
      RecipeStep(behavior: 'focus', speed: 0.9, amplitude: 1.0),
      RecipeStep(behavior: 'nod', speed: 0.95, amplitude: 0.8, face: 'neutral'),
    ]),
  ),
];

/// 질문 트리 리프별 레시피. 1단계·2단계 답 조합마다 하나.
///
/// 조합이 15×3 = 45 개라 전부 적지 않고, **2단계 답(how)** 을 기준으로 둔다 —
/// 같은 "어떻게"면 상황이 달라도 움직임의 결은 같기 때문이다. 매칭은
/// howOptionId 우선, 없으면 칩 레시피로 떨어진다.
const List<DemoRecipe> _leafRecipes = [
  // cameHome
  DemoRecipe(
    id: 'demo.leaf.wave',
    howOptionId: 'wave',
    whenOptionId: 'someoneComesHome',
    name: 'Big hello',
    face: 'smile',
    reasoning: 'A full-body wave — leans forward, swings wide, and holds the greeting.',
    keywords: ['wave', 'hello', 'big', 'greeting'],
    recipe: Recipe(steps: [
      RecipeStep(behavior: 'greet', speed: 1.2, amplitude: 1.3, repeat: 2, face: 'smile'),
      RecipeStep(behavior: 'happy', speed: 1.15, amplitude: 1.1, face: 'heart'),
    ]),
  ),
  DemoRecipe(
    id: 'demo.leaf.perkUp',
    howOptionId: 'perkUp',
    whenOptionId: 'someoneComesHome',
    name: 'Perks up',
    face: 'neutral',
    reasoning: 'Lifts its head toward you, holds the look, then settles back down.',
    keywords: ['perk', 'look up', 'notice', 'turn toward'],
    recipe: Recipe(steps: [
      RecipeStep(behavior: 'wake', speed: 1.2),
      RecipeStep(behavior: 'look_around', speed: 1.0, amplitude: 0.9),
      RecipeStep(behavior: 'nod', speed: 1.0, amplitude: 0.9, face: 'smile'),
    ]),
  ),
  DemoRecipe(
    id: 'demo.leaf.shyNod',
    howOptionId: 'shyNod',
    whenOptionId: 'someoneComesHome',
    name: 'Shy nod',
    face: 'smile',
    reasoning: 'Barely moves — one small nod, then looks down.',
    keywords: ['shy', 'small', 'quiet', 'subtle', 'nod'],
    recipe: Recipe(steps: [
      RecipeStep(behavior: 'nod', speed: 0.9, amplitude: 0.6, face: 'smile'),
      RecipeStep(behavior: 'doze', speed: 0.9, amplitude: 0.7),
    ]),
  ),
  // tired
  DemoRecipe(
    id: 'demo.leaf.leanIn',
    howOptionId: 'leanIn',
    whenOptionId: 'iSayImTired',
    name: 'Leans in',
    face: 'sad',
    reasoning: 'Comes close slowly and stays — a quiet check-in rather than a question.',
    keywords: ['lean', 'comfort', 'close', 'check in'],
    recipe: Recipe(steps: [
      RecipeStep(behavior: 'focus', speed: 0.75, amplitude: 1.0, face: 'sad'),
      RecipeStep(behavior: 'nod', speed: 0.7, amplitude: 0.7),
    ]),
  ),
  DemoRecipe(
    id: 'demo.leaf.restWithMe',
    howOptionId: 'restWithMe',
    whenOptionId: 'iSayGoodNight',
    name: 'Rests with me',
    face: 'sleepy',
    reasoning: 'Droops softly and breathes along — keeps you company without asking anything.',
    keywords: ['rest', 'with me', 'company', 'sleep', 'night'],
    recipe: Recipe(steps: [
      RecipeStep(behavior: 'doze', speed: 0.8, amplitude: 0.9, face: 'sleepy'),
      RecipeStep(behavior: 'sleep', speed: 0.75, amplitude: 0.85),
    ]),
  ),
  DemoRecipe(
    id: 'demo.leaf.nudgeToBed',
    howOptionId: 'nudgeToBed',
    whenOptionId: 'lateAtDesk',
    name: 'Nudges me to rest',
    face: 'sleepy',
    reasoning: 'A small insistent nod toward the side, then a sleepy settle.',
    keywords: ['nudge', 'bed', 'go rest', 'late'],
    recipe: Recipe(steps: [
      RecipeStep(behavior: 'nod', speed: 1.0, amplitude: 0.9, repeat: 2, face: 'sleepy'),
      RecipeStep(behavior: 'doze', speed: 0.8, amplitude: 0.9),
    ]),
  ),
  // thankYou
  DemoRecipe(
    id: 'demo.leaf.bashful',
    howOptionId: 'bashful',
    whenOptionId: 'iSayThanks',
    name: 'Gets bashful',
    face: 'heart',
    reasoning: 'Turns away a little, then peeks back — pleased but shy about it.',
    keywords: ['bashful', 'shy', 'blush', 'turn away'],
    recipe: Recipe(steps: [
      RecipeStep(behavior: 'happy', speed: 1.1, amplitude: 0.9, face: 'heart'),
      RecipeStep(behavior: 'shake', speed: 0.9, amplitude: 0.6),
      RecipeStep(behavior: 'curious', speed: 1.0, amplitude: 0.8, face: 'tilt'),
    ]),
  ),
  DemoRecipe(
    id: 'demo.leaf.cheer',
    howOptionId: 'cheer',
    whenOptionId: 'weFinish',
    name: 'Cheers',
    face: 'heart',
    reasoning: 'Head up, big bounce, twice — celebrating with you.',
    keywords: ['cheer', 'celebrate', 'yay', 'loud', 'excited'],
    recipe: Recipe(steps: [
      RecipeStep(behavior: 'happy', speed: 1.3, amplitude: 1.3, repeat: 2, face: 'heart'),
      RecipeStep(behavior: 'greet', speed: 1.2, amplitude: 1.1),
    ]),
  ),
  DemoRecipe(
    id: 'demo.leaf.quietNod',
    howOptionId: 'quietNod',
    whenOptionId: 'iPraiseIt',
    name: 'Quiet nod',
    face: 'smile',
    reasoning: 'One small nod and straight back to resting — understated.',
    keywords: ['quiet', 'small nod', 'understated', 'simple'],
    recipe: Recipe(steps: [
      RecipeStep(behavior: 'nod', speed: 0.95, amplitude: 0.7, face: 'smile'),
      RecipeStep(behavior: 'idle', speed: 0.9),
    ]),
  ),
  // startled
  DemoRecipe(
    id: 'demo.leaf.jumpBack',
    howOptionId: 'jumpBack',
    whenOptionId: 'loudNoise',
    name: 'Jumps back',
    face: 'surprise',
    reasoning: 'Snaps away fast, then creeps back to see what made the noise.',
    keywords: ['jump', 'back', 'flinch', 'away', 'startled'],
    recipe: Recipe(steps: [
      RecipeStep(behavior: 'alert', speed: 1.5, amplitude: 1.3, face: 'surprise'),
      RecipeStep(behavior: 'curious', speed: 0.85, amplitude: 0.9, face: 'tilt'),
    ]),
  ),
  DemoRecipe(
    id: 'demo.leaf.freeze',
    howOptionId: 'freeze',
    whenOptionId: 'somethingFalls',
    name: 'Freezes',
    face: 'surprise',
    reasoning: 'Stops dead, holds still, then slowly lets go of the tension.',
    keywords: ['freeze', 'still', 'hold', 'stop'],
    recipe: Recipe(steps: [
      RecipeStep(behavior: 'alert', speed: 1.4, amplitude: 1.1, face: 'surprise'),
      RecipeStep(behavior: 'focus', speed: 0.7, amplitude: 0.8),
      RecipeStep(behavior: 'idle', speed: 0.85, face: 'neutral'),
    ]),
  ),
  DemoRecipe(
    id: 'demo.leaf.checkOnMe',
    howOptionId: 'checkOnMe',
    whenOptionId: 'suddenMove',
    name: 'Checks on me',
    face: 'surprise',
    reasoning: 'Looks at you first, then at the noise — you come before the thing.',
    keywords: ['check', 'on me', 'turn to me', 'protect'],
    recipe: Recipe(steps: [
      RecipeStep(behavior: 'alert', speed: 1.3, amplitude: 1.0, face: 'surprise'),
      RecipeStep(behavior: 'greet', speed: 1.1, amplitude: 0.9, face: 'neutral'),
      RecipeStep(behavior: 'look_around', speed: 1.0),
    ]),
  ),
  // whatIsThis
  DemoRecipe(
    id: 'demo.leaf.tiltAndStudy',
    howOptionId: 'tiltAndStudy',
    whenOptionId: 'iShowSomething',
    name: 'Tilts and studies',
    face: 'tilt',
    reasoning: 'Tilts one way, holds, then the other — reading it slowly.',
    keywords: ['tilt', 'study', 'read', 'examine'],
    recipe: Recipe(steps: [
      RecipeStep(behavior: 'curious', speed: 0.95, amplitude: 1.2, repeat: 2, face: 'tilt'),
      RecipeStep(behavior: 'focus', speed: 0.9),
    ]),
  ),
  DemoRecipe(
    id: 'demo.leaf.circleAround',
    howOptionId: 'circleAround',
    whenOptionId: 'newThingOnDesk',
    name: 'Looks it over',
    face: 'neutral',
    reasoning: 'Sweeps across it left and right, then settles facing it.',
    keywords: ['look over', 'sweep', 'scan', 'around'],
    recipe: Recipe(steps: [
      RecipeStep(behavior: 'sweep', speed: 1.0, amplitude: 1.1),
      RecipeStep(behavior: 'focus', speed: 0.9, face: 'neutral'),
    ]),
  ),
  DemoRecipe(
    id: 'demo.leaf.carefulPoke',
    howOptionId: 'carefulPoke',
    whenOptionId: 'iAskAbout',
    name: 'Approaches carefully',
    face: 'tilt',
    reasoning: 'Creeps forward in small steps, pausing between each.',
    keywords: ['careful', 'slow', 'approach', 'creep', 'cautious'],
    recipe: Recipe(steps: [
      RecipeStep(behavior: 'curious', speed: 0.8, amplitude: 0.8, face: 'tilt'),
      RecipeStep(behavior: 'focus', speed: 0.75, amplitude: 0.9, repeat: 2),
    ]),
  ),
];

/// 전부 — 칩 기본 + 질문 트리 리프.
const List<DemoRecipe> kDemoRecipes = [..._chipRecipes, ..._leafRecipes];

/// 아무것도 매칭되지 않을 때. 반드시 하나는 재생돼야 한다.
const DemoRecipe kDemoFallback = DemoRecipe(
  id: 'demo.fallback',
  name: 'Little nod',
  face: 'neutral',
  reasoning: 'Purebot acknowledges what you said with a small nod.',
  keywords: [],
  recipe: Recipe(steps: [
    RecipeStep(behavior: 'nod', speed: 1.0, amplitude: 0.9, face: 'neutral'),
    RecipeStep(behavior: 'idle', speed: 1.0),
  ]),
);

DemoRecipe? demoRecipeById(String id) {
  for (final r in kDemoRecipes) {
    if (r.id == id) return r;
  }
  return null;
}

DemoRecipe demoRecipeForChip(String chipId) {
  for (final r in kDemoRecipes) {
    if (r.chipId == chipId) return r;
  }
  return kDemoFallback;
}

/// 질문 트리 리프 조합에 맞는 레시피. 없으면 칩 기본.
DemoRecipe demoRecipeForLeaf({String? chipId, String? whenOptionId, String? howOptionId}) {
  for (final r in _leafRecipes) {
    if (r.howOptionId == howOptionId && r.whenOptionId == whenOptionId) return r;
  }
  for (final r in _leafRecipes) {
    if (r.howOptionId == howOptionId) return r;
  }
  return chipId == null ? kDemoFallback : demoRecipeForChip(chipId);
}
