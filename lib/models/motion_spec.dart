import 'clip.dart';
import 'motion_signature.dart';
import 'recipe.dart';

/// 재생 방식. Tier 1 = 레시피(기본), Tier 2 = 키프레임 클립(플래그 directClip).
enum SpecMode { recipe, clip }

/// 생성된 모션 하나. 채팅 답장·라이브러리·질문형 초안이 전부 이걸 들고 다닌다.
class MotionSpec {
  const MotionSpec({
    required this.id,
    required this.name,
    required this.face,
    required this.mode,
    required this.recipe,
    required this.signatureSnapshot,
    this.clip,
    this.reasoning = '',
    this.version = 1,
    this.thumbnailPath,
  });

  final String id;

  /// 저장 시트의 이름 제안에 쓰인다. 1~20자.
  final String name;

  /// 기본 표정 (7종 허용 목록).
  final String face;

  final SpecMode mode;

  /// clip 모드여도 레시피는 항상 함께 들고 있다 — 검증 실패 시 바로 폴백한다.
  final Recipe recipe;

  final Clip? clip;

  /// GPT 가 쓴 설명. UI 문구가 영어라 영어로 받는다.
  final String reasoning;

  /// 생성 당시의 시그니처. 나중에 시그니처를 바꿔도 이 값은 변하지 않는다.
  final MotionSignature signatureSnapshot;

  /// 피드백으로 재생성할 때마다 1씩 올라간다.
  final int version;

  /// 시뮬 capture() PNG 를 저장한 경로. 라이브러리 썸네일.
  final String? thumbnailPath;

  /// 클립 모드지만 클립이 없으면 레시피로 본다.
  SpecMode get effectiveMode => mode == SpecMode.clip && clip != null ? SpecMode.clip : SpecMode.recipe;

  MotionSpec copyWith({
    String? id,
    String? name,
    String? face,
    SpecMode? mode,
    Recipe? recipe,
    Clip? clip,
    String? reasoning,
    MotionSignature? signatureSnapshot,
    int? version,
    String? thumbnailPath,
  }) =>
      MotionSpec(
        id: id ?? this.id,
        name: name ?? this.name,
        face: face ?? this.face,
        mode: mode ?? this.mode,
        recipe: recipe ?? this.recipe,
        clip: clip ?? this.clip,
        reasoning: reasoning ?? this.reasoning,
        signatureSnapshot: signatureSnapshot ?? this.signatureSnapshot,
        version: version ?? this.version,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'face': face,
        'mode': mode.name,
        'recipe': recipe.toJson(),
        'clip': ?clip?.toJson(),
        'reasoning': reasoning,
        'signatureSnapshot': signatureSnapshot.toJson(),
        'version': version,
        'thumbnailPath': ?thumbnailPath,
      };

  factory MotionSpec.fromJson(Map<String, Object?> json) => MotionSpec(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        face: json['face'] as String? ?? 'neutral',
        mode: SpecMode.values
            .firstWhere((e) => e.name == json['mode'], orElse: () => SpecMode.recipe),
        recipe: Recipe.fromJson((json['recipe'] as Map?)?.cast<String, Object?>() ?? const {}),
        clip: json['clip'] == null
            ? null
            : Clip.fromJson((json['clip'] as Map).cast<String, Object?>()),
        reasoning: json['reasoning'] as String? ?? '',
        signatureSnapshot: MotionSignature.fromJson(
          (json['signatureSnapshot'] as Map?)?.cast<String, Object?>() ?? const {},
        ),
        version: (json['version'] as num?)?.toInt() ?? 1,
        thumbnailPath: json['thumbnailPath'] as String?,
      );
}
