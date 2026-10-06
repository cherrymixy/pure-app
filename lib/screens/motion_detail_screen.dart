import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../data/situations.dart';
import '../data/strings.dart';
import '../models/saved_motion.dart';
import '../providers/chat_provider.dart';
import '../providers/library_provider.dart';
import '../sim/sim_controller.dart';
import '../sim/sim_host.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_icon.dart';
import '../widgets/gray_box.dart';
import '../widgets/pure_button.dart';
import '../widgets/pure_sheet.dart';
import '../widgets/pure_top_bar.dart';

/// 07-2 모션 상세 — Figma `481:2984`.
///
/// 시안 값: 뒤로가기 상단바 + 더보기 44 흰 원 / 미리보기 354×300(radius 28,
/// `neutral/900`) / 제목 Title/L / 메타 14 / 반응 카드 radius 20 / 아래 버튼 둘.
class MotionDetailScreen extends StatefulWidget {
  const MotionDetailScreen({super.key, required this.motionId});

  final String motionId;

  @override
  State<MotionDetailScreen> createState() => _MotionDetailScreenState();
}

class _MotionDetailScreenState extends State<MotionDetailScreen> {
  bool _playing = false;
  StreamSubscription<SimEvent>? _sub;

  SimController get _sim => SimHost.controllerOf(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sub = _sim.events.listen((e) {
        if (e is SimEnded && mounted) setState(() => _playing = false);
      });
      _play();
      if (_devSheet == 'delete') {
        _delete();
      } else if (_devSheet == 'rename') {
        _rename();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  SavedMotion? get _motion =>
      context.read<LibraryProvider>().byId(widget.motionId);

  Future<void> _play() async {
    final motion = _motion;
    if (motion == null) return;
    setState(() => _playing = true);
    try {
      await _sim.playRecipe(motion.spec.recipe.toJson());
      await _sim.setFace(motion.spec.face);
    } catch (_) {
      if (mounted) setState(() => _playing = false);
    }
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _sim.stop();
      if (mounted) setState(() => _playing = false);
    } else {
      await _play();
    }
  }

  Future<void> _rename() async {
    final motion = _motion;
    if (motion == null) return;
    final library = context.read<LibraryProvider>();

    final next = await showPureRename(
      context,
      title: S.renameTitle,
      initial: motion.name,
      maxLength: LibraryProvider.nameMax,
      validate: (text) => text.isEmpty
          ? S.errorNameEmpty
          : (library.isNameAvailable(text, ignoreId: motion.id)
              ? null
              : S.errorNameTaken),
    );

    if (next == null || !mounted) return;
    final outcome = await library.rename(motion.id, next);
    if (!mounted) return;
    showGrayToast(
      context,
      outcome is SaveSucceeded ? S.toastRenamed : S.errorNameTaken,
    );
  }

  Future<void> _delete() async {
    final motion = _motion;
    if (motion == null) return;
    final situation = motion.situation;

    // 자동 재생이던 모션은 무엇이 멈추는지 함께 알린다.
    final body = motion.kind == ReactionKind.auto && situation != null
        ? fill(S.deleteMotionBodyAuto, {
            'situation': situationLabel(situation).toLowerCase(),
          })
        : S.deleteMotionBody;

    final ok = await showPureConfirm(
      context,
      title: fill(S.deleteMotionTitle, {'name': motion.name}),
      body: body,
      confirmLabel: S.actionDelete,
    );
    if (!ok || !mounted) return;

    await context.read<LibraryProvider>().delete(motion.id);
    if (!mounted) return;
    showGrayToast(context, S.toastDeleted);
    Navigator.pop(context);
  }

  Future<void> _editInChat() async {
    final motion = _motion;
    if (motion == null) return;
    final chat = context.read<ChatProvider>();
    final opened = await chat.open(motion.chatId);
    if (!mounted) return;
    if (!opened) {
      showGrayToast(context, 'That chat is gone.');
      return;
    }
    // 대화는 홈 위에 올라간다 — 홈만 남기고 돌아간다.
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    // 삭제·이름변경이 반영되게 watch.
    final library = context.watch<LibraryProvider>();
    final motion = library.byId(widget.motionId);

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      body: SafeArea(
        bottom: false,
        child: motion == null
            ? Column(
                children: [
                  const PureBackBar(),
                  const Expanded(
                    child: GrayEmptyState(
                      title: S.toastDeleted,
                      body: S.emptyLibraryBody,
                    ),
                  ),
                ],
              )
            : _body(motion),
      ),
    );
  }

  Widget _body(SavedMotion motion) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PureBackBar(
          trailing: PureRoundButton(
            icon: AppIconName.more,
            onTap: _openMenu,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x24,
              12,
              AppSpacing.x24,
              AppSpacing.x24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Preview(motion: motion, playing: _playing, onTap: _toggle),
                const SizedBox(height: 22),
                Text(motion.name, style: AppTextStyles.titleL),
                const SizedBox(height: AppSpacing.x4),
                Text(
                  [
                    fill(S.librarySavedOn, {'date': _date(motion.savedAt)}),
                    if (motion.editCount > 0)
                      fill(S.libraryEditedTimes, {'count': motion.editCount}),
                  ].join('  /  '),
                  // 시안 14 Regular — Label/M 과 크기가 같고 굵기만 다르다.
                  style: AppTextStyles.labelM.copyWith(
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 25),
                _TriggerCard(motion: motion),
                if (motion.spec.reasoning.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x12),
                  Text(motion.spec.reasoning, style: AppTextStyles.bodyS),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x24,
            0,
            AppSpacing.x24,
            18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PureButton(
                label: _playing ? S.actionStop : S.actionPlayOnPurebot,
                onPressed: _toggle,
              ),
              const SizedBox(height: AppSpacing.x12),
              PureButton(
                label: S.libraryEditInChat,
                variant: PureButtonVariant.secondary,
                onPressed: _editInChat,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 더보기 — 시안에 메뉴 모양이 따로 없어 같은 시트 틀로 띄운다.
  Future<void> _openMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.bgOverlay,
      builder: (context) => PureSheet(
        children: [
          const SizedBox(height: 22),
          PureButton(
            label: S.actionRename,
            variant: PureButtonVariant.subtle,
            onPressed: () => Navigator.pop(context, 'rename'),
          ),
          const SizedBox(height: 6),
          PureButton(
            label: S.actionDelete,
            variant: PureButtonVariant.danger,
            onPressed: () => Navigator.pop(context, 'delete'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'rename') {
      await _rename();
    } else {
      await _delete();
    }
  }

  /// 개발용 — 열자마자 시트를 띄운다. `--dart-define=DEV_SHEET=delete`
  static const String _devSheet = String.fromEnvironment('DEV_SHEET');

  /// 시안은 "Saved Oct 4" 꼴로 쓴다.
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _date(DateTime t) => '${_months[t.month - 1]} ${t.day}';
}

/// 시안 `Preview` (`481:2992`) — 354×300, radius 28, `neutral/900`.
///
/// 재생 중이면 여기서 시뮬레이터가 돈다. 아니면 썸네일 위에 어둡게 깔고
/// 가운데 큰 재생 삼각형을 얹는다.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.motion,
    required this.playing,
    required this.onTap,
  });

  final SavedMotion motion;
  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final path = motion.spec.thumbnailPath;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: AspectRatio(
          aspectRatio: 354 / 300,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: AppColors.neutral900),
              if (playing)
                const SimSlot(priority: 1, borderRadius: AppRadius.xl)
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
                    size: 50,
                    color: AppColors.iconOnInverse,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 시안 `Trigger` (`481:2999`) — 흰 카드 radius 20, 좌우 20 / 위아래 16, 줄 간격 6.
class _TriggerCard extends StatelessWidget {
  const _TriggerCard({required this.motion});
  final SavedMotion motion;

  @override
  Widget build(BuildContext context) {
    final situation = motion.situation;
    final isAuto = motion.kind == ReactionKind.auto;

    final String? label;
    final String value;
    switch (motion.kind) {
      case ReactionKind.auto:
        label = S.libraryTriggerAuto;
        value = situation == null ? '' : situationLabel(situation);
      case ReactionKind.askFirst:
        label = S.libraryTriggerAsk;
        value = situation == null ? '' : situationLabel(situation);
      case ReactionKind.manual:
        label = null;
        value = S.saveSheetOnlyWhenIAsk;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x20,
        vertical: AppSpacing.x16,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Text(
              label,
              style: AppTextStyles.bodyS.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              if (isAuto) ...[
                const AppIcon(
                  AppIconName.zap,
                  size: 16,
                  color: AppColors.iconBrand,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(child: Text(value, style: AppTextStyles.bodyLStrong)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            S.libraryTriggerHint,
            style: AppTextStyles.bodyS.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
