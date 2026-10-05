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
import '../providers/profile_provider.dart';
import '../providers/robot_provider.dart';
import '../services/generation/generation_client.dart';
import '../services/motion_engine.dart';
import '../services/thumbnail_store.dart';
import '../services/video_input_service.dart';
import '../sim/sim_controller.dart';
import '../sim/sim_host.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_icon.dart';
import '../widgets/composer.dart';
import '../widgets/gray_box.dart';
import '../widgets/pure_top_bar.dart';
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

  /// 위쪽 페이드는 스크롤이 시작돼야 보인다 (시안 06-E1 은 opacity 0).
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    _simSub?.cancel();
    _text.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final scrolled = _scroll.hasClients && _scroll.offset > 4;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    _simSub = _sim.events.listen(_onSimEvent);

    final chat = context.read<ChatProvider>();
    await chat.ensureCurrent();

    final entry = widget.entry;
    if (entry == null) {
      // 이어 보는 대화는 마지막 답장이 보이는 자리에서 시작한다.
      _scrollToEnd();
      return;
    }
    _lastUserText = entry.text;
    await _send(text: entry.text ?? '', video: entry.video, chipId: entry.chipId);
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

    final name = context.watch<ProfileProvider>().name;

    return Scaffold(
      backgroundColor: AppColors.bgCanvas,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const PureBackBar(),
                Expanded(
                  child: Stack(
                    children: [
                      // 시안 `Chat` (480:2458): 좌우 여백 25, 말풍선 사이 20.
                      ListView.separated(
                        controller: _scroll,
                        // 아래는 입력창(59 + 바깥 여백 8 + 홈 인디케이터) 만큼 비운다.
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.x24,
                          AppSpacing.x24,
                          AppSpacing.x24,
                          MediaQuery.paddingOf(context).bottom + 91,
                        ),
                        itemCount: messages.length + 1,
                        // 인사말 다음만 36, 나머지는 20.
                        separatorBuilder: (_, i) =>
                            SizedBox(height: i == 0 ? 36 : AppSpacing.x20),
                        itemBuilder: (context, i) => i == 0
                            ? _Greeting(name: name)
                            : _buildMessage(messages[i - 1]),
                      ),
                      _TopFade(visible: _scrolled),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_playingSpecId != null)
                  _NowPlayingBar(elapsed: _playElapsed, onStop: _stop),
                Composer(
                  key: _composerKey,
                  controller: _text,
                  onSend: _onComposerSend,
                  enabled: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(Message m) {
    if (m.sender == Sender.user) return _UserBubble(message: m);

    // 로봇 쪽은 전부 왼쪽 정렬이다 (시안 `Chat`).
    final Widget bubble;
    switch (m.status) {
      case MessageStatus.generating:
        bubble = TypingBubble(delayed: _delayed);
      case MessageStatus.failed:
        bubble = FailedBubble(onRetry: () => _send(text: _lastUserText ?? ''));
      case MessageStatus.sent:
      case MessageStatus.done:
        final spec = m.spec;
        if (spec == null) return const SizedBox.shrink();
        bubble = RobotCard(
          spec: spec,
          isActive: _activeSpecId == spec.id,
          playing: _playingSpecId == spec.id,
          saved: _savedSpecs.containsKey(spec.id),
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
    return Align(alignment: Alignment.centerLeft, child: bubble);
  }
}

/// 홈에서 보던 인사말이 채팅 맨 위에 그대로 이어진다 (시안 06-E1 `480:3015`).
class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Text(
        '${fill(S.homeGreetingLine1, {'name': name})}\n${S.homeGreetingLine2}',
        style: AppTextStyles.homeGreeting,
      );
}

/// 시안 `Top fade` — 위로 스크롤된 말풍선이 상단바 밑으로 사라지게 한다.
/// 높이 159.65 · `#e4e6e9` → 투명 · 전체 불투명도 50%.
class _TopFade extends StatelessWidget {
  const _TopFade({required this.visible});
  final bool visible;

  @override
  Widget build(BuildContext context) => Positioned(
        left: 0,
        right: 0,
        top: 0,
        height: 159.65,
        child: IgnorePointer(
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x80E4E6E9), Color(0x00E4E6E9)],
                ),
              ),
            ),
          ),
        ),
      );
}

/// 사용자 말풍선 — 시안 `Chat Bubble / User Text` · `User Media`.
///
/// 시안은 글과 영상을 **따로 띄운다**. 둘 다 있으면 영상이 위, 글이 아래로 붙는다.
class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message});
  final Message message;

  @override
  Widget build(BuildContext context) {
    final video = message.video;
    final text = message.text ?? '';

    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (video != null) _UserMediaBubble(video: video),
          if (video != null && text.isNotEmpty)
            const SizedBox(height: AppSpacing.x8),
          if (text.isNotEmpty)
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(text, style: AppTextStyles.bodyL),
            ),
        ],
      ),
    );
  }
}

/// 시안 `User Media` — 흰 말풍선 안쪽 패딩 16, 영상 140×140(radius 16).
class _UserMediaBubble extends StatelessWidget {
  const _UserMediaBubble({required this.video});
  final VideoAttachment video;

  @override
  Widget build(BuildContext context) {
    final s = video.selectedSec.round();
    final time = '${(s ~/ 60).toString().padLeft(2, '0')}:'
        '${(s % 60).toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0xFF393939)),
              if (video.thumbPath.isNotEmpty)
                Image.file(
                  File(video.thumbPath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              const ColoredBox(color: Color(0x33000000)),
              const Center(
                child: AppIcon(
                  AppIconName.playMedia,
                  size: 24,
                  color: AppColors.iconOnInverse,
                ),
              ),
              Positioned(
                left: AppSpacing.x12,
                bottom: AppSpacing.x12,
                child: Text(
                  time,
                  style: AppTextStyles.labelS.copyWith(
                    color: AppColors.textOnInverse,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 06-6 `Now playing` (`480:2758`) — 입력창 바로 위에 뜨는 흰 막대.
///
/// 시안 값: 좌우 여백 23 · radius 24 · 그림자 0 4 16 rgba(0,0,0,.08) ·
/// 왼쪽 18 / 오른쪽 8 / 위아래 8 · 요소 간격 10 · 세이지 점 8.
class _NowPlayingBar extends StatelessWidget {
  const _NowPlayingBar({required this.elapsed, required this.onStop});

  final int elapsed;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final time = '${elapsed ~/ 60}:${(elapsed % 60).toString().padLeft(2, '0')}';
    // 시안은 문구와 시간의 색·굵기가 다르다 — 자리표시자를 기준으로 쪼갠다.
    final parts = S.playingBar.split('{time}');

    return Padding(
      padding: const EdgeInsets.fromLTRB(23, 0, 23, 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, AppSpacing.x8, AppSpacing.x8, AppSpacing.x8),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              offset: Offset(0, 4),
              blurRadius: 16,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.bgBrand,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: parts.first),
                    TextSpan(
                      text: time,
                      style: AppTextStyles.labelM.copyWith(
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (parts.length > 1) TextSpan(text: parts[1]),
                  ],
                ),
                style: AppTextStyles.labelM,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Material(
              color: AppColors.bgInverse,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onStop,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x16,
                    vertical: AppSpacing.x8,
                  ),
                  child: Text(
                    S.actionStop,
                    style: AppTextStyles.labelS.copyWith(
                      color: AppColors.textOnInverse,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
