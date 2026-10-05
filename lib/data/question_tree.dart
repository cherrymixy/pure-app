/// 질문형 생성(06-9)의 고정 트리.
///
/// 칩에서 들어오면 이 트리를 쓰고, 자유 텍스트로 들어오면 GPT 가 예시 3개를 만든다
/// (실패·오프라인이면 [kFallbackBranch] 로 폴백 — 부록 D 결정).
///
/// 문구는 전부 영어. 원형 버튼은 2줄까지라 짧게 유지한다.
///
/// 🟡 PRD 에는 패턴과 예시 하나(Someone comes home / I say good night / A loud noise)만
/// 있어서 나머지는 그 패턴대로 채웠다. 전시 대본 확정되면 여기만 고치면 된다.
library;

import '../models/saved_motion.dart';

/// 1단계 답 하나 — "언제".
class WhenOption {
  const WhenOption({
    required this.id,
    required this.label,
    required this.situation,
    required this.exampleBehavior,
    required this.exampleLabel,
  });

  final String id;

  /// 원형 버튼 라벨. 2줄까지.
  final String label;

  /// 저장 시트의 반응 상황을 미리 채우는 데 쓴다.
  final Situation situation;

  /// 1단계에서 카드에 미리 보여줄 예시 모션 (허용 목록 안).
  final String exampleBehavior;

  /// 카드 위 칩 문구. "Example / Shy nod" 의 뒷부분.
  final String exampleLabel;
}

/// 2단계 답 하나 — "어떻게".
class HowOption {
  const HowOption({required this.id, required this.label, required this.hint});

  final String id;
  final String label;

  /// 생성 요청에 함께 보내는 설명. 버튼 라벨만으로는 의도가 얇다.
  final String hint;
}

/// 칩 하나에 대한 질문 가지.
class QuestionBranch {
  const QuestionBranch({
    required this.chipId,
    required this.whenOptions,
    required this.howOptions,
  });

  final String chipId;
  final List<WhenOption> whenOptions;
  final List<HowOption> howOptions;
}

const String kStep1Question = 'When should Purebot do this?';
const String kStep2Question = 'How should it react?';
const String kStep3Question = 'Like this one?';

/// 칩 5개의 트리.
const List<QuestionBranch> kQuestionTree = [
  QuestionBranch(
    chipId: 'cameHome',
    whenOptions: [
      WhenOption(
        id: 'someoneComesHome',
        label: 'Someone\ncomes home',
        situation: Situation.comesHome,
        exampleBehavior: 'greet',
        exampleLabel: 'Warm hello',
      ),
      WhenOption(
        id: 'iGetBack',
        label: 'I get back\nfrom work',
        situation: Situation.comesHome,
        exampleBehavior: 'happy',
        exampleLabel: 'Happy bounce',
      ),
      WhenOption(
        id: 'doorOpens',
        label: 'The door\nopens',
        situation: Situation.startled,
        exampleBehavior: 'alert',
        exampleLabel: 'Quick look',
      ),
    ],
    howOptions: [
      HowOption(
        id: 'wave',
        label: 'Wave\nhello',
        hint: 'A big, friendly greeting — lean forward and wave the whole body',
      ),
      HowOption(
        id: 'perkUp',
        label: 'Perk up\nand look',
        hint: 'Lift the head and turn toward the person, then settle',
      ),
      HowOption(
        id: 'shyNod',
        label: 'A shy\nnod',
        hint: 'A small, quiet nod — barely moves, slightly looks down after',
      ),
    ],
  ),
  QuestionBranch(
    chipId: 'tired',
    whenOptions: [
      WhenOption(
        id: 'iSayImTired',
        label: "I say\nI'm tired",
        situation: Situation.tired,
        exampleBehavior: 'sad',
        exampleLabel: 'Gentle slump',
      ),
      WhenOption(
        id: 'iSayGoodNight',
        label: 'I say\ngood night',
        situation: Situation.tired,
        exampleBehavior: 'doze',
        exampleLabel: 'Sleepy drift',
      ),
      WhenOption(
        id: 'lateAtDesk',
        label: "It's late\nat my desk",
        situation: Situation.tired,
        exampleBehavior: 'sleep',
        exampleLabel: 'Settles down',
      ),
    ],
    howOptions: [
      HowOption(
        id: 'leanIn',
        label: 'Lean in\nto comfort',
        hint: 'Move slowly toward the person and hold still, like a quiet check-in',
      ),
      HowOption(
        id: 'restWithMe',
        label: 'Rest\nwith me',
        hint: 'Droop softly and breathe — keeps me company without asking anything',
      ),
      HowOption(
        id: 'nudgeToBed',
        label: 'Nudge me\nto rest',
        hint: 'A small insistent nod toward the side, then a sleepy settle',
      ),
    ],
  ),
  QuestionBranch(
    chipId: 'thankYou',
    whenOptions: [
      WhenOption(
        id: 'iSayThanks',
        label: 'I say\nthank you',
        situation: Situation.onlyWhenAsked,
        exampleBehavior: 'happy',
        exampleLabel: 'Pleased wiggle',
      ),
      WhenOption(
        id: 'iPraiseIt',
        label: 'I praise\nPurebot',
        situation: Situation.onlyWhenAsked,
        exampleBehavior: 'nod',
        exampleLabel: 'Proud nod',
      ),
      WhenOption(
        id: 'weFinish',
        label: 'We finish\nsomething',
        situation: Situation.onlyWhenAsked,
        exampleBehavior: 'greet',
        exampleLabel: 'Little cheer',
      ),
    ],
    howOptions: [
      HowOption(
        id: 'bashful',
        label: 'Get a bit\nbashful',
        hint: 'Turn away slightly, then peek back — shy but pleased',
      ),
      HowOption(
        id: 'cheer',
        label: 'Cheer\nout loud',
        hint: 'Big bouncy motion, head up, repeats twice',
      ),
      HowOption(
        id: 'quietNod',
        label: 'Just a\nquiet nod',
        hint: 'One small nod and back to resting — understated',
      ),
    ],
  ),
  QuestionBranch(
    chipId: 'startled',
    whenOptions: [
      WhenOption(
        id: 'loudNoise',
        label: 'A loud\nnoise',
        situation: Situation.startled,
        exampleBehavior: 'alert',
        exampleLabel: 'Startled snap',
      ),
      WhenOption(
        id: 'somethingFalls',
        label: 'Something\nfalls',
        situation: Situation.startled,
        exampleBehavior: 'shake',
        exampleLabel: 'Quick shake',
      ),
      WhenOption(
        id: 'suddenMove',
        label: 'A sudden\nmovement',
        situation: Situation.startled,
        exampleBehavior: 'look_around',
        exampleLabel: 'Scans around',
      ),
    ],
    howOptions: [
      HowOption(
        id: 'jumpBack',
        label: 'Jump\nback',
        hint: 'Snap away fast, then creep back to look at what happened',
      ),
      HowOption(
        id: 'freeze',
        label: 'Freeze\nin place',
        hint: 'Stop dead, hold, then slowly relax',
      ),
      HowOption(
        id: 'checkOnMe',
        label: 'Check\non me',
        hint: 'Turn toward the person first, then look at the noise',
      ),
    ],
  ),
  QuestionBranch(
    chipId: 'whatIsThis',
    whenOptions: [
      WhenOption(
        id: 'iShowSomething',
        label: 'I show it\nsomething',
        situation: Situation.onlyWhenAsked,
        exampleBehavior: 'curious',
        exampleLabel: 'Head tilt',
      ),
      WhenOption(
        id: 'newThingOnDesk',
        label: 'A new thing\non my desk',
        situation: Situation.onlyWhenAsked,
        exampleBehavior: 'focus',
        exampleLabel: 'Leans in close',
      ),
      WhenOption(
        id: 'iAskAbout',
        label: 'I ask\nabout it',
        situation: Situation.onlyWhenAsked,
        exampleBehavior: 'look_around',
        exampleLabel: 'Looks for it',
      ),
    ],
    howOptions: [
      HowOption(
        id: 'tiltAndStudy',
        label: 'Tilt and\nstudy it',
        hint: 'Tilt the head, hold, tilt the other way — reading it slowly',
      ),
      HowOption(
        id: 'circleAround',
        label: 'Look it\nover',
        hint: 'Sweep left and right across it, then settle facing it',
      ),
      HowOption(
        id: 'carefulPoke',
        label: 'Approach\ncarefully',
        hint: 'Creep forward in small steps, pausing between each',
      ),
    ],
  ),
];

/// 자유 입력에서 GPT 예시 생성이 실패했을 때 쓰는 기본 가지.
/// PRD §3 에 적힌 예시 그대로다.
const QuestionBranch kFallbackBranch = QuestionBranch(
  chipId: '',
  whenOptions: [
    WhenOption(
      id: 'someoneComesHome',
      label: 'Someone\ncomes home',
      situation: Situation.comesHome,
      exampleBehavior: 'greet',
      exampleLabel: 'Warm hello',
    ),
    WhenOption(
      id: 'iSayGoodNight',
      label: 'I say\ngood night',
      situation: Situation.tired,
      exampleBehavior: 'doze',
      exampleLabel: 'Sleepy drift',
    ),
    WhenOption(
      id: 'loudNoise',
      label: 'A loud\nnoise',
      situation: Situation.startled,
      exampleBehavior: 'alert',
      exampleLabel: 'Startled snap',
    ),
  ],
  howOptions: [
    HowOption(
      id: 'perkUp',
      label: 'Perk up\nand look',
      hint: 'Lift the head and turn toward it, then settle',
    ),
    HowOption(
      id: 'turnAway',
      label: 'Turn\naway',
      hint: 'Rotate away from it and stay low',
    ),
    HowOption(
      id: 'quietNod',
      label: 'Just a\nquiet nod',
      hint: 'One small nod and back to resting',
    ),
  ],
);

QuestionBranch branchForChip(String? chipId) {
  for (final b in kQuestionTree) {
    if (b.chipId == chipId) return b;
  }
  return kFallbackBranch;
}

WhenOption? whenOptionById(String id) {
  for (final b in [...kQuestionTree, kFallbackBranch]) {
    for (final o in b.whenOptions) {
      if (o.id == id) return o;
    }
  }
  return null;
}

HowOption? howOptionById(String id) {
  for (final b in [...kQuestionTree, kFallbackBranch]) {
    for (final o in b.howOptions) {
      if (o.id == id) return o;
    }
  }
  return null;
}
