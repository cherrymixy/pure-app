import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../data/chips.dart';
import '../data/strings.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/profile_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/composer.dart';
import '../widgets/pure_sidebar.dart';
import '../widgets/pure_chip.dart';
import '../widgets/pure_top_bar.dart';

/// 06-1 홈 — Figma `06-1.home / Home` (`480:2041`).
///
/// 시안에서 읽은 값:
///  - 배경 `bg/canvas`, 그 위에 오로라 글로우 SVG (420×535, 좌 −16, 상 306)
///  - 상단바: 햄버거 44 + 종 24.55, 좌우 여백 15.34, 상단 62.4. **로봇 상태 텍스트 없음**
///  - 인사말: 34.78 / 42.96 Light, 가운데 정렬, 두 줄
///  - 칩: 높이 43 · 좌우 16 · radius full, 가로 간격 10 · 세로 11, 가운데, 묶음 폭 321
///  - 입력창: 바닥 고정, 좌우 여백 22
///
/// 화면 세로가 시안(874)보다 기기(852)가 짧아서 절대 좌표 대신 비율로 배치한다
/// (STEP 0 결정). 가로 여백과 요소 크기는 시안 값 그대로다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.startNewChat = false});

  /// 사이드바의 "New motion" 으로 들어왔는가.
  final bool startNewChat;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// 개발용 — 사이드바를 연 채로 띄워 스크린샷으로 확인한다.
  ///   ./scripts/dev.sh install --dart-define=OPEN_DRAWER=true
  static const bool _openDrawerOnStart = bool.fromEnvironment('OPEN_DRAWER');

  final _scaffoldKey = GlobalKey<ScaffoldState>();
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
    if (_openDrawerOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scaffoldKey.currentState?.openDrawer();
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
      fromVoice: fromVoice,
    );

    /*
     * 전부 채팅으로 간다 (승아 결정). 칩·음성은 상황이 한 줄뿐이라 채팅 안에서
     * 로봇이 두 번 되묻고, 텍스트·영상은 바로 만든다 (부록 D 의 갈림길은
     * 그대로지만 화면이 갈리지 않는다).
     */
    Navigator.pushNamed(context, AppRoutes.chat, arguments: entry);
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<ProfileProvider>().name;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bgCanvas,
      resizeToAvoidBottomInset: true,
      drawer: const PureSidebar(),
      body: Stack(
        children: [
          const _HomeGlow(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const PureTopBar(),
                // 시안에서 인사말은 화면 위쪽 1/3 근처, 칩 묶음은 가운데 아래.
                const Spacer(flex: 24),
                Text(
                  // 시안은 두 줄로 끊어 놓았다 — 이름이 길어도 같은 리듬을 유지한다.
                  '${fill(S.homeGreetingLine1, {'name': name})}\n${S.homeGreetingLine2}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.homeGreeting,
                ),
                const Spacer(flex: 30),
                const _HomeChips(),
                const Spacer(flex: 26),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Composer(
              key: _composerKey,
              controller: _text,
              onSend: _onSend,
              onVoiceResult: (_) => _fromVoice = true,
            ),
          ),
        ],
      ),
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
/// 기기 폭·높이가 달라도 같은 비율로 앉도록 환산해 놓는다.
class _HomeGlow extends StatelessWidget {
  const _HomeGlow();

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
        child: Image.asset(
          'assets/images/glow_home.png',
          fit: BoxFit.fill,
        ),
      ),
    );
  }
}

/// 상황 칩 5개. 시안 배치: 2 / 2 / 1, 가운데 정렬, 묶음 폭 321.
class _HomeChips extends StatelessWidget {
  const _HomeChips();

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_HomeScreenState>();
    return Center(
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
    );
  }
}

/// 홈에서 채팅으로 넘길 때 들고 가는 것.
class ChatEntry {
  const ChatEntry({
    this.text,
    this.video,
    this.chipId,
    this.fromVoice = false,
  });

  final String? text;
  final VideoAttachment? video;

  /// 칩에서 왔으면 그 id. 되물을지 판단하고 질문 가지를 고르는 데 쓴다 (부록 D).
  final String? chipId;

  /// 음성으로 들어왔는가. 칩과 마찬가지로 상황이 한 줄뿐이라 되묻는다.
  final bool fromVoice;

  bool get fromChip => chipId != null;
}
