import 'motion_spec.dart';

/// 저장된 모션이 언제 재생되는가.
enum ReactionKind {
  /// 상황이 오면 묻지 않고 바로 (라이브러리 Auto 그룹).
  auto,

  /// 상황이 오면 물어보고.
  askFirst,

  /// 내가 부를 때만.
  manual,
}

/// 반응 상황 4종 (PRD §5).
enum Situation { comesHome, tired, startled, onlyWhenAsked }

/// 라이브러리에 저장된 모션.
class SavedMotion {
  const SavedMotion({
    required this.id,
    required this.name,
    required this.spec,
    required this.kind,
    required this.savedAt,
    required this.chatId,
    this.situation,
    this.editCount = 0,
  });

  final String id;

  /// 1~20자. 라이브러리에서 중복은 허용하지 않는다.
  final String name;

  final MotionSpec spec;
  final ReactionKind kind;

  /// auto / askFirst 일 때의 상황. manual 이면 null.
  final Situation? situation;

  final DateTime savedAt;

  /// Edit in chat 후 다시 저장할 때마다 1씩 올라간다.
  final int editCount;

  /// 이 모션을 만든 대화. "Edit in chat" 이 여기로 돌아간다.
  final String chatId;

  SavedMotion copyWith({
    String? name,
    MotionSpec? spec,
    ReactionKind? kind,
    Situation? situation,
    int? editCount,
    bool clearSituation = false,
  }) =>
      SavedMotion(
        id: id,
        name: name ?? this.name,
        spec: spec ?? this.spec,
        kind: kind ?? this.kind,
        situation: clearSituation ? null : (situation ?? this.situation),
        savedAt: savedAt,
        editCount: editCount ?? this.editCount,
        chatId: chatId,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'spec': spec.toJson(),
        'kind': kind.name,
        'situation': ?situation?.name,
        'savedAt': savedAt.toIso8601String(),
        'editCount': editCount,
        'chatId': chatId,
      };

  factory SavedMotion.fromJson(Map<String, Object?> json) => SavedMotion(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        spec: MotionSpec.fromJson((json['spec'] as Map?)?.cast<String, Object?>() ?? const {}),
        kind: ReactionKind.values
            .firstWhere((e) => e.name == json['kind'], orElse: () => ReactionKind.manual),
        situation: json['situation'] == null
            ? null
            : Situation.values.firstWhere(
                (e) => e.name == json['situation'],
                orElse: () => Situation.onlyWhenAsked,
              ),
        savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime(2026),
        editCount: (json['editCount'] as num?)?.toInt() ?? 0,
        chatId: json['chatId'] as String? ?? '',
      );
}
