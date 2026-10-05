/// 사용자 프로필. 서버·로그인이 없으므로 시드 값으로 시작한다.
class UserProfile {
  const UserProfile({required this.name, required this.email});

  /// 1~20자. 홈 인사말에 바로 반영된다.
  final String name;

  /// 수정 불가 (09-1 에서 읽기 전용).
  final String email;

  UserProfile copyWith({String? name}) =>
      UserProfile(name: name ?? this.name, email: email);

  Map<String, Object?> toJson() => {'name': name, 'email': email};

  factory UserProfile.fromJson(Map<String, Object?> json) => UserProfile(
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
      );
}
