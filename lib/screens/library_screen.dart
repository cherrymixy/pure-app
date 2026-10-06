import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../data/situations.dart';
import '../data/strings.dart';
import '../models/saved_motion.dart';
import '../providers/library_provider.dart';
import '../sim/sim_controller.dart';
import '../sim/sim_host.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_icon.dart';
import '../widgets/gray_box.dart';
import '../widgets/pure_chip.dart';
import '../widgets/pure_sidebar.dart';
import '../widgets/pure_top_bar.dart';

/// 07-1 라이브러리 — Figma `481:2725`.
///
/// 시안 값: 햄버거 + 제목 + 돋보기(44 흰 원) / 필터 칩 세 개(간격 8) /
/// 목록은 좌우 24, 항목 간격 10, 그룹 사이 8 더.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  /// 개발용 — 첫 모션의 상세를 바로 연다. 시뮬레이터를 탭할 수 없어서 둔다.
  ///   ./scripts/dev.sh install --dart-define=START_ROUTE=/library \
  ///       --dart-define=DEV_OPEN_DETAIL=true
  static const bool _devOpenDetail = bool.fromEnvironment('DEV_OPEN_DETAIL');

  /// 지금 카드 자리에서 재생 중인 모션.
  String? _playingId;
  StreamSubscription<SimEvent>? _sub;

  SimController get _sim => SimHost.controllerOf(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sub = _sim.events.listen((e) {
        if (e is SimEnded && mounted) setState(() => _playingId = null);
      });
      if (_devOpenDetail) {
        final first = context.read<LibraryProvider>().visible.firstOrNull;
        if (first != null) {
          Navigator.pushNamed(
            context,
            AppRoutes.motionDetail,
            arguments: first.id,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _togglePlay(SavedMotion motion) async {
    if (_playingId == motion.id) {
      await _sim.stop();
      if (mounted) setState(() => _playingId = null);
      return;
    }
    setState(() => _playingId = motion.id);
    try {
      await _sim.playRecipe(motion.spec.recipe.toJson());
      await _sim.setFace(motion.spec.face);
    } catch (_) {
      if (mounted) setState(() => _playingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      drawer: const PureSidebar(),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PureMenuBar(
              title: S.libraryTitle,
              trailing: PureRoundButton(
                icon: AppIconName.search,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.librarySearch),
              ),
            ),
            if (library.isEmpty)
              Expanded(
                child: GrayEmptyState(
                  title: S.emptyLibraryTitle,
                  body: S.emptyLibraryBody,
                  actionLabel: S.emptyLibraryAction,
                  onAction: () => Navigator.popUntil(context, (r) => r.isFirst),
                ),
              )
            else ...[
              // 시안: 상단바 아래 17, 칩 묶음 높이 43, 그 아래 11.
              const SizedBox(height: 17),
              _FilterBar(value: library.filter, onChanged: library.setFilter),
              const SizedBox(height: 11),
              Expanded(child: _list(library)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _list(LibraryProvider library) {
    final auto = library.autoGroup;
    final others = library.others;

    if (auto.isEmpty && others.isEmpty) {
      return const GrayEmptyState(
        title: S.emptySearchTitle,
        body: S.emptySearchBody,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x24,
        0,
        AppSpacing.x24,
        AppSpacing.x24,
      ),
      children: [
        if (auto.isNotEmpty) ...[
          const _GroupLabel(S.libraryAutoGroup),
          for (final m in auto) ...[const SizedBox(height: 10), _card(m)],
        ],
        if (others.isNotEmpty) ...[
          // 시안: 그룹 사이에 8 이 더 들어간다.
          SizedBox(height: auto.isEmpty ? 0 : 18),
          const _GroupLabel(S.saveSheetOnlyWhenIAsk),
          for (final m in others) ...[const SizedBox(height: 10), _card(m)],
        ],
      ],
    );
  }

  Widget _card(SavedMotion motion) => MotionCard(
        motion: motion,
        playing: _playingId == motion.id,
        onPlay: () => _togglePlay(motion),
        onTap: () => Navigator.pushNamed(
          context,
          AppRoutes.motionDetail,
          arguments: motion.id,
        ),
      );
}

/// 그룹 머리말 — `PURE/Body/S`, `text/secondary`.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppTextStyles.bodyS.copyWith(color: AppColors.textSecondary),
      );
}

/// 07-1 목록 카드 — 시안 `Motion/…` (`481:2740`).
///
/// 시안 값: 흰 바탕 radius 20 · 왼쪽 12 / 오른쪽 14 / 위아래 12 · 간격 14 ·
/// 썸네일 60(radius 14) · 오른쪽 재생 버튼 36(`bg/surface-muted`).
///
/// 재생 중이면 썸네일 자리에서 시뮬레이터가 돈다.
class MotionCard extends StatelessWidget {
  const MotionCard({
    super.key,
    required this.motion,
    required this.playing,
    required this.onPlay,
    required this.onTap,
    this.nameSpan,
  });

  final SavedMotion motion;
  final bool playing;
  final VoidCallback onPlay;
  final VoidCallback onTap;

  /// 검색에서 일치 글자를 강조할 때 쓴다.
  final InlineSpan? nameSpan;

  @override
  Widget build(BuildContext context) {
    final isAuto = motion.kind == ReactionKind.auto;
    final situation = motion.situation;

    // 시안은 자동과 수동 두 가지만 보여 준다. askFirst 는 밀려난 상태라 수동처럼
    // 보이면 안 되므로 기존 문구를 그대로 쓴다 (reactionLabel 주석 참고).
    final String line;
    if (isAuto && situation != null) {
      line = whenLabel(situation);
    } else if (motion.kind == ReactionKind.manual) {
      line = S.libraryManualLine;
    } else {
      line = reactionLabel(motion.kind, situation);
    }

    return Material(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          child: Row(
            children: [
              _Thumb(motion: motion, playing: playing),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    nameSpan == null
                        ? Text(
                            motion.name,
                            style: AppTextStyles.bodyLStrong,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : Text.rich(
                            nameSpan!,
                            style: AppTextStyles.bodyLStrong,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    const SizedBox(height: AppSpacing.x4),
                    Row(
                      children: [
                        if (isAuto) ...[
                          const AppIcon(
                            AppIconName.zap,
                            size: 12,
                            color: AppColors.iconBrand,
                          ),
                          const SizedBox(width: AppSpacing.x4),
                        ],
                        Expanded(
                          child: Text(
                            line,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyS.copyWith(
                              color: isAuto
                                  ? AppColors.textBrand
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.x8),
              _PlayButton(playing: playing, onTap: onPlay),
            ],
          ),
        ),
      ),
    );
  }
}

/// 썸네일 60 — 시안은 `bg/inverse` 바탕에 어둡게 덮고 작은 재생 삼각형을 얹는다.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.motion, required this.playing});

  final SavedMotion motion;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final path = motion.spec.thumbnailPath;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 60,
        height: 60,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.bgInverse),
            if (playing)
              const SimSlot(priority: 1)
            else ...[
              if (path != null && path.isNotEmpty)
                Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              const ColoredBox(color: AppColors.bgOverlay),
              const Center(
                child: AppIcon(
                  AppIconName.playThumb,
                  size: 8.47,
                  color: AppColors.iconOnInverse,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 시안 `Button/Play` — 36 원형 `bg/surface-muted`, 아이콘 14.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.bgSurfaceMuted,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: playing
                  ? const Icon(Icons.stop, size: 14, color: AppColors.iconPrimary)
                  : const AppIcon(AppIconName.playChip, size: 14),
            ),
          ),
        ),
      );
}

/// 시안 `Filter` — `Chip` M 세 개, 간격 8. 고른 것은 검정.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.value, required this.onChanged});

  final LibraryFilter value;
  final ValueChanged<LibraryFilter> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 43,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x24),
          children: [
            for (final f in LibraryFilter.values)
              Padding(
                padding: EdgeInsets.only(
                  right: f == LibraryFilter.values.last ? 0 : AppSpacing.x8,
                ),
                child: PureChip(
                  label: switch (f) {
                    LibraryFilter.all => S.libraryFilterAll,
                    LibraryFilter.auto => S.libraryFilterAuto,
                    LibraryFilter.manual => S.libraryFilterManual,
                  },
                  state: f == value
                      ? PureChipState.selected
                      : PureChipState.normal,
                  onTap: () => onChanged(f),
                ),
              ),
          ],
        ),
      );
}
