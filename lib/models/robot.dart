import 'motion_signature.dart';

/// 로봇. 연결 기능이 없으므로 시드 하나만 존재한다.
class Robot {
  const Robot({
    required this.id,
    required this.name,
    required this.model,
    required this.signature,
  });

  final String id;
  final String name;
  final String model;
  final MotionSignature signature;

  Robot copyWith({String? name, MotionSignature? signature}) => Robot(
        id: id,
        name: name ?? this.name,
        model: model,
        signature: signature ?? this.signature,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'model': model,
        'signature': signature.toJson(),
      };

  factory Robot.fromJson(Map<String, Object?> json) => Robot(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        model: json['model'] as String? ?? '',
        signature: MotionSignature.fromJson(
          (json['signature'] as Map?)?.cast<String, Object?>() ?? const {},
        ),
      );
}
