import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../data/seed.dart';
import '../models/activity_item.dart';
import '../models/message.dart';
import '../models/notification_item.dart';
import '../models/robot.dart';
import '../models/saved_motion.dart';
import '../models/user_profile.dart';
import 'data_repository.dart';
import 'json_store.dart';

/// 로컬 JSON 파일 구현. 서버 없음 — 전부 기기 안에 남는다.
///
/// 상태 전체를 한 파일에 담는다. 전시용 규모(라이브러리 수십 개)에서는 부분 저장을
/// 쪼개는 것보다 통째로 쓰는 쪽이 어긋날 여지가 없다. 쓰기는 [JsonStore] 가
/// 임시 파일 + rename 으로 처리하고 연속 호출을 합친다.
class LocalRepository implements DataRepository {
  LocalRepository(this._store);

  /// 앱용 — documents 디렉터리.
  static Future<LocalRepository> forApp() async {
    final dir = await getApplicationDocumentsDirectory();
    return LocalRepository(JsonStore.inDirectory(dir, 'pure_state.json'));
  }

  /// 테스트용 — 임시 디렉터리.
  static LocalRepository inDirectory(Directory dir) =>
      LocalRepository(JsonStore.inDirectory(dir, 'pure_state.json'));

  final JsonStore _store;

  bool _ready = false;
  late UserProfile _profile;
  late Robot _robot;
  final List<Chat> _chats = [];
  final List<SavedMotion> _library = [];
  final List<NotificationItem> _notifications = [];
  final List<ActivityItem> _activity = [];
  final Map<String, Object?> _settings = {};

  @override
  bool get isReady => _ready;

  void _requireReady() {
    if (!_ready) throw StateError('DataRepository.init() 을 먼저 호출해야 합니다');
  }

  // ---------------------------------------------------------------- 로드

  @override
  Future<void> init() async {
    final json = await _store.read();
    if (json.isEmpty) {
      _applySeed();
      _ready = true;
      await _persistNow();
      return;
    }
    _applyJson(json);
    _ready = true;
  }

  void _applySeed() {
    _profile = kSeedProfile;
    _robot = kSeedRobot;
    _chats
      ..clear()
      ..addAll(const []);
    _library
      ..clear()
      ..addAll(seedLibrary());
    _notifications
      ..clear()
      ..addAll(seedNotifications());
    _activity
      ..clear()
      ..addAll(seedActivity());
    _settings
      ..clear()
      ..addAll({
        SettingKeys.onboarded: false,
        SettingKeys.forceDemoMode: false,
        SettingKeys.notificationSettings: kSeedNotificationSettings,
      });

    // 파일에서 읽을 때와 같은 순서가 되게. 이걸 빼면 첫 실행에서만 라이브러리 순서가
    // 다르게 보인다 — 전시에서 앱을 처음 켠 그 한 번이 하필 그 경우다.
    _sortChats();
    _sortLibrary();
  }

  void _applyJson(Map<String, Object?> json) {
    _profile = json['profile'] == null
        ? kSeedProfile
        : UserProfile.fromJson((json['profile']! as Map).cast<String, Object?>());
    _robot = json['robot'] == null
        ? kSeedRobot
        : Robot.fromJson((json['robot']! as Map).cast<String, Object?>());

    _chats
      ..clear()
      ..addAll(_list(json['chats'], Chat.fromJson));
    _library
      ..clear()
      ..addAll(_list(json['library'], SavedMotion.fromJson));
    _notifications
      ..clear()
      ..addAll(_list(json['notifications'], NotificationItem.fromJson));
    _activity
      ..clear()
      ..addAll(_list(json['activity'], ActivityItem.fromJson));
    _settings
      ..clear()
      ..addAll((json['settings'] as Map?)?.cast<String, Object?>() ?? const {});

    _sortChats();
    _sortLibrary();
  }

  static List<T> _list<T>(Object? raw, T Function(Map<String, Object?>) from) =>
      ((raw as List?) ?? const [])
          .whereType<Map>()
          .map((e) {
            try {
              return from(e.cast<String, Object?>());
            } catch (_) {
              return null;
            }
          })
          .whereType<T>()
          .toList();

  // ---------------------------------------------------------------- 저장

  Map<String, Object?> _snapshot() => {
        'version': 1,
        'profile': _profile.toJson(),
        'robot': _robot.toJson(),
        'chats': _chats.map((c) => c.toJson()).toList(),
        'library': _library.map((m) => m.toJson()).toList(),
        'notifications': _notifications.map((n) => n.toJson()).toList(),
        'activity': _activity.map((a) => a.toJson()).toList(),
        'settings': _settings,
      };

  void _persist() => _store.schedule(_snapshot());

  Future<void> _persistNow() {
    _store.schedule(_snapshot());
    return _store.flush();
  }

  @override
  Future<void> flush() => _store.flush();

  // ---------------------------------------------------------------- 프로필

  @override
  UserProfile get profile {
    _requireReady();
    return _profile;
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    _requireReady();
    _profile = profile;
    _persist();
  }

  // ---------------------------------------------------------------- 로봇

  @override
  Robot get robot {
    _requireReady();
    return _robot;
  }

  @override
  Future<void> saveRobot(Robot robot) async {
    _requireReady();
    _robot = robot;
    _persist();
  }

  // ---------------------------------------------------------------- 대화

  void _sortChats() => _chats.sort((a, b) => b.lastActiveAt.compareTo(a.lastActiveAt));

  @override
  List<Chat> get chats {
    _requireReady();
    return List.unmodifiable(_chats);
  }

  @override
  Chat? chatById(String id) {
    _requireReady();
    for (final c in _chats) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Future<void> upsertChat(Chat chat) async {
    _requireReady();
    final i = _chats.indexWhere((c) => c.id == chat.id);
    if (i >= 0) {
      _chats[i] = chat;
    } else {
      _chats.add(chat);
    }
    _sortChats();
    _persist();
  }

  @override
  Future<void> deleteChat(String id) async {
    _requireReady();
    _chats.removeWhere((c) => c.id == id);
    _persist();
  }

  // ---------------------------------------------------------------- 라이브러리

  void _sortLibrary() => _library.sort((a, b) => b.savedAt.compareTo(a.savedAt));

  @override
  List<SavedMotion> get library {
    _requireReady();
    return List.unmodifiable(_library);
  }

  @override
  SavedMotion? savedMotionById(String id) {
    _requireReady();
    for (final m in _library) {
      if (m.id == id) return m;
    }
    return null;
  }

  @override
  SavedMotion? autoMotionFor(Situation situation) {
    _requireReady();
    for (final m in _library) {
      if (m.kind == ReactionKind.auto && m.situation == situation) return m;
    }
    return null;
  }

  @override
  Future<void> upsertSavedMotion(SavedMotion motion) async {
    _requireReady();
    final i = _library.indexWhere((m) => m.id == motion.id);
    if (i >= 0) {
      _library[i] = motion;
    } else {
      _library.add(motion);
    }
    _sortLibrary();
    _persist();
  }

  @override
  Future<void> deleteSavedMotion(String id) async {
    _requireReady();
    _library.removeWhere((m) => m.id == id);
    _persist();
  }

  // ---------------------------------------------------------------- 알림 · 기록

  @override
  List<NotificationItem> get notifications {
    _requireReady();
    return List.unmodifiable(_notifications);
  }

  @override
  Future<void> saveNotifications(List<NotificationItem> items) async {
    _requireReady();
    _notifications
      ..clear()
      ..addAll(items);
    _persist();
  }

  @override
  List<ActivityItem> get activity {
    _requireReady();
    return List.unmodifiable(_activity);
  }

  @override
  Future<void> saveActivity(List<ActivityItem> items) async {
    _requireReady();
    _activity
      ..clear()
      ..addAll(items);
    _persist();
  }

  // ---------------------------------------------------------------- 설정

  @override
  T? setting<T>(String key) {
    _requireReady();
    final v = _settings[key];
    return v is T ? v : null;
  }

  @override
  Future<void> saveSetting(String key, Object? value) async {
    _requireReady();
    _settings[key] = value;
    _persist();
  }

  // ---------------------------------------------------------------- 전시 운영

  @override
  Future<void> resetDemoData() async {
    _applySeed();
    _ready = true;
    await _persistNow();
  }
}
