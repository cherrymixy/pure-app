/// 레시피의 한 단계 — 동작 15종 중 하나를 어떻게 재생할지.
///
/// 범위(speed 0.5~1.6, amplitude 0.4~1.5, repeat 1~4)는 여기서 강제하지 않는다.
/// GPT 출력 검증은 STEP 6 의 motion_engine 이 전담한다 — OpenAI 의 strict 스키마가
/// minimum/maximum 을 지원하지 않아서, 범위는 반드시 파싱 후에 클램프해야 한다.
class RecipeStep {
  const RecipeStep({
    required this.behavior,
    this.speed = 1.0,
    this.amplitude = 1.0,
    this.repeat = 1,
    this.face,
  });

  /// data/behaviors.dart 의 허용 목록 안에 있어야 한다.
  final String behavior;
  final double speed;
  final double amplitude;
  final int repeat;

  /// 이 단계에서 바꿀 표정. null 이면 동작 기본 표정.
  final String? face;

  RecipeStep copyWith({double? speed, double? amplitude, int? repeat, String? face}) =>
      RecipeStep(
        behavior: behavior,
        speed: speed ?? this.speed,
        amplitude: amplitude ?? this.amplitude,
        repeat: repeat ?? this.repeat,
        face: face ?? this.face,
      );

  /// `window.pure.playRecipe` 가 받는 모양 그대로 (PRD 부록 B).
  Map<String, Object?> toJson() => {
        'behavior': behavior,
        'speed': speed,
        'amplitude': amplitude,
        'repeat': repeat,
        'face': ?face,
      };

  factory RecipeStep.fromJson(Map<String, Object?> json) => RecipeStep(
        behavior: json['behavior'] as String? ?? '',
        speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
        amplitude: (json['amplitude'] as num?)?.toDouble() ?? 1.0,
        repeat: (json['repeat'] as num?)?.toInt() ?? 1,
        face: json['face'] as String?,
      );
}

/// 동작 조합. GPT Tier 1 의 출력이자 데모 모드의 재생 단위.
class Recipe {
  const Recipe({required this.steps, this.loop = false});

  final List<RecipeStep> steps;
  final bool loop;

  bool get isEmpty => steps.isEmpty;

  Recipe copyWith({List<RecipeStep>? steps, bool? loop}) =>
      Recipe(steps: steps ?? this.steps, loop: loop ?? this.loop);

  Map<String, Object?> toJson() => {
        'steps': steps.map((s) => s.toJson()).toList(),
        'loop': loop,
      };

  factory Recipe.fromJson(Map<String, Object?> json) => Recipe(
        steps: ((json['steps'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => RecipeStep.fromJson(e.cast<String, Object?>()))
            .toList(),
        loop: json['loop'] as bool? ?? false,
      );
}
