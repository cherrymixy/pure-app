import '../models/motion_signature.dart';

/// 05 모션 시그니처 화면의 선택지와, 그 선택이 축 값으로 어떻게 번역되는지.
///
/// 축 값(lively / bold / richness)은 STEP 6 의 motion_engine 이 재생 파라미터로
/// 바꾼다. 여기서는 "선택지 → 축" 매핑만 들고 있다.

/// 05-1 성격.
class PersonalityOption {
  const PersonalityOption({
    required this.id,
    required this.label,
    required this.description,
    required this.lively,
    required this.bold,
    required this.idleBehavior,
  });

  final String id;
  final String label;
  final String description;

  /// 0~100.
  final int lively;
  final int bold;

  /// 이 성격의 대기 모션 (PRD §6-9).
  final String idleBehavior;
}

/// 05-2 관계 방식.
class RelationshipOption {
  const RelationshipOption({
    required this.value,
    required this.label,
    required this.description,
    required this.greetBehavior,
  });

  final Relationship value;
  final String label;
  final String description;

  /// 05-2 에서 세 방식을 순서대로 짧게 보여줄 때 쓰는 동작.
  final String greetBehavior;
}

/// 05-3 움직임 표현.
class ExpressionOption {
  const ExpressionOption({
    required this.value,
    required this.label,
    required this.description,
    required this.speedFactor,
  });

  final Expression value;
  final String label;
  final String description;

  /// 재생 속도 배율 (PRD §6-9: A 1.2 / B 0.8 / between 1.0).
  final double speedFactor;
}

const List<PersonalityOption> kPersonalityOptions = [
  PersonalityOption(
    id: 'calm',
    label: 'Calm & gentle',
    description: 'Moves softly, stays still unless something happens',
    lively: 20,
    bold: 25,
    idleBehavior: 'doze',
  ),
  PersonalityOption(
    id: 'lively',
    label: 'Lively',
    description: 'Looks around often, reacts quickly',
    lively: 80,
    bold: 50,
    idleBehavior: 'look_around',
  ),
  PersonalityOption(
    id: 'bold',
    label: 'Bold & curious',
    description: 'Leans in close, wants to see everything',
    lively: 65,
    bold: 85,
    idleBehavior: 'curious',
  ),
];

const List<RelationshipOption> kRelationshipOptions = [
  RelationshipOption(
    value: Relationship.comesFirst,
    label: 'Comes to me first',
    description: 'Turns toward you before you ask',
    greetBehavior: 'greet',
  ),
  RelationshipOption(
    value: Relationship.waitsNear,
    label: "Waits till I'm near",
    description: 'Stays quiet until you come close',
    greetBehavior: 'nod',
  ),
  RelationshipOption(
    value: Relationship.onlyNeeded,
    label: 'Only when needed',
    description: 'Keeps to itself unless you call',
    greetBehavior: 'focus',
  ),
];

const List<ExpressionOption> kExpressionOptions = [
  ExpressionOption(
    value: Expression.quickBouncy,
    label: 'Quick & bouncy',
    description: 'Short, springy movements',
    speedFactor: 1.2,
  ),
  ExpressionOption(
    value: Expression.slowSmooth,
    label: 'Slow & smooth',
    description: 'Long, flowing movements',
    speedFactor: 0.8,
  ),
  ExpressionOption(
    value: Expression.inBetween,
    label: 'In between',
    description: 'A bit of both',
    speedFactor: 1.0,
  ),
];

/// 05-3 은 A/B 를 번갈아 재생한다. A = quickBouncy, B = slowSmooth.
const Expression kExpressionA = Expression.quickBouncy;
const Expression kExpressionB = Expression.slowSmooth;

PersonalityOption? personalityById(String id) {
  for (final o in kPersonalityOptions) {
    if (o.id == id) return o;
  }
  return null;
}

/// 현재 시그니처에 가장 가까운 성격 선택지 — 편집 모드에서 현재 답을 강조할 때 쓴다.
PersonalityOption personalityFor(MotionSignature s) {
  PersonalityOption best = kPersonalityOptions.first;
  var bestDist = 1 << 30;
  for (final o in kPersonalityOptions) {
    final d = (o.lively - s.lively).abs() + (o.bold - s.bold).abs();
    if (d < bestDist) {
      bestDist = d;
      best = o;
    }
  }
  return best;
}

RelationshipOption relationshipFor(Relationship v) =>
    kRelationshipOptions.firstWhere((o) => o.value == v);

ExpressionOption expressionFor(Expression v) =>
    kExpressionOptions.firstWhere((o) => o.value == v);

/// 성격 선택을 시그니처에 반영한다.
MotionSignature applyPersonality(MotionSignature s, PersonalityOption o) =>
    s.copyWith(lively: o.lively, bold: o.bold);

/// 상단 로봇 상태 줄의 요약 — "LIVELY, BOUNCY" (PRD §4 공통).
String signatureSummary(MotionSignature s) {
  final p = personalityFor(s).label.split(' ').first.toUpperCase();
  final e = expressionFor(s.expression).label.split(' ').last.toUpperCase();
  return '$p, $e';
}
