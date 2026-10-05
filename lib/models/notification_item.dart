/// 알림 목록 항목 (10-1). 시드 더미 — 실제 푸시는 범위 밖이다.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.target,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  /// 탭했을 때 갈 화면 키 (예: 'library', 'robot').
  final String? target;

  NotificationItem copyWith({bool? read}) => NotificationItem(
        id: id,
        title: title,
        body: body,
        createdAt: createdAt,
        read: read ?? this.read,
        target: target,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'read': read,
        'target': ?target,
      };

  factory NotificationItem.fromJson(Map<String, Object?> json) => NotificationItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime(2026),
        read: json['read'] as bool? ?? false,
        target: json['target'] as String?,
      );
}
