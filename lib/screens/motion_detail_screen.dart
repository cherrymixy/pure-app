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
    final controller = TextEditingController(text: motion.name);

    final next = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheet) {
              final text = controller.text.trim();
              final changed = text != motion.name;
              final available = library.isNameAvailable(text, ignoreId: motion.id);
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(S.actionRename,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      maxLength: LibraryProvider.nameMax,
                      onChanged: (_) => setSheet(() {}),
                      decoration: InputDecoration(
                        counterText: '',
                        border: const OutlineInputBorder(),
                        errorText: text.isEmpty
                            ? S.errorNameEmpty
                            : (available ? null : S.errorNameTaken),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      // 바뀌었고 쓸 수 있는 이름일 때만 저장이 열린다.
                      onPressed: changed && available && text.isNotEmpty
                          ? () => Navigator.pop(context, text)
                          : null,
                      child: const Text(S.actionSave),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(S.actionCancel),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
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
    final warn = motion.kind == ReactionKind.auto && situation != null
        ? fill(S.deleteMotionAutoWarning,
            {'situation': situationLabel(situation).toLowerCase()})
        : null;

    final ok = await showGrayConfirm(
      context,
      title: S.deleteMotionTitle,
      body: warn,
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

  /// 더보기 — 시안에 메뉴 모양이 따로 없어 시트로 띄운다 (07-2 rename / delete).
  Future<void> _openMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text(S.actionRename),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              title: const Text(S.actionDelete),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'rename') {
      await _rename();
    } else {
      await _delete();
    }
  }

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
