import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../data/strings.dart';
import '../models/message.dart';
import '../models/motion_spec.dart';
import '../models/saved_motion.dart';
import '../providers/chat_provider.dart';
import '../providers/generation_provider.dart';
import '../providers/library_provider.dart';
import '../providers/robot_provider.dart';
import '../services/generation/generation_client.dart';
import '../services/motion_engine.dart';
import '../services/thumbnail_store.dart';
import '../services/video_input_service.dart';
import '../sim/sim_controller.dart';
import '../sim/sim_host.dart';
import '../widgets/app_shell.dart';
import '../widgets/composer.dart';
import '../widgets/gray_box.dart';
import '../widgets/robot_card.dart';
import '../widgets/save_sheet.dart';
import 'home_screen.dart';

/// 06-2 ~ 06-7 — 전송 · 생성 중 · 로봇 답장 · 피드백 · 저장.
///
/// 지금까지 만든 것이 전부 여기서 한 줄로 이어진다:
/// 입력 → 영상 프레임 추출 → GenerationService(검증·시그니처 반영·데모 폴백)
/// → ChatProvider 기록 → 시뮬레이터 재생 → 썸네일 캡처 → LibraryProvider 저장.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.entry});

  /// 홈에서 들고 온 첫 입력. 없으면 기존 대화를 이어 본다.
  final ChatEntry? entry;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _composerKey = GlobalKey<ComposerState>();

  /// 지금 시뮬레이터를 차지한 답장.
  String? _activeSpecId;

  /// 재생 중인 모션 (06-6 상태 바).
  String? _playingSpecId;
  Timer? _playTimer;
  int _playElapsed = 0;

  StreamSubscription<SimEvent>? _simSub;
  bool _delayed = false;
  String? _lastUserText;

  /// 이 화면에서 저장한 모션 id → 라이브러리 id.
  final Map<String, String> _savedSpecs = {};

  SimController get _sim => SimHost.controllerOf(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    _simSub?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    _simSub = _sim.events.listen(_onSimEvent);

    final chat = context.read<ChatProvider>();
    await chat.ensureCurrent();

    final entry = widget.entry;
    if (entry != null) {
      _lastUserText = entry.text;
      await _send(text: entry.text ?? '', video: entry.video, chipId: entry.chipId);
    }
  }

  void _onSimEvent(SimEvent e) {
    if (e is SimEnded && _playingSpecId != null) _stopPlaying();
  }

  // ---------------------------------------------------------------- 전송

  Future<void> _send({
    required String text,
    VideoAttachment? video,
    String? chipId,
  }) async {
    final chat = context.read<ChatProvider>();
    final gen = context.read<GenerationProvider>();
    final robot = context.read<RobotProvider>();
    final videoService = context.read<VideoInputService>();

    // 생성 중에 새로 보내면 이전 자리를 치운다 (PRD §6-6).
    if (gen.isBusy) {
      gen.cancel();
      await chat.cancelPending();
    }

    if (text.trim().isNotEmpty) _lastUserText = text.trim();
    await chat.addUserMessage(text: text, video: video);
    final pending = await chat.addPendingReply();
    setState(() => _delayed = false);
    _scrollToEnd();

    var frames = const <String>[];
    if (video != null) {
      frames = await videoService.extractFrames(video);
    }
    if (!mounted) return;

    final result = await gen.generate(GenerationRequest(
      signature: robot.signature,
      text: text,
      frames: frames,
      chipId: chipId,
      situation: _situationForChip(chipId),
    ));

    if (!mounted) return;
    if (result == null) {
      // 취소됐다면 새 요청이 이어받는다. 실패면 말풍선으로.
      if (gen.status == GenerationStatus.failed) {
        await chat.failReply(pending.id);
      }
      return;
    }

    await chat.completeReply(pending.id, result.spec);
    if (!mounted) return;
    setState(() => _activeSpecId = result.spec.id);
    _scrollToEnd();
    await _play(result.spec, capture: true, messageId: pending.id);
  }

  /// 피드백 재생성 — 직전 답장을 기준으로 새 버전을 만든다 (06-5).
  Future<void> _sendFeedback(String feedback) async {
    final chat = context.read<ChatProvider>();
    final gen = context.read<GenerationProvider>();
    final robot = context.read<RobotProvider>();

    final previous = chat.lastReply?.spec;
    if (previous == null) {
      await _send(text: feedback);
      return;
    }

    if (gen.isBusy) {
      gen.cancel();
      await chat.cancelPending();
    }

    await chat.addUserMessage(text: feedback);
    final pending = await chat.addPendingReply();
    setState(() => _delayed = false);
    _scrollToEnd();

    final result = await gen.generate(GenerationRequest(
      signature: robot.signature,
      text: _lastUserText,
      feedback: feedback,
      previousSpec: previous,
    ));

    if (!mounted) return;
    if (result == null) {
      if (gen.status == GenerationStatus.failed) await chat.failReply(pending.id);
      return;
    }

    await chat.completeReply(pending.id, result.spec);
    if (!mounted) return;
    setState(() => _activeSpecId = result.spec.id);
    _scrollToEnd();
    await _play(result.spec, capture: true, messageId: pending.id);
  }

  Situation? _situationForChip(String? chipId) => switch (chipId) {
        'cameHome' => Situation.comesHome,
        'tired' => Situation.tired,
        'startled' => Situation.startled,
        _ => null,
      };

  // ---------------------------------------------------------------- 재생

  Future<void> _play(
    MotionSpec spec, {
    bool capture = false,
    String? messageId,
  }) async {
    setState(() {
      _activeSpecId = spec.id;
      _playingSpecId = spec.id;
      _playElapsed = 0;
    });

    _playTimer?.cancel();
    _playTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _playElapsed++);
    });

    try {
      // 시그니처는 레시피에 이미 반영돼 있다 — 배율을 또 넘기지 않는다 (STEP 6).
      await _sim.playRecipe(spec.recipe.toJson());
      await _sim.setFace(spec.face);
    } catch (_) {
      _stopPlaying();
      return;
    }

    if (!capture || messageId == null) return;

    // 재생이 한 바퀴 돈 뒤의 모습을 라이브러리 썸네일로 쓴다.
    final waitMs =
        (MotionEngine.estimateSeconds(spec.recipe) * 1000).clamp(600, 4000).round();
    await Future<void>.delayed(Duration(milliseconds: waitMs));
    if (!mounted) return;
    await _captureThumbnail(messageId, spec);
  }

  Future<void> _captureThumbnail(String messageId, MotionSpec spec) async {
    try {
      final data = await _sim.capture();
      if (data.isEmpty || !mounted) return;
      final store = context.read<ThumbnailStore>();
      final path = await store.savePngDataUrl(
        data,
        id: spec.id,
        replacing: spec.thumbnailPath,
      );
      if (path == null || !mounted) return;
      await context.read<ChatProvider>().attachThumbnail(messageId, path);
    } catch (_) {
      // 썸네일이 없다고 시연이 멈추면 안 된다.
    }
  }

  void _stopPlaying() {
    _playTimer?.cancel();
    _playTimer = null;
    if (mounted) setState(() => _playingSpecId = null);
  }

  Future<void> _stop() async {
    await _sim.stop();
    _stopPlaying();
  }

  // ---------------------------------------------------------------- 저장

  Future<void> _save(MotionSpec spec) async {
    final chat = context.read<ChatProvider>();
    final library = context.read<LibraryProvider>();

    final request = await showSaveSheet(
      context,
      spec: spec,
      lastUserText: _lastUserText,
      initialSituation: _situationForChip(widget.entry?.chipId),
    );
    if (request == null || !mounted) return;

    final outcome = await library.save(
      id: 'saved.${spec.id}',
      name: request.name,
      spec: spec,
      chatId: chat.currentId ?? '',
      situation: request.situation,
    );
    if (!mounted) return;

    switch (outcome) {
      case SaveSucceeded(:final motion):
        setState(() => _savedSpecs[spec.id] = motion.id);
        showGrayToast(
          context,
          S.toastSavedToLibrary,
          actionLabel: S.actionView,
          onAction: () => Navigator.pushNamed(context, AppRoutes.library),
        );
      case SaveRejected(:final reason):
        showGrayToast(
          context,
          switch (reason) {
            SaveRejectReason.nameTaken => S.errorNameTaken,
            _ => S.errorNameEmpty,
          },
        );
    }
  }

  // ---------------------------------------------------------------- 보조

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  void _onComposerSend(String text, VideoAttachment? video) {
    final hasReply = context.read<ChatProvider>().lastReply != null;
    if (hasReply && video == null && text.trim().isNotEmpty) {
      _sendFeedback(text);
    } else {
      _send(text: text, video: video);
    }
  }

  // ---------------------------------------------------------------- 그리기

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final gen = context.watch<GenerationProvider>();
    final messages = chat.messages;

    if (gen.status == GenerationStatus.delayed && !_delayed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _delayed = true);
      });
    }

    return AppShell(
      onBack: () => Navigator.pop(context),
      title: null,
      actions: [
        IconButton(
          icon: const Icon(Icons.history),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.chats),
        ),
      ],
      floating: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_playingSpecId != null) _PlayingBar(elapsed: _playElapsed, onStop: _stop),
          Composer(
            key: _composerKey,
            controller: _text,
            onSend: _onComposerSend,
            enabled: true,
          ),
        ],
      ),
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: messages.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _buildMessage(messages[i]),
      ),
    );
  }

  Widget _buildMessage(Message m) {
    if (m.sender == Sender.user) return _UserBubble(message: m);

    switch (m.status) {
      case MessageStatus.generating:
        return TypingBubble(delayed: _delayed);
      case MessageStatus.failed:
        return FailedBubble(
          onRetry: () => _send(text: _lastUserText ?? ''),
        );
      case MessageStatus.sent:
      case MessageStatus.done:
        final spec = m.spec;
        if (spec == null) return const SizedBox.shrink();
        final isActive = _activeSpecId == spec.id;
        return RobotCard(
          spec: spec,
          isActive: isActive,
          saved: _savedSpecs.containsKey(spec.id),
          statusLabel: _playingSpecId == spec.id ? S.playingOnPurebot : null,
          onTap: () => setState(() => _activeSpecId = spec.id),
          onPlay: () => _play(spec),
          onSave: () => _save(spec),
          onFullscreen: () => Navigator.pushNamed(
            context,
            AppRoutes.preview,
            arguments: spec,
          ),
        );
    }
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message});
  final Message message;

  @override
  Widget build(BuildContext context) {
    final video = message.video;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Gray.accent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (video != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    if (video.thumbPath.isNotEmpty)
                      Image.file(
                        File(video.thumbPath),
                        width: 160,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const SizedBox(width: 160, height: 120),
                      ),
                    Container(
                      margin: const EdgeInsets.all(6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${video.selectedSec.toStringAsFixed(0)}s',
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              if ((message.text ?? '').isNotEmpty) const SizedBox(height: 6),
            ],
            if ((message.text ?? '').isNotEmpty)
              Text(
                message.text!,
                style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.4),
              ),
          ],
        ),
      ),
    );
  }
}

/// 06-6 재생 상태 바 — 입력창 바로 위.
class _PlayingBar extends StatelessWidget {
  const _PlayingBar({required this.elapsed, required this.onStop});

  final int elapsed;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final time = '${elapsed ~/ 60}:${(elapsed % 60).toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(
          color: Gray.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Gray.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                fill(S.playingBar, {'time': time}),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            TextButton(onPressed: onStop, child: const Text(S.actionStop)),
          ],
        ),
      ),
    );
  }
}
