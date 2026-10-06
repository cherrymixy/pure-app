import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../providers/notification_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_icon.dart';

/// 홈 상단바 — Figma `480:2069`.
///
/// 시안 값: 좌우 여백 15.34, 상단 62.4(상태바 51 아래 ≈ 11), 양끝 정렬.
/// 왼쪽 햄버거 44×44(막대 20·20·14, 두께 2, 간격 7), 오른쪽 종 24.55.
///
/// **로봇 상태 텍스트는 시안에 없다.** PRD §4 는 상단에 "Purebot · PUREBOT /
/// LIVELY, BOUNCY" 를 두라고 했지만 최신 UI 페이지의 홈에는 햄버거와 종뿐이다.
class PureTopBar extends StatelessWidget {
  const PureTopBar({super.key, this.onMenu});

  /// 없으면 Scaffold 의 drawer 를 연다.
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15.34, 11, 15.34, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _MenuButton(onTap: onMenu ?? () => Scaffold.of(context).openDrawer()),
          const _BellButton(),
        ],
      ),
    );
  }
}

/// 햄버거 + 제목 상단바 — Figma `Top Bar / Main` (`453:4221`).
///
/// 시안 07-1 값: 햄버거 44 가 왼쪽 14, 제목이 62 에서 시작(= 14 + 44 + 4),
/// 오른쪽 버튼은 여백 24. 제목은 `PURE/Title/L` (30/38 Medium).
class PureMenuBar extends StatelessWidget {
  const PureMenuBar({super.key, required this.title, this.trailing});

  final String title;

  /// 오른쪽에 붙는 둥근 버튼 (라이브러리의 돋보기 등).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, AppSpacing.x24, 0),
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              _MenuButton(onTap: () => Scaffold.of(context).openDrawer()),
              const SizedBox(width: AppSpacing.x4),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.titleL,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      );
}

/// 시안 `Button/search` 같은 흰 원형 버튼 (44, radius 22).
class PureRoundButton extends StatelessWidget {
  const PureRoundButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.iconSize = 18,
  });

  final AppIconName icon;
  final VoidCallback onTap;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.bgSurface,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(child: AppIcon(icon, size: iconSize)),
          ),
        ),
      );
}

/// 뒤로가기 상단바 — Figma `Top Bar / Back` (`453:4186`).
///
/// 시안 값: 높이 56 · 왼쪽 패딩 12 · 오른쪽 16 · 버튼 44 안에 아이콘 24.
/// 오른쪽은 비워 둔다 (시안에 아무것도 없다).
class PureBackBar extends StatelessWidget {
  const PureBackBar({super.key, this.onBack, this.trailing});

  /// 없으면 그냥 pop.
  final VoidCallback? onBack;

  /// 시안에는 없지만 화면이 필요로 하면 오른쪽에 붙인다.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: AppSpacing.x16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkResponse(
                onTap: onBack ?? () => Navigator.maybePop(context),
                radius: 24,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(child: AppIcon(AppIconName.arrowBack, size: 24)),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      );
}

/// 햄버거. 시안이 도형으로 그려 둬서 아이콘 대신 그대로 옮긴다.
class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            children: const [
              _Bar(top: 14, width: 20),
              _Bar(top: 21, width: 20),
              _Bar(top: 28, width: 14),
            ],
          ),
        ),
      );
}

class _Bar extends StatelessWidget {
  const _Bar({required this.top, required this.width});
  final double top;
  final double width;

  @override
  Widget build(BuildContext context) => Positioned(
        left: 12,
        top: top,
        child: Container(
          width: width,
          height: 2,
          decoration: BoxDecoration(
            color: AppColors.bgInverse,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      );
}

class _BellButton extends StatelessWidget {
  const _BellButton();

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<NotificationProvider>().hasUnread;
    return InkResponse(
      onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
      radius: 24,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const AppIcon(AppIconName.bell, size: 24.55),
            if (unread)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.statusLive,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
