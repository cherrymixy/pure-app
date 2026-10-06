import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../data/seed.dart';
import '../data/strings.dart';
import '../providers/library_provider.dart';
import '../models/notification_item.dart';
import '../providers/notification_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/robot_provider.dart';
import '../repositories/data_repository.dart';
import '../services/thumbnail_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_icon.dart';
import '../widgets/pure_list.dart';
import '../widgets/pure_empty.dart';
import '../widgets/pure_sheet.dart';
import '../widgets/pure_toast.dart';
import '../widgets/pure_sidebar.dart';
import '../widgets/pure_top_bar.dart';

/// 09-1 마이. 하위 화면은 UI 그대로 껍데기이고 탭 반응만 한다 (PRD §2).
class MeScreen extends StatefulWidget {
  const MeScreen({super.key});

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  int _versionTaps = 0;
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);

  /// 버전을 5번 탭하면 전시 데이터를 초기화한다 (STEP 25 전시 설정).
  Future<void> _onVersionTap() async {
    final now = DateTime.now();
    _versionTaps =
        now.difference(_lastTap) > const Duration(seconds: 2) ? 1 : _versionTaps + 1;
    _lastTap = now;
    if (_versionTaps < 5) return;
    _versionTaps = 0;

    final ok = await showPureConfirm(
      context,
      title: S.devResetTitle,
      body: S.devResetBody,
      confirmLabel: S.actionReset,
    );
    if (!ok || !mounted) return;

    final repo = context.read<DataRepository>();
    final thumbnails = context.read<ThumbnailStore>();
    await repo.resetDemoData();
    // 참조가 사라진 썸네일을 치운다.
    await thumbnails.pruneExcept({
      for (final m in repo.library)
        if (m.spec.thumbnailPath != null) m.spec.thumbnailPath!,
    });
    if (!mounted) return;

    // 저장소를 통째로 갈아끼웠으니 화면들이 다시 읽게 한다.
    context.read<LibraryProvider>().refresh();
    context.read<ProfileProvider>().refresh();
    context.read<RobotProvider>().refresh();
    context.read<NotificationProvider>().refresh();

    showPureToast(context, S.toastDemoDataReset);
    Navigator.popUntil(context, (r) => r.isFirst);
  }

  Future<void> _editName() async {
    final profile = context.read<ProfileProvider>();
    final next = await showPureRename(
      context,
      title: S.meYourName,
      initial: profile.name,
      maxLength: ProfileProvider.nameMax,
    );

    if (next == null || !mounted) return;
    await profile.rename(next);
    if (!mounted) return;
    showPureToast(context, S.toastSaved);
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      drawer: const PureSidebar(),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PureMenuBar(title: S.meTitle),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x24,
                  12,
                  AppSpacing.x24,
                  AppSpacing.x24,
                ),
                children: [
                  _ProfileCard(
                    name: profile.name,
                    email: profile.email,
                    onEdit: _editName,
                  ),
                  const SizedBox(height: AppSpacing.x12),
                  PureCard(
                    rows: [
                      PureRow(
                        icon: AppIconName.bellRow,
                        label: S.meNotifications,
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.meNotifications,
                        ),
                      ),
                      PureRow(
                        icon: AppIconName.user,
                        label: S.meAccount,
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.meAccount),
                      ),
                    ],
                  ),
                  // 시안: 성격이 다른 묶음 사이는 더 띄운다.
                  const SizedBox(height: 48),
                  PureCard(
                    rows: [
                      PureRow(
                        icon: AppIconName.help,
                        label: S.meHelp,
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.meHelp),
                      ),
                      PureRow(
                        icon: AppIconName.fileDoc,
                        label: S.meTerms,
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.meTerms),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  // 다섯 번 두드리면 데모 데이터를 되돌린다 (전시 운영용).
                  GestureDetector(
                    onTap: _onVersionTap,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        fill(S.meVersion, {'version': kAppVersion}),
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 시안 `Profile` (`481:4412`) — 흰 카드 radius 24, 왼쪽 18 / 오른쪽 16 / 위아래 18,
/// 간격 14, 아바타 56, 오른쪽 Edit 알약.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.email,
    required this.onEdit,
  });

  final String name;
  final String email;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 18, AppSpacing.x16, 18),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.bgSurfaceMuted,
                shape: BoxShape.circle,
              ),
              child: const Center(child: AppIcon(AppIconName.person, size: 26)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.titleS,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: AppTextStyles.bodyS.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.x8),
            Material(
              color: AppColors.bgSurfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onEdit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: AppSpacing.x8,
                  ),
                  child: Text(S.meEdit, style: AppTextStyles.labelS),
                ),
              ),
            ),
          ],
        ),
      );
}

/// 09-2 알림 설정 — Figma `481:4589`. 토글은 로컬에 저장된다.
class MeNotificationsScreen extends StatelessWidget {
  const MeNotificationsScreen({super.key});

  /// 키 → (제목, 설명). 시안 넷 중 셋은 로봇, 하나는 PURE 소식이다.
  static const _robot = [
    ('motionPlayed', S.meNotifMotionReady, S.meNotifMotionReadyBody),
    ('robotOffline', S.meNotifRobotOffline, S.meNotifRobotOfflineBody),
    ('autoReactions', S.meNotifAutoReactions, S.meNotifAutoReactionsBody),
  ];

  @override
  Widget build(BuildContext context) {
    final notifications = context.watch<NotificationProvider>();

    PureRow toggle(String key, String title, String body) => PureRow(
          label: title,
          value: body,
          showChevron: false,
          onTap: () => notifications.setEnabled(key, !notifications.isEnabled(key)),
          trailing: Switch.adaptive(
            value: notifications.isEnabled(key),
            onChanged: (v) => notifications.setEnabled(key, v),
          ),
        );

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PureBackBar(title: S.meNotifications),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x24,
                  18,
                  AppSpacing.x24,
                  AppSpacing.x24,
                ),
                children: [
                  PureCard(
                    rows: [
                      for (final (key, title, body) in _robot)
                        toggle(key, title, body),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x24),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.x8),
                    child: Text(
                      S.meNotifFromPure,
                      style: AppTextStyles.bodyS.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  PureCard(
                    rows: [
                      toggle('tips', S.meNotifTips, S.meNotifTipsBody),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 09-3 계정 — Figma `481:4679`. Log out · Delete 는 확인만 하고 닫는다 (PRD §2).
class MeAccountScreen extends StatelessWidget {
  const MeAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PureBackBar(title: S.meAccount),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x24,
                  18,
                  AppSpacing.x24,
                  AppSpacing.x24,
                ),
                children: [
                  PureCard(
                    rows: [
                      PureRow(
                        icon: AppIconName.fileDoc,
                        label: S.meAccountEmail,
                        value: profile.email,
                        showChevron: false,
                        onTap: () {},
                      ),
                      PureRow(
                        icon: AppIconName.user,
                        label: S.meAccountSignedIn,
                        trailingText: S.meAccountApple,
                        showChevron: false,
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.x16),
                  PureCard(
                    rows: [
                      PureRow(
                        label: S.meAccountChangePassword,
                        value: S.meAccountChangePasswordBody,
                        // 더미 — 전시 계정은 Apple 로그인뿐이다.
                        onTap: () =>
                            showPureToast(context, S.meAccountChangePassword),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  PureCard(
                    rows: [
                      PureRow(
                        label: S.meLogOut,
                        showChevron: false,
                        onTap: () => showPureConfirm(
                          context,
                          title: S.meLogOutTitle,
                          body: S.meLogOutBody,
                          confirmLabel: S.meLogOut,
                        ),
                      ),
                      PureRow(
                        label: S.meDeleteAccount,
                        danger: true,
                        showChevron: false,
                        onTap: () => showPureConfirm(
                          context,
                          title: S.meDeleteTitle,
                          body: S.meDeleteBody,
                          confirmLabel: S.meDeleteAccount,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 09-4 Help & FAQ — 아코디언.
class MeHelpScreen extends StatelessWidget {
  const MeHelpScreen({super.key});

  static const _faq = {
    'How does Purebot make a motion?':
        'Tell it what happened, or show it a short video. It picks movements that fit '
            'the moment and plays them right away.',
    'What is a motion signature?':
        'Three answers that set how Purebot moves — how lively it is, how it comes to '
            'you, and how big its movements are.',
    'Why does it sometimes say demo?':
        'When there is no network, Purebot uses motions it already knows so it never '
            'stops responding.',
    'Where are my motions saved?':
        'On this phone only. Nothing is uploaded except the words and frames you send '
            'when making a motion.',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bgCanvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PureBackBar(title: S.meHelp),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x24,
                    12,
                    AppSpacing.x24,
                    AppSpacing.x24,
                  ),
                  children: [
                    for (final e in _faq.entries)
                      Theme(
                        // 카드 안이라 기본 구분선은 지운다.
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(
                            e.key,
                            style: AppTextStyles.bodyM.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Text(
                                e.value,
                                style: AppTextStyles.bodyS.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 20 / 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// 09-4 Terms & Privacy — 정적 문서.
class MeTermsScreen extends StatelessWidget {
  const MeTermsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bgCanvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PureBackBar(title: S.meTerms),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x24,
                    12,
                    AppSpacing.x24,
                    AppSpacing.x24,
                  ),
                  child: Text(
                    'PURE is a graduation-exhibition prototype.\n\n'
                    'Everything you make stays on this phone. The only thing that '
                    'leaves the device is the text you type and the frames taken from '
                    'a video you attach, which are sent to generate a motion and are '
                    'not stored.\n\n'
                    'There is no account, no sync, and no analytics.',
                    style: AppTextStyles.bodyS.copyWith(
                      color: AppColors.textSecondary,
                      height: 22 / 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

/// 10-1 알림 — Figma `481:5234`.
///
/// 시안 값: 뒤로 + 제목 + "Mark all read" / 날짜 그룹 / 항목 카드(radius 18,
/// 패딩 14, 간격 12) · 아이콘 원 40 · 제목 15 Medium + 시각 + 안 읽음 점 7.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  /// 어디로 가는 알림인지에 따라 아이콘이 달라진다 (시안 10-1).
  static (AppIconName, bool) _iconFor(String? target) => switch (target) {
        'library' => (AppIconName.zap, false),
        'robot' => (AppIconName.download, false),
        _ => (AppIconName.check, false),
      };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final items = provider.items;

    final now = DateTime.now();
    final groups = <String, List<NotificationItem>>{};
    for (final n in items) {
      final day = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
      final today = DateTime(now.year, now.month, now.day);
      final key = today.difference(day).inDays <= 0
          ? S.chatHistoryToday
          : S.notificationsEarlier;
      groups.putIfAbsent(key, () => []).add(n);
    }

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PureBackBar(
              title: S.notificationsTitle,
              trailing: items.isEmpty
                  ? null
                  : GestureDetector(
                      onTap: provider.markAllRead,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        S.notificationsMarkAllRead,
                        style: AppTextStyles.labelM.copyWith(
                          color: AppColors.textBrand,
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const PureEmptyState(
                      icon: AppIconName.bellRow,
                      title: S.emptyNotifications,
                      body: 'New things show up here.',
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.x24,
                        12,
                        AppSpacing.x24,
                        AppSpacing.x24,
                      ),
                      children: [
                        for (final entry in groups.entries) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.x8),
                            child: Text(
                              entry.key,
                              style: AppTextStyles.bodyS.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          for (final n in entry.value) ...[
                            _NotiCard(
                              item: n,
                              icon: _iconFor(n.target).$1,
                              onTap: () {
                                provider.markRead(n.id);
                                Navigator.pushNamed(
                                  context,
                                  switch (n.target) {
                                    'library' => AppRoutes.library,
                                    'robot' => AppRoutes.robot,
                                    _ => AppRoutes.home,
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: AppSpacing.x8),
                          ],
                          const SizedBox(height: 6),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 시안 `Noti/…` (`481:5241`) — 흰 카드 radius 18, 패딩 14, 간격 12.
class _NotiCard extends StatelessWidget {
  const _NotiCard({
    required this.item,
    required this.icon,
    required this.onTap,
  });

  final NotificationItem item;
  final AppIconName icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(child: AppIcon(icon, size: 18)),
                ),
                const SizedBox(width: AppSpacing.x12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: AppTextStyles.bodyM.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _ago(item.createdAt),
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          if (!item.read) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AppColors.bgBrand,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.body,
                        style: AppTextStyles.bodyS.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  /// 시안은 "2m" / "1h" / "Yesterday" / "Oct 1" 꼴을 섞어 쓴다.
  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays == 1) return S.activityYesterday;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[t.month - 1]} ${t.day}';
  }
}
