import 'motion_spec.dart';

/// 질문형 생성(06-9) 3단계의 진행 상태.
class QuestionSession {
  const QuestionSession({
    required this.chatId,
    this.step = 1,
    this.answers = const [],
    this.draft,
    this.seedChipId,
  });

  final String chatId;

  /// 1 = 언제 / 2 = 어떻게 / 3 = 확인.
  final int step;

  /// 지금까지 고른 답. 길이가 곧 진행도다.
  final List<String> answers;

  /// 2단계부터 재생되는 초안.
  final MotionSpec? draft;

  /// 어느 칩에서 들어왔는지. 자유 입력이면 null.
  final String? seedChipId;

  bool get isLast => step >= 3;

  QuestionSession copyWith({
    int? step,
    List<String>? answers,
    MotionSpec? draft,
  }) =>
      QuestionSession(
        chatId: chatId,
        step: step ?? this.step,
        answers: answers ?? this.answers,
        draft: draft ?? this.draft,
        seedChipId: seedChipId,
      );

  Map<String, Object?> toJson() => {
        'chatId': chatId,
        'step': step,
        'answers': answers,
        'draft': ?draft?.toJson(),
        'seedChipId': ?seedChipId,
      };

  factory QuestionSession.fromJson(Map<String, Object?> json) => QuestionSession(
        chatId: json['chatId'] as String? ?? '',
        step: (json['step'] as num?)?.toInt() ?? 1,
        answers: ((json['answers'] as List?) ?? const []).map((e) => e.toString()).toList(),
        draft: json['draft'] == null
            ? null
            : MotionSpec.fromJson((json['draft'] as Map).cast<String, Object?>()),
        seedChipId: json['seedChipId'] as String?,
      );
}
