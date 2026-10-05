/// 로봇 행동 기록 (08-5). 시드 더미.
enum ActivityTrigger { auto, byYou }

class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.motionName,
    required this.trigger,
    required this.at,
    this.situationLabel,
  });

  final String id;
  final String motionName;
  final ActivityTrigger trigger;

  /// "When someone comes home" 같은 문구. 수동 실행이면 null.
  final String? situationLabel;

  final DateTime at;

  Map<String, Object?> toJson() => {
        'id': id,
        'motionName': motionName,
        'trigger': trigger.name,
        'situationLabel': ?situationLabel,
        'at': at.toIso8601String(),
      };

  factory ActivityItem.fromJson(Map<String, Object?> json) => ActivityItem(
        id: json['id'] as String? ?? '',
        motionName: json['motionName'] as String? ?? '',
        trigger: ActivityTrigger.values
            .firstWhere((e) => e.name == json['trigger'], orElse: () => ActivityTrigger.byYou),
        situationLabel: json['situationLabel'] as String?,
        at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime(2026),
      );
}
