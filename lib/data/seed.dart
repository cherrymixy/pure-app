/// 첫 실행 시드 — 전시용 더미 데이터.
///
/// 라이브러리가 비어 있으면 07 화면에서 보여줄 게 없다. 숨은 "Reset demo data"
/// (마이 → Version 5번 탭)가 이 상태로 되돌린다. 첫 실행 플래그도 같이 초기화해서
/// 다음 관람객에게 05 시그니처부터 보여줄 수 있다 (부록 D 결정).
library;

import '../models/activity_item.dart';
import '../models/motion_signature.dart';
import '../models/motion_spec.dart';
import '../models/notification_item.dart';
import '../models/robot.dart';
import '../models/saved_motion.dart';
import '../models/user_profile.dart';
import 'demo_recipes.dart';

/// 시드 시각의 기준. 상대 시간("2 hours ago")은 이 값이 아니라 now 로 계산한다.
final DateTime _seedNow = DateTime(2026, 10, 6, 9);

const UserProfile kSeedProfile = UserProfile(
  name: 'SeungA',
  email: 'seunga@purebot.app',
);

const Robot kSeedRobot = Robot(
  id: 'robot.purebot',
  name: 'Purebot',
  model: 'Purebot Arm',
  signature: MotionSignature.seed,
);

// ------------------------------------------------------------------ 라이브러리

MotionSpec _specFromDemo(DemoRecipe d, {required String id}) => MotionSpec(
      id: id,
      name: d.name,
      face: d.face,
      mode: SpecMode.recipe,
      recipe: d.recipe,
      reasoning: d.reasoning,
      signatureSnapshot: MotionSignature.seed,
    );

/// 라이브러리 샘플 3개 (PRD §5).
List<SavedMotion> seedLibrary() => [
      SavedMotion(
        id: 'saved.welcomeHome',
        name: 'Welcome home',
        spec: _specFromDemo(demoRecipeForChip('cameHome'), id: 'spec.welcomeHome'),
        kind: ReactionKind.auto,
        situation: Situation.comesHome,
        savedAt: _seedNow.subtract(const Duration(days: 3)),
        chatId: 'chat.seed.welcomeHome',
      ),
      SavedMotion(
        id: 'saved.gentleCheerUp',
        name: 'Gentle cheer-up',
        spec: _specFromDemo(demoRecipeForChip('tired'), id: 'spec.gentleCheerUp'),
        kind: ReactionKind.auto,
        situation: Situation.tired,
        savedAt: _seedNow.subtract(const Duration(days: 2)),
        chatId: 'chat.seed.gentleCheerUp',
        editCount: 1,
      ),
      SavedMotion(
        id: 'saved.startledHop',
        name: 'Startled hop',
        spec: _specFromDemo(demoRecipeForChip('startled'), id: 'spec.startledHop'),
        kind: ReactionKind.manual,
        situation: Situation.onlyWhenAsked,
        savedAt: _seedNow.subtract(const Duration(days: 1)),
        chatId: 'chat.seed.startledHop',
      ),
    ];

// ------------------------------------------------------------------ 알림 (10-1)

List<NotificationItem> seedNotifications() => [
      NotificationItem(
        id: 'noti.1',
        title: 'Welcome home played',
        body: 'Purebot greeted someone at the door.',
        createdAt: _seedNow.subtract(const Duration(hours: 2)),
        target: 'library',
      ),
      NotificationItem(
        id: 'noti.2',
        title: 'Firmware 1.3.0 is ready',
        body: 'Update Purebot when you have a moment.',
        createdAt: _seedNow.subtract(const Duration(days: 1)),
        target: 'robot',
      ),
      NotificationItem(
        id: 'noti.3',
        title: 'Motion signature saved',
        body: 'Purebot now moves quick and bouncy.',
        createdAt: _seedNow.subtract(const Duration(days: 2)),
        read: true,
        target: 'robot',
      ),
    ];

// ------------------------------------------------------------------ 행동 기록 (08-5)

List<ActivityItem> seedActivity() => [
      ActivityItem(
        id: 'act.1',
        motionName: 'Welcome home',
        trigger: ActivityTrigger.auto,
        situationLabel: 'When someone comes home',
        at: _seedNow.subtract(const Duration(hours: 2)),
      ),
      ActivityItem(
        id: 'act.2',
        motionName: 'Startled hop',
        trigger: ActivityTrigger.byYou,
        at: _seedNow.subtract(const Duration(hours: 5)),
      ),
      ActivityItem(
        id: 'act.3',
        motionName: 'Gentle cheer-up',
        trigger: ActivityTrigger.auto,
        situationLabel: "When I say I'm tired",
        at: _seedNow.subtract(const Duration(days: 1)),
      ),
      ActivityItem(
        id: 'act.4',
        motionName: 'Welcome home',
        trigger: ActivityTrigger.auto,
        situationLabel: 'When someone comes home',
        at: _seedNow.subtract(const Duration(days: 1, hours: 9)),
      ),
    ];

// ------------------------------------------------------------------ 08 로봇 탭 더미

/// 08-1 에 그대로 보여줄 값들 (PRD §4).
class RobotSeedInfo {
  const RobotSeedInfo();

  String get connection => 'Connected';
  String get network => 'Home_5G';
  String get power => 'Plugged in';
  String get firmwareCurrent => '1.2.4';
  String get firmwareAvailable => '1.3.0';

  /// 성격 모드 (더미 — 탭은 되지만 값만 바뀐다).
  List<String> get personalityModes => const ['Family', 'Partner', 'Focus'];
  String get activeMode => 'Family';

  /// 08-3 로봇 목록.
  List<String> get myRobots => const ['Purebot · Purebot Arm'];
}

const RobotSeedInfo kRobotSeedInfo = RobotSeedInfo();

// ------------------------------------------------------------------ 설정 기본값

/// 09-2 알림 토글 기본값. 로컬에만 저장된다.
const Map<String, bool> kSeedNotificationSettings = {
  'motionPlayed': true,
  'firmware': true,
  'tips': false,
};

/// 앱 버전 (09-1 표시).
const String kAppVersion = '1.0.0';
