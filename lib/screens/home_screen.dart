import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../data/chips.dart';
import '../data/strings.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/composer.dart';
import '../widgets/gray_box.dart';

/// 06-1 홈 — 인사말 · 상황 칩 5개 · 입력창.
///
/// 칩을 탭하면 입력창을 **채우기만** 한다 (PRD §4 06-1). 보내는 건 사용자가 한다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.startNewChat = false});

  /// 사이드바의 "New motion" 으로 들어왔는가.
  final bool startNewChat;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _text = TextEditingController();
  final _composerKey = GlobalKey<ComposerState>();
  String? _pendingChipId;
  bool _fromVoice = false;

  @override
  void initState() {
    super.initState();
    if (widget.startNewChat) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<ChatProvider>().startNew();
      });
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _onChipTap(HomeChip chip) {
    _pendingChipId = chip.id;
    _fromVoice = false;
    _composerKey.currentState?.fill(chip.label);
  }

  void _onSend(String text, VideoAttachment? video) {
    // 칩을 탭한 뒤 문장을 고쳤으면 더 이상 칩이 아니다.
    final chip = _pendingChipId == null ? null : chipById(_pendingChipId!);
    final stillChip = chip != null && chip.label == text.trim();
    final fromVoice = _fromVoice;

    _pendingChipId = null;
    _fromVoice = false;

    final entry = ChatEntry(
      text: text,
      video: video,
      chipId: stillChip ? chip.id : null,
    );

    /*
     * 갈림길 (부록 D 결정):
     *  - 칩 · 음성 → 질문형(06-9). 상황을 좁혀 가며 묻는다.
     *  - 텍스트 · 영상 → 채팅(06-2~06-5). 바로 만든다.
     * 둘은 같은 Chat 위에 올라가므로 기록은 한 곳에 남는다.
     */
    final toQuestion = (stillChip || fromVoice) && video == null;
    Navigator.pushNamed(
      context,
      toQuestion ? AppRoutes.question : AppRoutes.chat,
      arguments: entry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<ProfileProvider>().name;

    return AppShell(
      floating: Composer(
        key: _composerKey,
        controller: _text,
        onSend: _onSend,
        onVoiceResult: (_) => _fromVoice = true,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          Text(
            fill(S.homeGreeting, {'name': name}),
            style: const TextStyle(fontSize: 26, height: 1.3, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final chip in kHomeChips)
                GrayChip(label: chip.label, onTap: () => _onChipTap(chip)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 홈에서 채팅/질문형으로 넘길 때 들고 가는 것.
class ChatEntry {
  const ChatEntry({this.text, this.video, this.chipId});

  final String? text;
  final VideoAttachment? video;

  /// 칩에서 왔으면 그 id. 질문형으로 갈지 판단하는 데 쓴다 (부록 D 결정).
  final String? chipId;

  bool get fromChip => chipId != null;
}
