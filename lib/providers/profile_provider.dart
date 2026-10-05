import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import '../repositories/data_repository.dart';

/// 프로필 — 이름을 바꾸면 홈 인사말이 바로 따라온다 (09-1a).
class ProfileProvider extends ChangeNotifier {
  ProfileProvider(this._repo);

  final DataRepository _repo;

  UserProfile get profile => _repo.profile;
  String get name => profile.name;
  String get email => profile.email;

  /// 이름 길이 제한 (09-1a).
  static const int nameMin = 1;
  static const int nameMax = 20;

  /// 저장 버튼을 켤 수 있는가. 같거나 비어 있으면 끈다.
  bool canSaveName(String candidate) {
    final t = candidate.trim();
    return t.length >= nameMin && t.length <= nameMax && t != profile.name;
  }

  Future<bool> rename(String candidate) async {
    if (!canSaveName(candidate)) return false;
    await _repo.saveProfile(profile.copyWith(name: candidate.trim()));
    notifyListeners();
    return true;
  }
}
