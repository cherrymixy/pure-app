import 'dart:async';

import '../../models/motion_spec.dart';
import '../../models/recipe.dart';
import 'generation_client.dart';

/// 테스트용. 무엇을 돌려줄지, 언제 실패할지를 전부 지정할 수 있다.
///
/// 실제 시계를 쓰지 않는다 — 60초 타임아웃 테스트가 60초를 기다리면 안 된다.
class FakeClient implements GenerationClient {
  FakeClient({
    this.recipe = const Recipe(steps: [RecipeStep(behavior: 'greet')]),
    this.name = 'Fake motion',
    this.face = 'smile',
    this.reasoning = 'Fake reasoning.',
    this.failWith,
    this.delay = Duration.zero,
    this.onGenerate,
  });

  Recipe recipe;
  String name;
  String face;
  String reasoning;

  /// 설정하면 그 실패로 던진다.
  GenerationFailure? failWith;

  Duration delay;

  /// 호출될 때마다 요청을 넘겨준다. 프롬프트 조립 검증에 쓴다.
  void Function(GenerationRequest)? onGenerate;

  /// 키가 없는 OpenAIClient 를 흉내 낼 때 false 로 둔다.
  bool available = true;

  int callCount = 0;
  GenerationRequest? lastRequest;
  bool delayNotified = false;

  @override
  bool get isAvailable => available;

  @override
  Future<GenerationResult> generate(
    GenerationRequest request, {
    CancelToken? cancel,
    void Function()? onDelay,
  }) async {
    callCount++;
    lastRequest = request;
    onGenerate?.call(request);

    if (delay > Duration.zero) {
      await Future.any([
        Future<void>.delayed(delay),
        if (cancel != null) cancel.whenCancelled,
      ]);
    }
    cancel?.throwIfCancelled();

    if (failWith != null) {
      throw GenerationException(failWith!, 'FakeClient 가 의도적으로 실패');
    }

    return GenerationResult(
      spec: MotionSpec(
        id: 'spec.fake.$callCount',
        name: name,
        face: face,
        mode: SpecMode.recipe,
        recipe: recipe,
        reasoning: reasoning,
        signatureSnapshot: request.signature,
        version: (request.previousSpec?.version ?? 0) + 1,
      ),
      source: GenerationSource.fake,
      raw: '{"fake":true}',
    );
  }

  /// 지연 안내 콜백을 수동으로 흉내 낸다.
  void triggerDelay(void Function()? onDelay) {
    delayNotified = true;
    onDelay?.call();
  }
}
