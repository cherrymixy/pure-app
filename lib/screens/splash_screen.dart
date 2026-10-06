import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../app_routes.dart';
import '../providers/robot_provider.dart';
import '../theme/app_colors.dart';

/// 00 스플래시 — Figma `00.splash / Splash` (`474:2791`).
///
/// 시안의 로고는 정지 이미지가 아니라 **움직이는 영상**이다(`logo_motion_mobile 3`).
/// 그래서 PNG·SVG 로 받으면 빈 그림이 나온다 — Figma 에서 프레임째 MP4 로 내보내
/// `assets/video/splash.mp4` 로 넣었다 (402×874, 2.03초, 배경 `bg/canvas` 포함).
///
/// 영상이 끝나면 홈으로 간다 (첫 실행이면 05 시그니처 먼저). 이 2초 동안
/// 시뮬레이터가 뒤에서 wasm 을 올린다 — 홈에 도착했을 때 이미 준비돼 있게 하려는 것.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final VideoPlayerController _video;
  bool _ready = false;
  bool _left = false;
  Timer? _fallback;

  @override
  void initState() {
    super.initState();
    // 영상이 안 열려도 시연이 멈추면 안 된다 — 늦어도 2.6초면 넘어간다.
    _fallback = Timer(const Duration(milliseconds: 2600), _go);
    _video = VideoPlayerController.asset('assets/video/splash.mp4')
      ..addListener(_onTick);
    _init();
  }

  Future<void> _init() async {
    try {
      await _video.initialize();
      if (!mounted) return;
      setState(() => _ready = true);
      await _video.play();
    } catch (_) {
      // 영상이 없거나 못 열면 그냥 배경만 보이다 넘어간다.
    }
  }

  void _onTick() {
    if (!_video.value.isInitialized) return;
    final v = _video.value;
    if (v.position >= v.duration && !v.isPlaying) _go();
  }

  void _go() {
    if (_left || !mounted) return;
    _left = true;
    _fallback?.cancel();
    // 첫 실행이면 05 모션 시그니처를 먼저 보여 준다 (부록 D 결정).
    // "Reset demo data" 가 이 플래그도 지우므로 다음 관람객에게 다시 보여 줄 수 있다.
    final onboarded = context.read<RobotProvider>().onboarded;
    Navigator.pushReplacement(
      context,
      AppRoutes.fadeTo(onboarded ? AppRoutes.home : AppRoutes.signature),
    );
  }

  @override
  void dispose() {
    _fallback?.cancel();
    _video
      ..removeListener(_onTick)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 시안 배경 `#f2f2f2` — 영상에도 같은 배경이 들어 있어 이어 붙는다.
      backgroundColor: AppColors.bgCanvas,
      body: _ready
          // 영상 비율(402:874)이 기기와 거의 같다. 남는 쪽을 잘라 꽉 채운다.
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _video.value.size.width,
                  height: _video.value.size.height,
                  child: VideoPlayer(_video),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
