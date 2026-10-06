import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../data/chips.dart';
import '../data/question_tree.dart';
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
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_icon.dart';
import '../widgets/appear.dart';
import '../widgets/composer.dart';
import '../widgets/pure_banner.dart';
import '../widgets/pure_chip.dart';
import '../widgets/pure_sidebar.dart';
import '../widgets/pure_toast.dart';
import '../widgets/pure_top_bar.dart';
import '../widgets/robot_card.dart';
import '../widgets/save_sheet.dart';

/// 06-1 홈 — 그리고 06-2~06-7 채팅.
///
/// **둘은 같은 화면이다** (시안 프레임 이름이 둘 다 `06-1.home`). 대화가 비어
/// 있으면 글로우·인사말·칩이 보이고, 말을 걸면 그것들이 사라지면서 말풍선이
/// 그 자리를 채운다. 화면이 넘어가지 않는다 (승아 결정).
///
/// 여기서 만든 것이 전부 한 줄로 이어진다:
/// 입력 → (칩·음성이면 되묻기) → 영상 프레임 추출 → GenerationService
/// → ChatProvider 기록 → 시뮬레이터 재생 → 썸네일 캡처 → LibraryProvider 저장.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.startNewChat = false});

  /// 사이드바의 "New motion" 으로 들어왔는가. 빈 대화에서 시작한다.
  final bool startNewChat;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
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

  /// 지금 보고 있는 대화. 사이드바에서 다른 대화를 열면 상태를 비운다.
  String? _lastChatId;

  /// 칩을 눌러 입력창을 채웠으면 그 id. 문장을 고치면 더 이상 칩이 아니다.
  String? _pendingChipId;
  bool _fromVoice = false;

  /// 위쪽 페이드는 스크롤이 시작돼야 보인다 (시안 06-E1 은 opacity 0).
  bool _scrolled = false;

  /// 로봇이 **생성 말고** 입을 떼기 직전 (되묻는 질문). 생성 답장은 ChatProvider 의
  /// pending 자리가 점 세 개를 맡지만, 질문은 메시지로 바로 꽂히기 때문에 여기서
  /// 잠깐 띄운다 — 로봇이 말하기 전에는 늘 점이 구른다 (승아 결정).
  bool _typingAhead = false;

  /// 점 세 개가 깜빡이고 마는 걸 막는 최소 노출 시간.
  static const Duration _typingBeat = Duration(milliseconds: 700);

  /// [since] 로부터 [_typingBeat] 가 지나지 않았으면 남은 만큼 기다린다.
  Future<void> _holdTyping(DateTime since) async {
    final left = _typingBeat - DateTime.now().difference(since);
    if (left > Duration.zero) await Future<void>.delayed(left);
  }

  /// 점 세 개를 띄워 두고 [body] 가 끝날 때까지 기다린다.
  Future<void> _withTyping(Future<void> Function() body) async {
    setState(() => _typingAhead = true);
    _scrollToEnd();
    final since = DateTime.now();
    await _holdTyping(since);
    if (!mounted) return;
    setState(() => _typingAhead = false);
    await body();
  }

  SimController get _sim => SimHost.controllerOf(context);

  // ------------------------------------------------- 되묻기 (옛 06-9 질문형)
  //
  // 칩이나 음성으로 보내면 바로 만들지 않고 두 번 되묻는다. 예전에는 별도 화면에서
  // 큰 동그라미 답안을 골랐지만, 지금은 질문도 로봇 말풍선이고 답안은 그 아래
  // 알약 칩이다 (승아 결정).

  QuestionBranch? _branch;
  WhenOption? _when;
  HowOption? _how;
  String? _chipId;

  /// 지금 답을 기다리는 중인가. 답하면(칩이든 직접 입력이든) 꺼진다.
  bool _asking = false;

  static String _flat(String label) => label.replaceAll('\n', ' ');

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
    if (widget.startNewChat) {
      await chat.startNew();
    } else {
      await chat.ensureCurrent();
    }
    if (!mounted) return;
    _lastChatId = chat.currentId;
    // 이어 보는 대화는 마지막 답장이 보이는 자리에서 시작한다.
    _scrollToEnd();

  }

  /// 사이드바에서 다른 대화를 열었다 — 이 화면이 들고 있던 것은 전부 비운다.
  void _resetForNewConversation() {
    _stopPlaying();
    setState(() {
      _activeSpecId = null;
      _savedSpecs.clear();
      _lastUserText = null;
      _branch = null;
      _when = null;
      _how = null;
      _chipId = null;
      _asking = false;
      _delayed = false;
    });
    _scrollToEnd();
  }

  // ---------------------------------------------------------------- 되묻기

  Future<void> _startQuestions({String? chipId, required String text}) async {
    final chat = context.read<ChatProvider>();
    final branch = branchForChip(chipId);

    setState(() {
      _branch = branch;
      _chipId = chipId;
      _asking = true;
    });

    await chat.addUserMessage(text: text);
    if (!mounted) return;
    await _withTyping(
      () => chat.addQuestion(
        text: kStep1Question,
        choices: [
          for (final o in branch.whenOptions)
            MessageChoice(id: o.id, label: _flat(o.label)),
        ],
      ),
    );
    if (!mounted) return;
    _scrollToEnd();
  }

  Future<void> _onChoice(MessageChoice choice) async {
    final branch = _branch;
    if (branch == null || !_asking) return;

    if (_when == null) {
      final option = branch.whenOptions.firstWhere(
        (o) => o.id == choice.id,
        orElse: () => branch.whenOptions.first,
      );
      await _answerWhen(option, choice.label);
      return;
    }

    final option = branch.howOptions.firstWhere(
      (o) => o.id == choice.id,
      orElse: () => branch.howOptions.first,
    );
    setState(() => _how = option);
    await context.read<ChatProvider>().addUserMessage(text: choice.label);
    if (!mounted) return;
    setState(() => _asking = false);
    await _generate();
  }

  Future<void> _answerWhen(WhenOption option, String label) async {
    final chat = context.read<ChatProvider>();
    setState(() => _when = option);
    await chat.addUserMessage(text: label);
    if (!mounted) return;

    await _withTyping(
      () => chat.addQuestion(
        text: kStep2Question,
        choices: [
          for (final o in _branch!.howOptions)
            MessageChoice(id: o.id, label: _flat(o.label)),
        ],
      ),
    );
    if (!mounted) return;
    _scrollToEnd();
  }

  /// 칩 대신 직접 적거나 말해서 답했다 — 남은 질문은 건너뛰고 바로 만든다.
  Future<void> _answerFreely(String text) async {
    await context.read<ChatProvider>().addUserMessage(text: text);
    if (!mounted) return;
    setState(() => _asking = false);
    await _generate(extra: text);
  }

  /// 지금까지의 답을 한 문장으로. GPT 에는 이게 상황 설명이 된다.
  String _promptText(String? extra) {
    final first = _lastUserText?.trim();
    return [
      if (first != null && first.isNotEmpty) first,
      if (_when != null) 'When: ${_flat(_when!.label)}',
      if (_how != null) 'How: ${_how!.hint}',
      if (extra != null && extra.trim().isNotEmpty) extra.trim(),
    ].join('. ');
  }

  /// 되묻기가 끝난 뒤의 생성. 답을 그대로 실어 보낸다.
  Future<void> _generate({String? extra}) async {
    final chat = context.read<ChatProvider>();
    final gen = context.read<GenerationProvider>();
    final robot = context.read<RobotProvider>();

    final pending = await chat.addPendingReply();
    if (!mounted) return;
    setState(() => _delayed = false);
    _scrollToEnd();
    final typingSince = DateTime.now();

    final result = await gen.generate(
      GenerationRequest(
        signature: robot.signature,
        text: _promptText(extra),
        chipId: _chipId,
        whenOptionId: _when?.id,
        howOptionId: _how?.id,
        situation: _when?.situation ?? _situationForChip(_chipId),
      ),
    );

    if (!mounted) return;
    if (result == null) {
      if (gen.status == GenerationStatus.failed) await chat.failReply(pending.id);
      return;
    }

    await _holdTyping(typingSince);
    if (!mounted) return;
    await chat.completeReply(pending.id, result.spec);
    if (!mounted) return;
    setState(() => _activeSpecId = result.spec.id);
    _scrollToEnd();
    await _play(result.spec, capture: true, messageId: pending.id);
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
    final typingSince = DateTime.now();

    var frames = const <String>[];
    if (video != null) {
      frames = await videoService.extractFrames(video);
    }
    if (!mounted) return;

    final result = await gen.generate(
      GenerationRequest(
        signature: robot.signature,
        text: text,
        frames: frames,
        chipId: chipId,
        situation: _situationForChip(chipId),
      ),
    );

    if (!mounted) return;
    if (result == null) {
      // 취소됐다면 새 요청이 이어받는다. 실패면 말풍선으로.
      if (gen.status == GenerationStatus.failed) {
        await chat.failReply(pending.id);
      }
      return;
    }

    await _holdTyping(typingSince);
    if (!mounted) return;
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
    final typingSince = DateTime.now();

    final result = await gen.generate(
      GenerationRequest(
        signature: robot.signature,
        text: _lastUserText,
        feedback: feedback,
        previousSpec: previous,
      ),
    );

    if (!mounted) return;
    if (result == null) {
      if (gen.status == GenerationStatus.failed) await chat.failReply(pending.id);
      return;
    }

    await _holdTyping(typingSince);
    if (!mounted) return;
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

  Future<void> _play(MotionSpec spec, {bool capture = false, String? messageId}) async {
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
    final waitMs = (MotionEngine.estimateSeconds(spec.recipe) * 1000)
        .clamp(600, 4000)
        .round();
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
      // 되묻기 1단계 답이 있으면 그걸로 미리 채운다.
      initialSituation: _when?.situation ?? _situationForChip(_chipId),
    );
    if (request == null || !mounted) return;

    final outcome = await library.save(
      id: 'saved.${spec.id}',
      name: request.name,
      spec: spec,
      chatId: chat.currentId ?? '',
      situation: request.situation,
      kind: request.kind,
    );
    if (!mounted) return;

    switch (outcome) {
      case SaveSucceeded(:final motion):
        setState(() => _savedSpecs[spec.id] = motion.id);
        showPureToast(
          context,
          S.toastSavedToLibrary,
          actionLabel: S.actionView,
          onAction: () => Navigator.pushNamed(context, AppRoutes.library),
        );
      case SaveRejected(:final reason):
        showPureToast(context, switch (reason) {
          SaveRejectReason.nameTaken => S.errorNameTaken,
          _ => S.errorNameEmpty,
        });
    }
  }

  // ---------------------------------------------------------------- 보조

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: AppMotion.maybe(context, AppMotion.screen),
        curve: AppMotion.easeIn,
      );
    });
  }

  /// 칩은 고르는 즉시 보낸다 (승아 결정) — 입력창에 채워 두고 한 번 더 누르게
  /// 하지 않는다.
  void _onChipTap(HomeChip chip) {
    _pendingChipId = chip.id;
    _fromVoice = false;
    _onComposerSend(chip.label, null);
  }

  void _onComposerSend(String text, VideoAttachment? video) {
    // 칩을 탭한 뒤 문장을 고쳤으면 더 이상 칩이 아니다.
    final chip = _pendingChipId == null ? null : chipById(_pendingChipId!);
    final stillChip = chip != null && chip.label == text.trim();
    final fromVoice = _fromVoice;
    _pendingChipId = null;
    _fromVoice = false;

    final trimmed = text.trim();

    // 되묻는 중이면 그게 곧 답이다 — 칩을 안 고르고 직접 적어도 된다.
    if (_asking && video == null && trimmed.isNotEmpty) {
      _answerFreely(text);
      return;
    }

    /*
     * 갈림길 (부록 D 결정):
     *  - 칩 · 음성 → 되묻기. 상황이 한 줄뿐이라 좁혀 가며 묻는다.
     *  - 텍스트 · 영상 → 바로 만든다.
     * 화면은 갈리지 않는다. 전부 이 화면 위에 쌓인다.
     */
    if ((stillChip || fromVoice) && video == null && trimmed.isNotEmpty) {
      _lastUserText = trimmed;
      _startQuestions(chipId: stillChip ? chip.id : null, text: trimmed);
      return;
    }

    final hasReply = context.read<ChatProvider>().lastReply != null;
    if (hasReply && video == null && trimmed.isNotEmpty) {
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
    final empty = messages.isEmpty;

    if (gen.status == GenerationStatus.delayed && !_delayed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _delayed = true);
      });
    }

    // 사이드바에서 다른 대화를 열면 이 화면이 들고 있던 것을 비운다.
    final id = chat.currentId;
    if (_lastChatId != null && id != null && id != _lastChatId) {
      _lastChatId = id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resetForNewConversation();
      });
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bgCanvas,
      resizeToAvoidBottomInset: true,
      drawer: const PureSidebar(),
      body: Stack(
        children: [
          _HomeGlow(visible: empty),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const PureTopBar(),
                // 시안 C-1: 상단바 아래, 좌우 24. 이 앱이 아는 '오프라인' 은
                // 데모 모드뿐이라 그때만 뜬다.
                if (context.watch<GenerationProvider>().forceDemo)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.x24,
                      AppSpacing.x8,
                      AppSpacing.x24,
                      0,
                    ),
                    child: PureBanner(
                      message: S.bannerDemoMode,
                      actionLabel: S.actionTurnOff,
                      onAction: _turnOffDemoMode,
                    ),
                  ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: AppMotion.maybe(context, AppMotion.screen),
                    child: empty
                        ? const _EmptyHome(key: ValueKey('empty'))
                        : _ChatList(
                            key: const ValueKey('chat'),
                            controller: _scroll,
                            messages: messages,
                            scrolled: _scrolled,
                            typingAhead: _typingAhead,
                            buildMessage: _buildMessage,
                          ),
                  ),
                ),
                // 시안 06-6: 입력창 바로 위.
                if (_playingSpecId != null)
                  _NowPlayingBar(elapsed: _playElapsed, onStop: _stop),
                // 시안 06-6 의 `Chat` 영역 아래 끝이 입력창 위와 맞닿는다. 그래서
                // 입력창을 띄워 얹지 않고 Column 의 마지막에 둔다 — 말풍선(과 그 위에
                // 올라타는 시뮬레이터)이 입력창을 덮지 않는다.
                Composer(
                  key: _composerKey,
                  controller: _text,
                  onSend: _onComposerSend,
                  onVoiceResult: (_) => _fromVoice = true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 배너의 `Turn off` — 데모 모드를 끈다.
  Future<void> _turnOffDemoMode() async {
    await context.read<GenerationProvider>().toggleDemoMode();
    if (!mounted) return;
    showPureToast(context, S.homeDemoModeOff);
  }

  /// 답안 칩을 마지막 질문에만 붙이려고 쓴다.
  String? get _lastMessageId {
    final list = context.read<ChatProvider>().messages;
    return list.isEmpty ? null : list.last.id;
  }

  Widget _buildMessage(Message m) {
    if (m.sender == Sender.user) return _UserBubble(message: m);

    // 되묻는 메시지. 답안 칩은 **아직 답하지 않은 마지막 질문**에만 붙는다.
    if (m.isQuestion) {
      final live = _asking && _lastMessageId == m.id;
      return Align(
        alignment: Alignment.centerLeft,
        child: _QuestionBubble(
          text: m.text ?? '',
          choices: live ? m.choices : const [],
          onChoice: _onChoice,
        ),
      );
    }

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
          onFullscreen: () =>
              Navigator.pushNamed(context, AppRoutes.preview, arguments: spec),
        );
    }
    return Align(alignment: Alignment.centerLeft, child: bubble);
  }
}

// ------------------------------------------------------------------ 빈 홈

/// 아직 말을 걸지 않았을 때 — 인사말과 상황 칩.
class _EmptyHome extends StatelessWidget {
  const _EmptyHome({super.key});

  @override
  Widget build(BuildContext context) {
    final name = context.watch<ProfileProvider>().name;
    final state = context.findAncestorStateOfType<_HomeScreenState>();

    // 시안에서 인사말은 화면 위쪽 1/3 근처, 칩 묶음은 가운데 아래.
    return Column(
      children: [
        const Spacer(flex: 24),
        Text(
          // 시안은 두 줄로 끊어 놓았다 — 이름이 길어도 같은 리듬을 유지한다.
          '${fill(S.homeGreetingLine1, {'name': name})}\n${S.homeGreetingLine2}',
          textAlign: TextAlign.center,
          style: AppTextStyles.homeGreeting,
        ),
        const Spacer(flex: 30),
        // 시안 배치: 2 / 2 / 1, 가운데 정렬, 묶음 폭 321.
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 321),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 11,
              children: [
                for (final chip in kHomeChips)
                  PureChip(
                    label: chip.label,
                    onTap: () => state?._onChipTap(chip),
                  ),
              ],
            ),
          ),
        ),
        const Spacer(flex: 26),
      ],
    );
  }
}

/// 배경 오로라. Figma 에서 받은 그림을 그대로 쓴다 (다시 그리지 않는다).
///
/// **PNG 로 받는다.** 시안의 글로우는 가우시안 블러가 걸린 원 세 개인데
/// `flutter_svg` 가 블러 필터를 지원하지 않아 SVG 로 넣으면 타원이 그대로 보인다.
/// Figma 가 블러까지 그려 준 3배 PNG 를 쓴다.
///
/// 시안 좌표: 좌 −16.02 · 상 305.98 · 420×535 (프레임 402×874 기준).
/// 말을 걸면 말풍선에 자리를 내주고 사라진다.
class _HomeGlow extends StatelessWidget {
  const _HomeGlow({required this.visible});
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    const designW = 402.0;
    const designH = 874.0;
    final kx = size.width / designW;
    final ky = size.height / designH;

    return Positioned(
      left: -16.02 * kx,
      top: 305.98 * ky,
      width: 420 * kx,
      height: 535 * ky,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          // 글로우만 일부러 느리다 — 말을 걸면 천천히 물러나야 한다.
          duration: AppMotion.maybe(context, const Duration(milliseconds: 420)),
          curve: AppMotion.easeIn,
          child: Image.asset('assets/images/glow_home.png', fit: BoxFit.fill),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ 채팅

class _ChatList extends StatelessWidget {
  const _ChatList({
    super.key,
    required this.controller,
    required this.messages,
    required this.scrolled,
    required this.typingAhead,
    required this.buildMessage,
  });

  final ScrollController controller;
  final List<Message> messages;
  final bool scrolled;

  /// 로봇이 입을 떼기 직전이면 맨 끝에 점 세 개를 붙인다.
  final bool typingAhead;

  final Widget Function(Message) buildMessage;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      // 시안 `Chat` (480:2458): 좌우 여백 25, 말풍선 사이 20.
      ListView.separated(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x24,
          AppSpacing.x24,
          AppSpacing.x24,
          AppSpacing.x20,
        ),
        itemCount: messages.length + (typingAhead ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.x20),
        // key 는 반드시 메시지 id — Appear 가 새로 온 것만 띄우게 한다.
        itemBuilder: (context, i) => i < messages.length
            ? Appear(
                key: ValueKey(messages[i].id),
                child: buildMessage(messages[i]),
              )
            : const Appear(
                key: ValueKey('typing'),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TypingBubble(),
                ),
              ),
      ),
      _TopFade(visible: scrolled),
    ],
  );
}

/// 로봇이 되묻는 말풍선 + 그 아래 추천 답안.
///
/// 말풍선은 시안 `Chat Bubble / Robot Text`, 답안은 홈과 같은 `Chip` (높이 43,
/// 좌우 16, radius full). 예전 06-9 의 큰 동그라미 버튼을 대신한다.
class _QuestionBubble extends StatelessWidget {
  const _QuestionBubble({
    required this.text,
    required this.choices,
    required this.onChoice,
  });

  final String text;
  final List<MessageChoice> choices;
  final ValueChanged<MessageChoice> onChoice;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      RobotTextBubble(text: text),
      if (choices.isNotEmpty) ...[
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 11,
          children: [
            for (final c in choices)
              PureChip(label: c.label, onTap: () => onChoice(c)),
          ],
        ),
      ],
    ],
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
        duration: AppMotion.maybe(context, AppMotion.quick),
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
          if (video != null && text.isNotEmpty) const SizedBox(height: AppSpacing.x8),
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
    final time =
        '${(s ~/ 60).toString().padLeft(2, '0')}:'
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
                  style: AppTextStyles.labelS.copyWith(color: AppColors.textOnInverse),
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
        padding: const EdgeInsets.fromLTRB(
          18,
          AppSpacing.x8,
          AppSpacing.x8,
          AppSpacing.x8,
        ),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), offset: Offset(0, 4), blurRadius: 16),
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
                    style: AppTextStyles.labelS.copyWith(color: AppColors.textOnInverse),
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
