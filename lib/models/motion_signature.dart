/// 로봇이 사람에게 먼저 다가가는 방식.
enum Relationship { comesFirst, waitsNear, onlyNeeded }

/// 움직임의 결.
enum Expression { quickBouncy, slowSmooth, inBetween }

T _enumFrom<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.firstWhere((e) => e.name == name, orElse: () => fallback);

/// 모션 시그니처 — 이 로봇을 '이 로봇'으로 만드는 값들.
///
/// 대기 모션과 생성 결과 양쪽에 반영된다. 생성된 모션에는 그때의 시그니처가
/// 스냅샷으로 함께 저장되므로, 나중에 시그니처를 바꿔도 저장된 모션은 그대로다.
class MotionSignature {
  const MotionSignature({
    this.lively = 75,
    this.bold = 50,
    this.relationship = Relationship.waitsNear,
    this.expression = Expression.quickBouncy,
    this.richness = 50,
    this.sound = 'soft',
  });

  /// 0~100. 높을수록 자주·빠르게 움직인다.
  final int lively;

  /// 0~100. 높을수록 동작이 크다.
  final int bold;

  final Relationship relationship;
  final Expression expression;

  /// 0~100. 부수 동작(곁다리 움직임)의 풍부함.
  final int richness;

  /// 소리 프리셋 이름. 시뮬레이터는 소리를 내지 않지만 값은 들고 다닌다.
  final String sound;

  /// PRD 부록 D 시드: Lively · Waits till I'm near · Quick & bouncy.
  static const MotionSignature seed = MotionSignature();

  MotionSignature copyWith({
    int? lively,
    int? bold,
    Relationship? relationship,
    Expression? expression,
    int? richness,
    String? sound,
  }) =>
      MotionSignature(
        lively: lively ?? this.lively,
        bold: bold ?? this.bold,
        relationship: relationship ?? this.relationship,
        expression: expression ?? this.expression,
        richness: richness ?? this.richness,
        sound: sound ?? this.sound,
      );

  Map<String, Object?> toJson() => {
        'lively': lively,
        'bold': bold,
        'relationship': relationship.name,
        'expression': expression.name,
        'richness': richness,
        'sound': sound,
      };

  factory MotionSignature.fromJson(Map<String, Object?> json) => MotionSignature(
        lively: (json['lively'] as num?)?.toInt() ?? 75,
        bold: (json['bold'] as num?)?.toInt() ?? 50,
        relationship:
            _enumFrom(Relationship.values, json['relationship'], Relationship.waitsNear),
        expression: _enumFrom(Expression.values, json['expression'], Expression.quickBouncy),
        richness: (json['richness'] as num?)?.toInt() ?? 50,
        sound: json['sound'] as String? ?? 'soft',
      );

  @override
  bool operator ==(Object other) =>
      other is MotionSignature &&
      other.lively == lively &&
      other.bold == bold &&
      other.relationship == relationship &&
      other.expression == expression &&
      other.richness == richness &&
      other.sound == sound;

  @override
  int get hashCode => Object.hash(lively, bold, relationship, expression, richness, sound);
}
