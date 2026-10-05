import '../models/activity_item.dart';
import '../models/message.dart';
import '../models/notification_item.dart';
import '../models/robot.dart';
import '../models/saved_motion.dart';
import '../models/user_profile.dart';

/// 설정 키. 문자열을 흩뿌리지 않는다.
abstract final class SettingKeys {
  /// 05 모션 시그니처를 한 번이라도 마쳤는가. "Reset demo data" 가 같이 되돌린다.
  static const onboarded = 'onboarded';

  /// 강제 데모 모드 (로봇 이름 5번 탭).
  static const forceDemoMode = 'forceDemoMode';

  /// 09-2 알림 토글.
  static const notificationSettings = 'notificationSettings';

  /// 라이브러리 필터 선택 유지 (All / Auto / Manual).
  static const libraryFilter = 'libraryFilter';
}

/// 데이터 접근의 유일한 문.
///
/// 지금 구현은 [LocalRepository] 하나(로컬 JSON)지만, 나중에 서버로 갈아끼울 수 있게
/// 인터페이스를 둔다. Provider 는 이 타입만 알고 구현을 모른다.
///
/// 읽기는 동기(이미 메모리에 올라와 있다), 쓰기는 비동기다. [init] 이 끝나기 전에
/// 읽으면 [StateError].
abstract class DataRepository {
  /// 파일을 읽고 첫 실행이면 시드를 심는다. 앱 시작 시 한 번.
  Future<void> init();

  bool get isReady;

  // ---------------------------------------------------------------- 프로필
  UserProfile get profile;
  Future<void> saveProfile(UserProfile profile);

  // ---------------------------------------------------------------- 로봇 · 시그니처
  Robot get robot;
  Future<void> saveRobot(Robot robot);

  // ---------------------------------------------------------------- 대화
  /// 최근 활동 순.
  List<Chat> get chats;
  Chat? chatById(String id);
  Future<void> upsertChat(Chat chat);
  Future<void> deleteChat(String id);

  // ---------------------------------------------------------------- 라이브러리
  /// 저장 시각 역순.
  List<SavedMotion> get library;
  SavedMotion? savedMotionById(String id);

  /// 같은 상황에 자동 재생으로 등록된 모션. 저장 시 경고에 쓴다.
  SavedMotion? autoMotionFor(Situation situation);

  Future<void> upsertSavedMotion(SavedMotion motion);
  Future<void> deleteSavedMotion(String id);

  // ---------------------------------------------------------------- 알림 · 기록
  List<NotificationItem> get notifications;
  Future<void> saveNotifications(List<NotificationItem> items);

  List<ActivityItem> get activity;
  Future<void> saveActivity(List<ActivityItem> items);

  // ---------------------------------------------------------------- 설정
  T? setting<T>(String key);
  Future<void> saveSetting(String key, Object? value);

  // ---------------------------------------------------------------- 전시 운영
  /// 모든 것을 시드 상태로 되돌린다 (마이 → Version 5번 탭).
  /// 첫 실행 플래그도 함께 지워서 다음 관람객에게 05 부터 보여줄 수 있다.
  Future<void> resetDemoData();

  /// 예약된 저장을 즉시 끝낸다. 테스트와 앱 종료용.
  Future<void> flush();
}
