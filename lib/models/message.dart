import 'motion_spec.dart';

enum Sender { user, robot }

enum MessageStatus { sent, generating, done, failed }

/// 첨부 영상. 파일은 자르지 않고 구간 값만 들고 있다 (PRD §9).
class VideoAttachment {
  const VideoAttachment({
    required this.path,
    required this.thumbPath,
    required this.durationSec,
    required this.trimStart,
    required this.trimEnd,
  });

  /// 원본 경로. 앱 밖으로 나가지 않는다 (추출한 프레임만 API 로 간다).
  final String path;
  final String thumbPath;
  final double durationSec;

  /// 프레임을 뽑을 구간. 30초 이하면 0 ~ durationSec.
  final double trimStart;
  final double trimEnd;

  double get selectedSec => (trimEnd - trimStart).clamp(0, durationSec).toDouble();

  Map<String, Object?> toJson() => {
        'path': path,
        'thumbPath': thumbPath,
        'durationSec': durationSec,
        'trimStart': trimStart,
        'trimEnd': trimEnd,
      };

  factory VideoAttachment.fromJson(Map<String, Object?> json) => VideoAttachment(
        path: json['path'] as String? ?? '',
        thumbPath: json['thumbPath'] as String? ?? '',
        durationSec: (json['durationSec'] as num?)?.toDouble() ?? 0,
        trimStart: (json['trimStart'] as num?)?.toDouble() ?? 0,
        trimEnd: (json['trimEnd'] as num?)?.toDouble() ?? 0,
      );
}

/// 채팅 메시지 하나. 질문형(06-9)의 답과 초안도 여기에 기록된다.
class Message {
  const Message({
    required this.id,
    required this.sender,
    required this.status,
    required this.createdAt,
    this.text,
    this.video,
    this.spec,
  });

  final String id;
  final Sender sender;
  final String? text;
  final VideoAttachment? video;
  final MessageStatus status;

  /// 로봇 답장이면 생성된 모션.
  final MotionSpec? spec;

  final DateTime createdAt;

  Message copyWith({
    String? text,
    MessageStatus? status,
    MotionSpec? spec,
    VideoAttachment? video,
  }) =>
      Message(
        id: id,
        sender: sender,
        text: text ?? this.text,
        video: video ?? this.video,
        status: status ?? this.status,
        spec: spec ?? this.spec,
        createdAt: createdAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'sender': sender.name,
        'text': ?text,
        'video': ?video?.toJson(),
        'status': status.name,
        'spec': ?spec?.toJson(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Message.fromJson(Map<String, Object?> json) => Message(
        id: json['id'] as String? ?? '',
        sender: Sender.values
            .firstWhere((e) => e.name == json['sender'], orElse: () => Sender.user),
        text: json['text'] as String?,
        video: json['video'] == null
            ? null
            : VideoAttachment.fromJson((json['video'] as Map).cast<String, Object?>()),
        status: MessageStatus.values
            .firstWhere((e) => e.name == json['status'], orElse: () => MessageStatus.done),
        spec: json['spec'] == null
            ? null
            : MotionSpec.fromJson((json['spec'] as Map).cast<String, Object?>()),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime(2026),
      );
}

/// 하나의 대화. 채팅 모드와 질문형 모드가 이 위에 같이 올라간다 (부록 D 결정).
class Chat {
  const Chat({
    required this.id,
    required this.messages,
    required this.createdAt,
    required this.lastActiveAt,
  });

  final String id;
  final List<Message> messages;
  final DateTime createdAt;
  final DateTime lastActiveAt;

  /// 로봇 답장 수 (06-8 목록에 표시).
  int get replyCount => messages.where((m) => m.sender == Sender.robot).length;

  Message? get lastRobotReply {
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].sender == Sender.robot && messages[i].spec != null) return messages[i];
    }
    return null;
  }

  Chat copyWith({List<Message>? messages, DateTime? lastActiveAt}) => Chat(
        id: id,
        messages: messages ?? this.messages,
        createdAt: createdAt,
        lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'messages': messages.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'lastActiveAt': lastActiveAt.toIso8601String(),
      };

  factory Chat.fromJson(Map<String, Object?> json) => Chat(
        id: json['id'] as String? ?? '',
        messages: ((json['messages'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Message.fromJson(e.cast<String, Object?>()))
            .toList(),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime(2026),
        lastActiveAt: DateTime.tryParse(json['lastActiveAt'] as String? ?? '') ?? DateTime(2026),
      );
}
