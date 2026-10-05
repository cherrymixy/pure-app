/// 키프레임 하나. 시각(초)과 각도(도).
class ClipKey {
  const ClipKey({required this.t, required this.value, this.easing = 'ease_in_out'});

  final double t;
  final double value;

  /// sim 의 EASINGS 키: linear / ease_in_out / ease_in / ease_out /
  /// ease_out_back / ease_out_elastic / ease_out_bounce.
  final String easing;

  Map<String, Object?> toJson() => {'t': t, 'value': value, 'easing': easing};

  factory ClipKey.fromJson(Map<String, Object?> json) => ClipKey(
        t: (json['t'] as num?)?.toDouble() ?? 0,
        value: (json['value'] as num?)?.toDouble() ?? 0,
        easing: json['easing'] as String? ?? 'ease_in_out',
      );
}

/// 관절별 키프레임 트랙 묶음 — GPT Tier 2(플래그 `directClip`)의 출력.
///
/// 관절 이름은 **계약 이름**(base_yaw / shoulder_pitch / elbow_pitch / head_pan /
/// head_tilt)을 쓴다. sim 내부 채널명(wrist_roll 등)을 넣으면 api.ts 가 거부한다.
class Clip {
  const Clip({
    required this.duration,
    required this.tracks,
    this.face,
    this.format = formatV1,
  });

  static const String formatV1 = 'lelamp.clip/1';

  /// 1~8초. 범위 강제는 motion_engine.validateClip 이 한다.
  final double duration;

  /// 계약 관절 이름 → 키프레임 목록. 생략한 관절은 움직이지 않는다.
  final Map<String, List<ClipKey>> tracks;

  final String? face;
  final String format;

  bool get isEmpty => tracks.isEmpty || tracks.values.every((k) => k.isEmpty);

  int get keyCount => tracks.values.fold(0, (sum, keys) => sum + keys.length);

  Clip copyWith({double? duration, Map<String, List<ClipKey>>? tracks, String? face}) => Clip(
        duration: duration ?? this.duration,
        tracks: tracks ?? this.tracks,
        face: face ?? this.face,
        format: format,
      );

  /// `window.pure.playClip` 이 받는 모양 그대로 (PRD 부록 B).
  Map<String, Object?> toJson() => {
        'format': format,
        'duration': duration,
        'tracks': tracks.map(
          (joint, keys) => MapEntry(joint, keys.map((k) => k.toJson()).toList()),
        ),
        'face': ?face,
      };

  factory Clip.fromJson(Map<String, Object?> json) => Clip(
        format: json['format'] as String? ?? formatV1,
        duration: (json['duration'] as num?)?.toDouble() ?? 0,
        tracks: ((json['tracks'] as Map?) ?? const {}).map(
          (joint, keys) => MapEntry(
            joint.toString(),
            ((keys as List?) ?? const [])
                .whereType<Map>()
                .map((e) => ClipKey.fromJson(e.cast<String, Object?>()))
                .toList(),
          ),
        ),
        face: json['face'] as String?,
      );
}
