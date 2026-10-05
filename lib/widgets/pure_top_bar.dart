import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../providers/notification_provider.dart';
import '../theme/app_colors.dart';
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
