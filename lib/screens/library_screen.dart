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
import '../widgets/app_shell.dart';
import '../widgets/gray_box.dart';

/// 07-1 라이브러리 — 필터 · 자동 재생 그룹 · 카드.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
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

    return AppShell(
      title: S.libraryTitle,
      onBack: () => Navigator.pop(context),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.librarySearch),
        ),
      ],
      child: library.isEmpty
          ? GrayEmptyState(
              title: S.emptyLibraryTitle,
              body: S.emptyLibraryBody,
              actionLabel: S.emptyLibraryAction,
              onAction: () => Navigator.popUntil(context, (r) => r.isFirst),
            )
          : Column(
              children: [
                _FilterBar(
                  value: library.filter,
                  onChanged: library.setFilter,
                ),
                Expanded(child: _list(library)),
              ],
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
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (auto.isNotEmpty) ...[
          const GraySectionLabel(S.libraryAutoGroup),
          ...auto.map(_card),
        ],
        if (others.isNotEmpty) ...[
          if (auto.isNotEmpty) const SizedBox(height: 4),
          ...others.map(_card),
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

/// 07-1 카드. 재생 중이면 그 자리에서 시뮬레이터가 돈다.
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

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      decoration: BoxDecoration(
        color: Gray.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Gray.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 72,
                  height: 54,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: Color(0xFF0A0A0D)),
                      if (playing)
                        const SimSlot(priority: 1)
                      else
                        _Thumb(path: motion.spec.thumbnailPath),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    nameSpan == null
                        ? Text(motion.name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w500))
                        : Text.rich(nameSpan!,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (isAuto)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.bolt, size: 13, color: Gray.accent),
                          ),
                        Expanded(
                          child: Text(
                            reactionLabel(motion.kind, situation),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isAuto ? Gray.accent : Gray.dim,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onPlay,
                icon: Icon(playing ? Icons.stop : Icons.play_arrow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.path});
  final String? path;

  @override
  Widget build(BuildContext context) {
    final p = path;
    if (p == null || p.isEmpty) {
      return const Center(
        child: Icon(Icons.smart_toy_outlined, size: 20, color: Colors.white24),
      );
    }
    return Image.file(
      File(p),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const Center(
        child: Icon(Icons.smart_toy_outlined, size: 20, color: Colors.white24),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.value, required this.onChanged});

  final LibraryFilter value;
  final ValueChanged<LibraryFilter> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(
          children: [
            for (final f in LibraryFilter.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GrayChip(
                  label: switch (f) {
                    LibraryFilter.all => S.libraryFilterAll,
                    LibraryFilter.auto => S.libraryFilterAuto,
                    LibraryFilter.manual => S.libraryFilterManual,
                  },
                  selected: f == value,
                  onTap: () => onChanged(f),
                ),
              ),
          ],
        ),
      );
}
