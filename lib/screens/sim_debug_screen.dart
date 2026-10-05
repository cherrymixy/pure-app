import 'dart:async';

import 'package:flutter/material.dart';

import '../sim/sim_controller.dart';
import '../sim/sim_view.dart';

/// STEP 3 브리지 확인용 임시 화면. 회색박스 화면(STEP 10)이 들어오면 사라진다.
///
/// 여기서 확인하는 것: WebView 안에서 wasm 이 뜨는가 / 표정 mp4 가 재생되는가 /
/// Flutter 버튼으로 재생·정지·캡처가 되는가 / ended 이벤트가 올라오는가.
class SimDebugScreen extends StatefulWidget {
  const SimDebugScreen({super.key});

  @override
  State<SimDebugScreen> createState() => _SimDebugScreenState();
}

class _SimDebugScreenState extends State<SimDebugScreen> {
  final _sim = SimController();
  final _log = <String>[];
  StreamSubscription<SimEvent>? _sub;
  String? _capturePreview;

  /// --dart-define=SIM_SELFTEST=1 로 빌드하면 ready 직후 브리지 전체를 자동으로 돌린다.
  /// 결과는 로그로 나가므로 사람이 버튼을 누르지 않아도 검증할 수 있다.
  static const bool _selfTest = bool.fromEnvironment('SIM_SELFTEST');

  @override
  void initState() {
    super.initState();
    if (_selfTest) unawaited(_runSelfTest());
    _sub = _sim.events.listen((e) {
      final line = switch (e) {
        SimReady(:final behaviors, :final faces, :final limits) =>
          'ready · 동작 ${behaviors.length} · 얼굴 ${faces.length} · '
              'head_tilt ${limits['head_tilt']?.$1.toStringAsFixed(0)}~'
              '${limits['head_tilt']?.$2.toStringAsFixed(0)}',
        SimPlaying(:final behavior, :final durationSec) =>
          'playing · $behavior · ${durationSec.toStringAsFixed(1)}s',
        SimEnded(:final id) => 'ended · $id',
        SimError(:final message) => 'error · $message',
      };
      setState(() {
        _log.insert(0, line);
        if (_log.length > 8) _log.removeLast();
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sim.dispose();
    super.dispose();
  }

  Future<void> _runSelfTest() async {
    void report(String name, bool pass, [String detail = '']) {
      debugPrint('SELFTEST ${pass ? 'PASS' : 'FAIL'} · $name${detail.isEmpty ? '' : ' · $detail'}');
    }

    try {
      final ready = await _sim.ready.timeout(const Duration(seconds: 60));
      report('ready', true,
          '동작 ${ready.behaviors.length} 얼굴 ${ready.faces.length}');
      report('동작 15종', ready.behaviors.length == 15, '${ready.behaviors.length}');
      report('얼굴 7종', ready.faces.length == 7, '${ready.faces.length}');
      final tilt = ready.limits['head_tilt'];
      report('head_tilt 범위', tilt != null && tilt.$1 == -33 && tilt.$2 == 42, '$tilt');

      // 재생 → ended 이벤트
      final ended = _sim.events.firstWhere((e) => e is SimEnded).timeout(
            const Duration(seconds: 25),
            onTimeout: () => const SimError(message: 'ended 타임아웃'),
          );
      final id = await _sim.playBehavior('greet', speed: 1.4);
      final result = await ended;
      report('playBehavior → ended', result is SimEnded && result.id == id, id);

      // 레시피
      await _sim.playRecipe({
        'steps': [
          {'behavior': 'nod', 'repeat': 2},
        ],
      });
      report('playRecipe', true);

      // 표정
      await _sim.setFace('heart');
      report('setFace(heart)', true);

      // 캡처 — 투명/빈 PNG 면 실패
      final png = await _sim.capture();
      report('capture', png.startsWith('data:image/png') && png.length > 20000,
          '${png.length} chars');

      // 대기 모션
      await _sim.setIdle(behavior: 'doze', speed: 1.2);
      report('setIdle(doze)', true);

      // 허용 목록 밖 이름은 던져야 한다
      var threw = false;
      try {
        await _sim.playBehavior('moonwalk');
      } catch (_) {
        threw = true;
      }
      report('알 수 없는 동작은 throw', threw);

      // 계약 관절 이름이 실제로 변환되는지
      var clipOk = true;
      try {
        await _sim.playClip({
          'format': 'lelamp.clip/1',
          'duration': 1.5,
          'tracks': {
            'head_pan': [
              {'t': 0, 'value': 0},
              {'t': 1.5, 'value': 60},
            ],
          },
        });
      } catch (_) {
        clipOk = false;
      }
      report('playClip(head_pan)', clipOk);

      var badJoint = false;
      try {
        await _sim.playClip({
          'format': 'lelamp.clip/1',
          'duration': 1.0,
          'tracks': {
            'wrist_roll': [
              {'t': 0, 'value': 0},
            ],
          },
        });
      } catch (_) {
        badJoint = true;
      }
      report('내부 관절 이름은 거부', badJoint);

      // 표정 mp4 가 실제로 디코드되고 흐르는지. 캔버스 픽셀은 로봇이 움직여서 항상
      // 바뀌므로 영상 자체의 currentTime 을 두 번 읽어 비교한다.
      final f1 = await _sim.faceStatus();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      final f2 = await _sim.faceStatus();
      final t1 = (f1['time'] as num?)?.toDouble() ?? -1;
      final t2 = (f2['time'] as num?)?.toDouble() ?? -1;
      final decodeState = (f2['readyState'] as num?)?.toInt() ?? -1;
      final w = (f2['w'] as num?)?.toInt() ?? 0;
      report('표정 영상 디코드', decodeState >= 2 && w > 0, 'readyState=$decodeState ${w}px');
      report('표정 영상 재생중', t2 != t1 && t2 > 0,
          '${t1.toStringAsFixed(2)} → ${t2.toStringAsFixed(2)}s');

      await _sim.stop();
      report('stop', true);
      debugPrint('SELFTEST DONE');
    } catch (e) {
      debugPrint('SELFTEST FAIL · 예외 · $e');
      debugPrint('SELFTEST DONE');
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      setState(() => _log.insert(0, 'throw · $e'));
    }
  }

  Future<void> _capture() => _guard(() async {
        final data = await _sim.capture();
        setState(() {
          _capturePreview = data.isEmpty ? null : data;
          _log.insert(0, 'capture · ${data.length} chars');
        });
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14141A),
      body: SafeArea(
        child: Column(
          children: [
            // 로봇 카드는 채팅 폭 4:3 (PRD 06-4).
            Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: SimView(controller: _sim),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final b in ['greet', 'happy', 'curious', 'sad', 'wake', 'nod'])
                          _Btn(b, () => _guard(() => _sim.playBehavior(b))),
                        _Btn('recipe', () async {
                          await _guard(() => _sim.playRecipe({
                                'steps': [
                                  {'behavior': 'greet', 'speed': 1.2, 'repeat': 2},
                                  {'behavior': 'happy', 'amplitude': 1.1},
                                ],
                              }));
                        }),
                        _Btn('idle doze', () => _guard(() => _sim.setIdle(behavior: 'doze'))),
                        _Btn('idle fast', () => _guard(() => _sim.setIdle(speed: 1.4, amplitude: 1.2))),
                        _Btn('face heart', () => _guard(() => _sim.setFace('heart'))),
                        _Btn('stop', () => _guard(_sim.stop)),
                        _Btn('capture', _capture),
                        _Btn('bad name', () => _guard(() => _sim.playBehavior('moonwalk'))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_capturePreview != null)
                      Container(
                        height: 90,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Image.memory(
                          Uri.parse(_capturePreview!).data!.contentAsBytes(),
                          fit: BoxFit.contain,
                        ),
                      ),
                    for (final line in _log)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          line,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.3,
                            color: line.startsWith('error') || line.startsWith('throw')
                                ? const Color(0xFFEE8888)
                                : const Color(0xFF9AA0AD),
                            fontFamily: 'Menlo',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: const Color(0xFF24242E),
        foregroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12),
      ),
      child: Text(label),
    );
  }
}
