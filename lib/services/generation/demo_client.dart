import 'dart:async';

import '../../models/motion_spec.dart';
import '../motion_engine.dart';
import 'generation_client.dart';

/// 네트워크·키 없이 도는 길.
///
/// 입력을 키워드로 매칭해 가장 가까운 데모 레시피를 돌려준다. **절대 실패하지 않는다** —
/// 전시장 와이파이가 죽어도 시연 경로는 살아 있어야 한다 (docs/conventions.md 규칙 11).
class DemoClient implements GenerationClient {
  DemoClient({this.thinkingDelay = const Duration(milliseconds: 1500)});

  /// 생성 중 연출을 유지할 시간. 즉시 돌려주면 "점 3개"가 깜빡이기만 한다.
  final Duration thinkingDelay;

  /// 데모는 언제나 쓸 수 있다 — 그게 존재 이유다.
  @override
  bool get isAvailable => true;

  @override
  Future<GenerationResult> generate(
    GenerationRequest request, {
    CancelToken? cancel,
    void Function()? onDelay,
  }) async {
    if (thinkingDelay > Duration.zero) {
      await Future.any([
        Future<void>.delayed(thinkingDelay),
        if (cancel != null) cancel.whenCancelled,
      ]);
    }
    cancel?.throwIfCancelled();

    final previous = request.previousSpec;
    final wantsSofter = _wantsSofter(request.feedback);

    // 피드백이면 **같은 레시피**가 기준이다 (PRD §6-7). 피드백 문장으로 다시 매칭하면
    // "use the arms" 같은 말이 엉뚱한 레시피를 끌어온다.
    if (request.isFeedback && previous != null) {
      return GenerationResult(
        spec: previous.copyWith(
          id: 'spec.demo.${_stamp()}',
          recipe: wantsSofter ? MotionEngine.applySoftener(previous.recipe) : previous.recipe,
          signatureSnapshot: request.signature,
          version: previous.version + 1,
        ),
        source: GenerationSource.demo,
        raw: 'feedback:${wantsSofter ? 'softer' : 'same'}',
      );
    }

    final demo = MotionEngine.demoMatch(
      request.matchText,
      chipId: request.chipId,
      whenOptionId: request.whenOptionId,
      howOptionId: request.howOptionId,
      situation: request.situation,
    );

    final spec = MotionSpec(
      id: 'spec.demo.${_stamp()}',
      name: demo.name,
      face: demo.face,
      mode: SpecMode.recipe,
      recipe: wantsSofter ? MotionEngine.applySoftener(demo.recipe) : demo.recipe,
      reasoning: demo.reasoning,
      signatureSnapshot: request.signature,
      version: (previous?.version ?? 0) + 1,
    );

    return GenerationResult(spec: spec, source: GenerationSource.demo, raw: demo.id);
  }

  static String _stamp() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  static const List<String> _softerWords = [
    'softer', 'soft', 'slower', 'slow', 'gently', 'gentle',
    'smaller', 'calmer', 'quieter', 'less',
  ];

  static bool _wantsSofter(String? feedback) {
    if (feedback == null) return false;
    final f = feedback.toLowerCase();
    return _softerWords.any(f.contains);
  }
}
