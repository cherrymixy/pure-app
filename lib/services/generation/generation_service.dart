import 'dart:async';

import '../../models/motion_spec.dart';
import '../motion_engine.dart';
import 'demo_client.dart';
import 'generation_client.dart';
import 'ollama_client.dart';
import 'openai_client.dart';

/// 생성의 **정책** 계층.
///
/// 클라이언트는 전송만 안다. "네트워크가 죽으면 데모로 간다 / 결과는 반드시
/// motion_engine 을 통과한다 / 시그니처를 미리 반영한다 / 새 요청이 오면 이전을
/// 취소한다" 는 전부 여기 모인다. 구현 세 개에 같은 코드를 세 번 넣지 않기 위해서다.
///
/// **이 서비스는 실패를 던지지 않는다.** 무슨 일이 있어도 데모 레시피로 답을 만든다
/// (docs/conventions.md 규칙 11). 호출부가 실패를 다뤄야 하는 경우는 취소뿐이다.
class GenerationService {
  GenerationService({
    GenerationClient? primary,
    GenerationClient? secondary,
    GenerationClient? fallback,
    this.forceDemo = false,
  })  : _primary = primary ?? OpenAIClient(),
        _secondary = secondary ?? OllamaClient(),
        _fallback = fallback ?? DemoClient();

  final GenerationClient _primary;

  /// 1차가 안 될 때 한 번 더 시도하는 곳 — 맥에서 도는 로컬 모델 (승아 결정).
  /// 주소가 없으면 `isAvailable` 이 false 라 그냥 건너뛴다.
  final GenerationClient _secondary;

  final GenerationClient _fallback;

  /// 강제 데모 모드 (로봇 이름 5번 탭). 설정에서 읽어 넣는다.
  bool forceDemo;

  CancelToken? _inFlight;

  /// 지금 생성 중인가.
  bool get isGenerating => _inFlight != null && !_inFlight!.isCancelled;

  /// 1차 클라이언트를 쓸 수 있는 상태인가. 화면의 데모 배지에 쓴다.
  bool get canUseOpenAI => _primary.isAvailable && !forceDemo;

  /// 진짜 생성을 시도할 곳이 하나라도 있는가.
  bool get canGenerate =>
      !forceDemo && (_primary.isAvailable || _secondary.isAvailable);

  /// 진행 중인 요청을 취소한다 (생성 중 새 전송 — PRD §6-6).
  void cancelInFlight() {
    _inFlight?.cancel();
    _inFlight = null;
  }

  /// 모션을 만든다.
  ///
  /// [onDelay] 는 20초가 지나면 한 번 불린다 (06-3 지연 안내).
  /// 취소되면 [GenerationException] (cancelled) 를 던진다 — 그 외에는 던지지 않는다.
  Future<GenerationResult> generate(
    GenerationRequest request, {
    void Function()? onDelay,
  }) async {
    cancelInFlight();
    final token = CancelToken();
    _inFlight = token;

    try {
      /*
       * 3단 폴백 (승아 결정):
       *   OpenAI → 로컬 모델(Ollama) → 데모
       * 앞의 것이 무슨 이유로든 실패하면 다음으로 내려간다. 취소만 그대로 던진다.
       * 셋 다 못 쓰면 데모가 받으므로 이 함수는 끝내 실패하지 않는다 (규칙 11).
       */
      GenerationResult? result;
      if (!forceDemo) {
        for (final client in [_primary, _secondary]) {
          if (!client.isAvailable) continue;
          try {
            result = await client.generate(
              request,
              cancel: token,
              onDelay: onDelay,
            );
            break;
          } on GenerationException catch (e) {
            if (e.failure == GenerationFailure.cancelled) rethrow;
          } catch (_) {
            // 다음 후보로.
          }
        }
      }
      result ??= await _fallback.generate(request, cancel: token);

      token.throwIfCancelled();
      return _finish(result, request);
    } finally {
      if (identical(_inFlight, token)) _inFlight = null;
    }
  }

  /// 검증 + 시그니처 반영. 검증에서 떨어지면 데모로 한 번 더 간다.
  Future<GenerationResult> _finish(
    GenerationResult result,
    GenerationRequest request,
  ) async {
    final validated = MotionEngine.validateRecipe(result.spec.recipe);

    if (!validated.ok) {
      // GPT 가 쓸 수 없는 걸 냈다. 데모로 대체한다 — 화면에는 뭔가가 나와야 한다.
      if (result.source != GenerationSource.demo) {
        final demo = await _fallback.generate(request);
        return _finish(demo, request);
      }
      // 데모조차 떨어지면 데이터가 깨진 것이다. 이건 테스트가 막는다.
      throw GenerationException(
        GenerationFailure.invalidResponse,
        '데모 레시피까지 검증에 실패: ${validated.reasons.join(', ')}',
      );
    }

    final params = MotionEngine.signatureToParams(request.signature);

    // 시그니처를 레시피에 미리 곱해 넣는다. 재생할 때 배율을 또 넘기면 두 번 곱해져
    // 관절 범위를 크게 넘는다 (STEP 6 참고).
    final withSignature = MotionEngine.applySignature(validated.value!, params);

    final name = result.spec.name.trim().isEmpty
        ? MotionEngine.suggestName(
            situation: request.situation,
            lastUserText: request.text,
          )
        : result.spec.name.trim();

    return GenerationResult(
      spec: result.spec.copyWith(
        name: name.length > 20 ? name.substring(0, 20).trim() : name,
        recipe: withSignature,
        signatureSnapshot: request.signature,
      ),
      source: result.source,
      raw: result.raw,
      validationReasons: validated.reasons,
    );
  }

  /// 질문형 3단계의 "Softer" — 다시 생성하지 않고 한 단계 낮춘다.
  MotionSpec soften(MotionSpec spec) =>
      spec.copyWith(recipe: MotionEngine.applySoftener(spec.recipe));

  void dispose() {
    cancelInFlight();
    final primary = _primary;
    if (primary is OpenAIClient) primary.dispose();
    final secondary = _secondary;
    if (secondary is OllamaClient) secondary.dispose();
  }
}
