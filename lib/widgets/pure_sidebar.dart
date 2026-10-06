import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../data/strings.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/library_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/robot_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_icon.dart';
import 'demo_mode_toggle.dart';
import 'pure_toast.dart';

/// M-1 사이드바 — Figma `Sidebar` (`457:4269`, 인스턴스 `483:19272`).
///
/// 시안: 폭 316 · `bg/canvas` · 오른쪽 모서리만 radius 28 · `PURE/Shadow/Float`
/// · 패딩 상 64 / 하 40 / 좌우 20 · 블록 간격 20.
///
/// 구성: 프로필 → `+ New motion`(검정 버튼 56) → 메뉴 5 → 구분선 → 최근 대화 → Me / Settings.
class PureSidebar extends StatelessWidget {
  const PureSidebar({super.key});

  static const double width = 316;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: width,
      backgroundColor: AppColors.bgCanvas,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(AppRadius.xl),
          bottomRight: Radius.circular(AppRadius.xl),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x20,
          64,
          AppSpacing.x20,
          AppSpacing.x40,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Profile(),
            const SizedBox(height: AppSpacing.x20),
            const _NewMotionButton(),
            const SizedBox(height: AppSpacing.x20),
            const _Menu(),
            const SizedBox(height: AppSpacing.x20),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.x20),
            const Expanded(child: _Recent()),
            _MenuItem(
              icon: AppIconName.navSettings,
              label: S.menuMeSettings,
              onTap: () => _go(context, AppRoutes.me),
            ),
          ],
        ),
      ),
    );
  }

  static void _go(BuildContext context, String route, {bool replace = false}) {
    Navigator.pop(context);
    if (replace) {
      Navigator.pushReplacementNamed(context, route);
    } else {
      Navigator.pushNamed(context, route);
    }
  }
}

/// 프로필 — 아바타 44 + 이름 Title/S + 로봇 상태 한 줄.
///
/// 로봇 이름을 5번 두드리면 데모 모드가 토글된다 (PRD §6-7 숨은 토글).
/// 전시 중에 인터넷이나 키가 말을 안 들을 때 쓰는 비상구다.
class _Profile extends StatefulWidget {
  const _Profile();

  @override
  State<_Profile> createState() => _ProfileState();
}

class _ProfileState extends State<_Profile> {
  int _taps = 0;
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _onStatusTap() async {
    final now = DateTime.now();
    // 간격이 뜨면 처음부터. 실수로 쌓이는 걸 막는다.
    _taps = now.difference(_lastTap) > const Duration(seconds: 2) ? 1 : _taps + 1;
    _lastTap = now;
    if (_taps < 5) return;
    _taps = 0;

    final toggle = DemoModeToggle.of(context);
    if (toggle == null) return;
    final on = await toggle();
    if (!mounted) return;
    showPureToast(context, on ? S.homeDemoModeOn : S.homeDemoModeOff);
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final robot = context.watch<RobotProvider>();

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: AppColors.bgSurfaceMuted,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: AppIcon(AppIconName.person, size: 22),
          ),
        ),
        const SizedBox(width: AppSpacing.x12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                profile.name,
                style: AppTextStyles.titleS,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: _onStatusTap,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    const AppIcon(AppIconName.dot, size: 7),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        fill(S.menuRobotLine, {
                          'name': robot.robot.name,
                          'status': S.robotConnected,
                        }),
                        style: AppTextStyles.bodyS.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 시안 `Button` Inverse / L — 높이 56, radius full, 검정.
class _NewMotionButton extends StatelessWidget {
  const _NewMotionButton();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.bgInverse,
            foregroundColor: AppColors.textOnInverse,
            shape: const StadiumBorder(),
            textStyle: AppTextStyles.bodyLStrong,
          ),
          onPressed: () => PureSidebar._go(context, AppRoutes.homeNew, replace: true),
          child: const Text(S.menuNewMotionButton),
        ),
      );
}

class _Menu extends StatelessWidget {
  const _Menu();

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context)?.settings.name;
    final unread = context.watch<NotificationProvider>().unreadCount;

    return Column(
      children: [
        _MenuItem(
          icon: AppIconName.navHome,
          label: S.menuHome,
          selected: route == AppRoutes.home,
          onTap: () => PureSidebar._go(context, AppRoutes.home, replace: true),
        ),
        _MenuItem(
          icon: AppIconName.navLibrary,
          label: S.menuLibrary,
          onTap: () => PureSidebar._go(context, AppRoutes.library),
        ),
        _MenuItem(
          icon: AppIconName.navRobot,
          label: S.menuRobot,
          onTap: () => PureSidebar._go(context, AppRoutes.robot),
        ),
        _MenuItem(
          icon: AppIconName.navActivity,
          label: S.menuActivityHistory,
          onTap: () => PureSidebar._go(context, AppRoutes.robotActivity),
        ),
        _MenuItem(
          icon: AppIconName.navNotifications,
          label: S.menuNotifications,
          badge: unread > 0 ? '$unread' : null,
          onTap: () => PureSidebar._go(context, AppRoutes.notifications),
        ),
      ],
    );
  }
}

/// 시안 `Menu Item` (`457:4268`) — 패딩 12 · 간격 12 · radius 14 · 아이콘 24.
/// Selected 면 `bg/surface-muted` 바탕에 라벨이 Medium 이 된다.
class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.badge,
  });

  final AppIconName icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  /// 숫자 또는 "New".
  final String? badge;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: selected ? AppColors.bgSurfaceMuted : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x12),
              child: Row(
                children: [
                  AppIcon(icon, size: 24),
                  const SizedBox(width: AppSpacing.x12),
                  Expanded(
                    child: Text(
                      label,
                      style: selected ? AppTextStyles.bodyLStrong : AppTextStyles.bodyL,
                    ),
                  ),
                  if (badge != null) _CountBadge(text: badge!),
                ],
              ),
            ),
          ),
        ),
      );
}

/// 시안 `Count Badge` (`452:4235`) — sage/300 바탕, 흰 글씨 Caption, 좌우 8 · 상하 2.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.sage300,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          text,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textOnInverse,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
}

/// 최근 대화. 머리말 "Recent" / "See all" + 대화 세 줄.
class _Recent extends StatelessWidget {
  const _Recent();

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final library = context.watch<LibraryProvider>();
    final chats = chat.chats.where((c) => c.messages.isNotEmpty).take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x12,
            0,
            AppSpacing.x12,
            6,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(S.menuRecent,
                  style: AppTextStyles.labelS
                      .copyWith(color: AppColors.textSecondary)),
              GestureDetector(
                onTap: () => PureSidebar._go(context, AppRoutes.chats),
                child: Text(S.menuSeeAll,
                    style:
                        AppTextStyles.labelS.copyWith(color: AppColors.textBrand)),
              ),
            ],
          ),
        ),
        for (final c in chats)
          _ChatItem(
            chat: c,
            savedCount: library.all.where((m) => m.chatId == c.id).length,
          ),
      ],
    );
  }
}

class _ChatItem extends StatelessWidget {
  const _ChatItem({required this.chat, required this.savedCount});

  final Chat chat;
  final int savedCount;

  @override
  Widget build(BuildContext context) {
    final title = chat.messages
            .firstWhere(
              (m) => m.sender == Sender.user && (m.text ?? '').isNotEmpty,
              orElse: () => chat.messages.first,
            )
            .text ??
        S.menuUntitled;

    final now = DateTime.now();
    final sameDay = chat.lastActiveAt.year == now.year &&
        chat.lastActiveAt.month == now.month &&
        chat.lastActiveAt.day == now.day;

    return InkWell(
      onTap: () async {
        await context.read<ChatProvider>().open(chat.id);
        if (!context.mounted) return;
        PureSidebar._go(context, AppRoutes.home, replace: true);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x12,
          vertical: AppSpacing.x8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: AppTextStyles.bodyM,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              [
                sameDay ? 'Today' : 'Earlier',
                if (savedCount > 0) 'Saved',
              ].join(' / '),
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
