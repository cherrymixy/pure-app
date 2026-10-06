import 'dart:async';

import '../../models/motion_signature.dart';
import '../../models/motion_spec.dart';
import '../../models/saved_motion.dart';

/// 생성 요청.
class GenerationRequest {
  const GenerationRequest({
    required this.signature,
    this.text,
    this.frames = const [],
    this.previousSpec,
    this.feedback,
    this.mode = SpecMode.recipe,
    this.chipId,
    this.whenOptionId,
    this.howOptionId,
    this.situation,
  });

  /// 생성 당시의 시그니처. 결과 [MotionSpec] 에 스냅샷으로 들어간다 (PRD §6-2).
  final MotionSignature signature;

  /// 사용자가 말한 것. 음성은 기기에서 글자로 바뀐 뒤 여기로 온다.
  final String? text;

  /// 영상에서 뽑은 프레임 (data URL, 최대 8장). 비어 있으면 텍스트만.
  final List<String> frames;

  /// 피드백 재생성일 때의 직전 결과.
  final MotionSpec? previousSpec;

  /// "more gently, arms not legs" 같은 수정 요청.
  final String? feedback;

  final SpecMode mode;

  // ---- 데모 폴백이 가장 가까운 레시피를 찾는 데 쓰는 단서 ----

  /// 어느 칩에서 시작했는지.
  final String? chipId;

  /// 질문형 1단계 답.
  final String? whenOptionId;

  /// 질문형 2단계 답.
  final String? howOptionId;

  /// 저장될 반응 상황.
  final Situation? situation;

  bool get hasFrames => frames.isNotEmpty;
  bool get isFeedback => feedback != null && feedback!.trim().isNotEmpty;

  /// 데모 매칭에 쓸 문장. 피드백이면 피드백 문장이 더 가깝다.
  String get matchText => (isFeedback ? feedback : text)?.trim() ?? '';
}

/// 어디서 나온 결과인가. 화면이 "데모 모드" 표시를 고르는 데 쓴다.
enum GenerationSource { openai, ollama, demo, fake }

/// 생성 결과.
class GenerationResult {
  const GenerationResult({
    required this.spec,
    required this.source,
    this.raw = '',
    this.validationReasons = const [],
  });

  final MotionSpec spec;
  final GenerationSource source;

  /// 원문 응답. docs/samples 에 남기고 프롬프트를 튜닝할 때 본다.
  final String raw;

  /// motion_engine 이 고친 내용. 비어 있으면 그대로 통과했다는 뜻.
  final List<String> validationReasons;

  bool get isDemo => source == GenerationSource.demo;
}

/// 생성이 실패한 이유. 화면이 문구를 고르는 데 쓴다.
enum GenerationFailure {
  /// 60초를 넘겼다.
  timeout,

  /// 네트워크가 없거나 끊겼다.
  network,

  /// 키가 없거나 거부당했다.
  auth,

  /// 크레딧이 없거나 사용량 한도를 넘었다. 재시도해도 소용없다.
  quota,

  /// 응답이 왔는데 쓸 수 있는 게 없었다.
  invalidResponse,

  /// 사용자가 새로 전송해서 취소됐다.
  cancelled,

  /// 이 클라이언트가 다룰 수 없는 요청 (예: 영상 프레임을 못 보는 모델).
  /// 다음 폴백으로 넘기라는 뜻이다.
  unsupported,

  /// 그 밖.
  unknown,
}

class GenerationException implements Exception {
  GenerationException(this.failure, [this.message = '']);

  final GenerationFailure failure;
  final String message;

  @override
  String toString() => 'GenerationException(${failure.name}): $message';
}

/// 취소 토큰. 생성 중에 새로 전송하면 이전 요청을 끊는다 (PRD §6-6).
class CancelToken {
  bool _cancelled = false;
  final _completer = Completer<void>();

  bool get isCancelled => _cancelled;

  /// 취소되면 완료된다. `Future.any` 로 대기에 끼워 넣는다.
  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    if (!_completer.isCompleted) _completer.complete();
  }

  /// 취소됐으면 던진다.
  void throwIfCancelled() {
    if (_cancelled) {
      throw GenerationException(GenerationFailure.cancelled, '새 요청이 들어와 취소됨');
    }
  }
}

/// 생성의 전송 계층.
///
/// "GPT 에 물어본다"만 안다. 폴백·검증·취소 **정책**은 [GenerationService] 가 맡는다 —
/// 안 그러면 같은 코드가 구현 세 개에 세 번 들어간다.
abstract class GenerationClient {
  /// 지금 쓸 수 있는가. 키가 없는 OpenAIClient 처럼 미리 알 수 있는 경우를 거른다.
  ///
  /// 서비스가 `Env.hasApiKey` 를 직접 보면 주입한 클라이언트를 무시하게 된다.
  bool get isAvailable => true;

  /// 결과를 만든다. 실패하면 [GenerationException] 을 던진다.
  ///
  /// [onDelay] 는 20초가 지났을 때 한 번 불린다 (06-3 지연 안내).
  Future<GenerationResult> generate(
    GenerationRequest request, {
    CancelToken? cancel,
    void Function()? onDelay,
  });
}
