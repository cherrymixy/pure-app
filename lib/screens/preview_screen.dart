import 'dart:async';

import 'package:flutter/material.dart';

import '../models/motion_spec.dart';
import '../sim/sim_controller.dart';
import '../sim/sim_host.dart';

/// 06-FS 전체 화면 미리보기 — 드래그 회전 · 반복 토글 · 아래로 쓸어 닫기.
///
/// 시뮬레이터 인스턴스는 하나뿐이라 새로 만들지 않는다. [SimSlot] 의 priority 를
/// 카드(0)보다 높게(10) 둬서, 이 화면이 떠 있는 동안 시뮬레이터가 여기로 옮겨 온다.
class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key, required this.spec});

  final MotionSpec spec;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  bool _loop = true;
  bool _playing = true;
  StreamSubscription<SimEvent>? _sub;

  SimController get _sim => SimHost.controllerOf(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _sub = _sim.events.listen((e) {
        if (e is SimEnded && mounted) {
          if (_loop) {
            _play();
          } else {
            setState(() => _playing = false);
          }
        }
      });
      // 드래그로 돌려 볼 수 있게.
      await _sim.enableOrbit(true);
      await _play();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    // 돌아가면 카드에서는 회전이 꺼져 있어야 한다.
    unawaited(_sim.enableOrbit(false));
    super.dispose();
  }

  Future<void> _play() async {
    if (!mounted) return;
    setState(() => _playing = true);
    try {
      await _sim.playRecipe(widget.spec.recipe.toJson());
      await _sim.setFace(widget.spec.face);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0D),
      body: GestureDetector(
        // 아래로 쓸면 닫는다.
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 300) Navigator.pop(context);
        },
        child: Stack(
          children: [
            const Positioned.fill(child: SimSlot(priority: 10)),
            SafeArea(
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Repeat',
                        icon: Icon(
                          Icons.repeat,
                          color: _loop ? Colors.white : Colors.white38,
                        ),
                        onPressed: () => setState(() => _loop = !_loop),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Row(
                      children: [
                        IconButton.filled(
                          onPressed: _toggle,
                          icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.spec.name,
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
