import 'dart:async';

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
import '../widgets/app_shell.dart';
import '../widgets/gray_box.dart';

/// 07-2 모션 상세 — 미리보기 · 정보 · 재생 · Edit in chat · Rename / Delete.
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
    if (motion == null) {
      return AppShell(
        title: S.libraryTitle,
        onBack: () => Navigator.pop(context),
        child: const GrayEmptyState(
          title: S.toastDeleted,
          body: S.emptyLibraryBody,
        ),
      );
    }

    final situation = motion.situation;
    final isAuto = motion.kind == ReactionKind.auto;

    return AppShell(
      title: motion.name,
      onBack: () => Navigator.pop(context),
      actions: [
        PopupMenuButton<String>(
          onSelected: (v) => v == 'rename' ? _rename() : _delete(),
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'rename', child: Text(S.actionRename)),
            PopupMenuItem(value: 'delete', child: Text(S.actionDelete)),
          ],
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Gray.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: Color(0xFF0A0A0D)),
                    const SimSlot(priority: 1),
                    if (!_playing)
                      const Center(
                        child: Icon(Icons.play_arrow,
                            size: 44, color: Colors.white38),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            [
              fill(S.librarySavedOn, {'date': _date(motion.savedAt)}),
              if (motion.editCount > 0)
                fill(S.libraryEditedTimes, {'count': motion.editCount}),
            ].join(' · '),
            style: const TextStyle(fontSize: 12, color: Gray.dim),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (isAuto)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.bolt, size: 16, color: Gray.accent),
                ),
              Expanded(
                child: Text(
                  reactionDetail(motion.kind, situation),
                  style: TextStyle(
                    fontSize: 14,
                    color: isAuto ? Gray.accent : Gray.dim,
                  ),
                ),
              ),
            ],
          ),
          if (motion.spec.reasoning.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(motion.spec.reasoning,
                style: const TextStyle(fontSize: 13, height: 1.45)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _toggle,
            icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
            label: Text(_playing ? S.actionStop : S.actionPlayOnPurebot),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _editInChat,
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text(S.libraryEditInChat),
          ),
        ],
      ),
    );
  }

  static String _date(DateTime t) =>
      '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')}';
}
