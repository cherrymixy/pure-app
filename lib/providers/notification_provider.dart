import 'package:flutter/foundation.dart';

import '../models/notification_item.dart';
import '../repositories/data_repository.dart';

/// 알림 목록 (10-1) 과 09-2 토글. 둘 다 로컬에만 남는다 — 실제 푸시는 범위 밖.
class NotificationProvider extends ChangeNotifier {
  NotificationProvider(this._repo);

  final DataRepository _repo;

  List<NotificationItem> get items => _repo.notifications;
  /// 저장소가 통째로 바뀐 뒤(전시 데이터 초기화) 화면을 다시 그리게 한다.
  void refresh() => notifyListeners();

  /// 상단 종에 점을 띄울지.
  bool get hasUnread => items.any((n) => !n.read);

  int get unreadCount => items.where((n) => !n.read).length;

  Future<void> markRead(String id) async {
    final next = items
        .map((n) => n.id == id ? n.copyWith(read: true) : n)
        .toList();
    await _repo.saveNotifications(next);
    notifyListeners();
  }

  Future<void> markAllRead() async {
    await _repo.saveNotifications(items.map((n) => n.copyWith(read: true)).toList());
    notifyListeners();
  }

  // ---------------------------------------------------------------- 09-2 토글

  Map<String, bool> get settings {
    final raw = _repo.setting<Map<String, Object?>>(SettingKeys.notificationSettings);
    return {
      for (final e in (raw ?? const {}).entries)
        if (e.value is bool) e.key: e.value! as bool,
    };
  }

  bool isEnabled(String key) => settings[key] ?? false;

  Future<void> setEnabled(String key, bool value) async {
    final next = {...settings, key: value};
    await _repo.saveSetting(SettingKeys.notificationSettings, next);
    notifyListeners();
  }
}
