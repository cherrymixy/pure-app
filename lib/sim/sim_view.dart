import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'sim_controller.dart';

/// 시뮬레이터 WebView 를 띄우는 위젯.
///
/// **앱 전체에 인스턴스는 하나뿐이다** (CLAUDE.md 규칙 14). 10MB wasm 컴파일 비용 때문에
/// 화면마다 새로 만들지 않는다. 로봇 카드·전체 화면·시그니처 화면은 같은 인스턴스를
/// 옮겨 쓴다 — 그 재부모화는 STEP 10 에서 붙인다.
///
/// WebView 패키지(flutter_inappwebview)는 2년째 업데이트가 없고 SwiftPM 전환 기한이
/// 걸려 있다. 바깥에서 이 패키지를 직접 부르는 곳은 이 파일과 sim_controller.dart 뿐이고,
/// 나머지 코드는 SimController 만 본다 — 나중에 갈아끼울 때 여기만 고치면 된다.
class SimView extends StatefulWidget {
  const SimView({
    super.key,
    required this.controller,
    this.onStatus,
  });

  final SimController controller;

  /// 로딩/오류 상태를 바깥에 알린다 (스피너·재시도 UI 용).
  final ValueChanged<SimViewStatus>? onStatus;

  @override
  State<SimView> createState() => _SimViewState();
}

enum SimViewStage { startingServer, loading, ready, failed }

class SimViewStatus {
  const SimViewStatus(this.stage, [this.message]);
  final SimViewStage stage;
  final String? message;
}

class _SimViewState extends State<SimView> {
  /// 포트는 계약의 일부다 — sim 번들은 자기 문서 위치 기준으로 에셋을 찾으므로
  /// 경로만 맞으면 되지만, 포트를 바꾸면 디버깅 문서가 전부 어긋난다.
  static const int _port = 8080;

  /// pubspec 의 `assets/sim/` 선언이 곧 URL 경로다. InAppLocalhostServer 는
  /// 에셋 키를 그대로 URL 로 쓴다 — `assets/` 접두사가 벗겨지지 않는다.
  static const String _entry = 'http://localhost:$_port/assets/sim/index.html$_probeQuery';

  /// 자체 검사 빌드에서만 sim 쪽 검증 통로를 연다. 일반 빌드에서는 닫혀 있다.
  static const String _probeQuery =
      bool.fromEnvironment('SIM_SELFTEST') ? '?probe=1' : '';

  /// 서버는 앱에 하나만 띄운다. 핫 리로드로 위젯이 다시 만들어져도 재사용된다.
  static InAppLocalhostServer? _server;
  static Future<void>? _serverStart;

  SimViewStatus _status = const SimViewStatus(SimViewStage.startingServer);
  int _reloadToken = 0;

  @override
  void initState() {
    super.initState();
    _ensureServer();
  }

  void _setStatus(SimViewStatus s) {
    if (!mounted) return;
    setState(() => _status = s);
    widget.onStatus?.call(s);
  }

  Future<void> _ensureServer() async {
    try {
      _server ??= InAppLocalhostServer(port: _port, documentRoot: './');
      _serverStart ??= _server!.start();
      await _serverStart;
      _setStatus(const SimViewStatus(SimViewStage.loading));
      return;
    } catch (e) {
      _serverStart = null;

      /*
       * 포트가 이미 물려 있을 때. 두 경우가 있고 구분해야 한다:
       *
       *  1) 우리 서버가 이미 떠 있다 (핫 리스타트). 그대로 쓰면 된다.
       *  2) 다른 프로세스가 물고 있다. iOS 시뮬레이터는 맥의 네트워크를 공유하므로
       *     맥에서 8080 을 쓰는 아무 프로그램이나, 또는 종료되지 않은 이전 빌드가
       *     여기 걸린다. 실기기에서는 생기지 않는다.
       *
       * 예외 메시지만 보고 1번이라고 단정하면 2번일 때 로딩 화면에 영원히 멈춘다.
       * 실제로 우리 번들이 그 포트에서 나오는지 확인하고 가른다.
       */
      final serving = await _bundleRespondsAtPort();
      if (serving) {
        _setStatus(const SimViewStatus(SimViewStage.loading));
        return;
      }

      _setStatus(SimViewStatus(
        SimViewStage.failed,
        '포트 $_port 를 다른 프로그램이 쓰고 있습니다.\n'
        '맥에서 그 프로그램을 끄고 Retry 를 누르세요.\n($e)',
      ));
      widget.controller.reportError('로컬 서버 실패(포트 $_port): $e');
    }
  }

  /// 그 포트에서 나오는 것이 우리 sim 번들인지 확인한다.
  Future<bool> _bundleRespondsAtPort() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final req = await client.getUrl(Uri.parse(_entry));
      final res = await req.close().timeout(const Duration(seconds: 3));
      if (res.statusCode != 200) return false;
      final body = await res.transform(const Utf8Decoder(allowMalformed: true)).join();
      return body.contains('id="stage"');
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  void _retry() {
    setState(() {
      _reloadToken += 1;
      _status = const SimViewStatus(SimViewStage.startingServer);
    });
    _serverStart = null;
    _ensureServer();
  }

  @override
  Widget build(BuildContext context) {
    final failed = _status.stage == SimViewStage.failed;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (!failed)
          InAppWebView(
            key: ValueKey(_reloadToken),
            initialUrlRequest: URLRequest(url: WebUri(_entry)),
            initialSettings: InAppWebViewSettings(
              // 기본값이 false 라 명시해야 한다. 표정 mp4 가 전체 화면으로 튀어나가지 않게.
              allowsInlineMediaPlayback: true,
              // 기본값이 true 라 명시해야 한다. 음소거 표정 영상이 자동 재생되게.
              mediaPlaybackRequiresUserGesture: false,
              transparentBackground: true,
              javaScriptEnabled: true,
              supportZoom: false,
              disableVerticalScroll: true,
              disableHorizontalScroll: true,
              // Safari 웹 인스펙터로 붙어 디버깅하기 위해.
              isInspectable: true,
              // useShouldOverrideUrlLoading 은 켜지 않는다 — 이 패키지의 iOS 크래시 이슈
              // (#2867)가 그 경로에 있고, 우리는 외부 링크를 열 일이 없다.
            ),
            onWebViewCreated: widget.controller.attach,
            onLoadStop: (_, _) => _setStatus(const SimViewStatus(SimViewStage.ready)),
            onReceivedError: (_, _, error) {
              _setStatus(SimViewStatus(SimViewStage.failed, error.description));
              widget.controller.reportError(error.description);
            },
            onReceivedHttpError: (_, _, response) {
              final code = response.statusCode;
              if (code != null && code >= 400) {
                _setStatus(SimViewStatus(SimViewStage.failed, 'HTTP $code'));
              }
            },
            onConsoleMessage: (_, msg) {
              // sim 쪽 콘솔을 Flutter 로그로 끌어온다 — wasm 로딩 문제는 여기서만 보인다.
              debugPrint('[sim] ${msg.messageLevel}: ${msg.message}');
            },
          ),
        if (_status.stage != SimViewStage.ready)
          _Overlay(status: _status, onRetry: failed ? _retry : null),
      ],
    );
  }

  @override
  void dispose() {
    widget.controller.detach();
    super.dispose();
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({required this.status, this.onRetry});

  final SimViewStatus status;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final failed = status.stage == SimViewStage.failed;
    return ColoredBox(
      color: const Color(0xFF0A0A0D),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!failed)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
              ),
            if (failed) const Icon(Icons.error_outline, color: Colors.white38, size: 28),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                status.message ?? 'Loading…',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF9AA0AD), fontSize: 12),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
