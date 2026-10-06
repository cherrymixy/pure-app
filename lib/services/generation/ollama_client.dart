import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/env.dart';
import '../../models/motion_spec.dart';
import '../../models/recipe.dart';
import 'generation_client.dart';
import 'openai_client.dart';

/// 맥에서 도는 로컬 모델(Ollama) 호출.
///
/// OpenAI 와 **같은 프롬프트·같은 스키마**를 쓴다 ([OpenAIClient.systemPrompt],
/// [OpenAIClient.userText], [OpenAIClient.jsonSchema]). 다른 것은 셋뿐이다:
///  - 엔드포인트가 `/api/chat` 이고 키가 없다
///  - 스키마를 `response_format` 이 아니라 `format` 에 그대로 넣는다
///  - 응답이 `choices[0].message` 가 아니라 `message` 하나다
///
/// **영상은 보지 못한다.** 받아 둔 모델(qwen3 · exaone3.5)이 텍스트 전용이라,
/// 프레임이 붙은 요청은 [GenerationFailure.unsupported] 로 돌려보내 다음 폴백
/// (데모)이 받게 한다. 눈이 없는 모델에 "영상을 봤다" 고 답하게 두는 것보다 낫다.
class OllamaClient implements GenerationClient {
  OllamaClient({http.Client? httpClient, String? host, String? model})
      : _http = httpClient ?? http.Client(),
        host = host ?? Env.ollamaHost,
        model = model ?? Env.ollamaModel;

  final http.Client _http;

  /// `http://localhost:11434` 꼴. 비어 있으면 쓰지 않는다.
  final String host;

  final String model;

  /// 로컬 모델은 OpenAI 보다 느리다 — 8B 가 7~10초, 4B 가 3~5초다.
  static const Duration delayNotice = Duration(seconds: 20);
  static const Duration hardTimeout = Duration(seconds: 90);

  @override
  bool get isAvailable => host.isNotEmpty;

  @override
  Future<GenerationResult> generate(
    GenerationRequest request, {
    CancelToken? cancel,
    void Function()? onDelay,
  }) async {
    if (!isAvailable) {
      throw GenerationException(GenerationFailure.unsupported, 'OLLAMA_HOST 가 없습니다');
    }
    if (request.hasFrames) {
      throw GenerationException(
        GenerationFailure.unsupported,
        '로컬 모델은 영상 프레임을 보지 못합니다',
      );
    }
    cancel?.throwIfCancelled();

    Timer? delayTimer;
    if (onDelay != null) delayTimer = Timer(delayNotice, onDelay);

    try {
      final raw = await _post(request, cancel: cancel).timeout(
        hardTimeout,
        onTimeout: () {
          throw GenerationException(
            GenerationFailure.timeout,
            '${hardTimeout.inSeconds}초를 넘겼습니다',
          );
        },
      );
      cancel?.throwIfCancelled();
      return _parse(raw, request);
    } finally {
      delayTimer?.cancel();
    }
  }

  /// 로컬 모델에 덧붙이는 지침.
  ///
  /// 작은 모델은 `reasoning` 에 "User expressed tiredness, so robot should…" 처럼
  /// 자기 판단 과정을 적고, `name` 에 `pure_desk` 같은 식별자를 넣는다. 둘 다
  /// 화면에 그대로 보이는 값이라 못 쓴다. OpenAI 프롬프트는 건드리지 않고 여기서만
  /// 덧댄다.
  ///
  /// **예문은 넣지 않는다.** 한 번 넣어 봤더니 모델이 그 문장을 그대로 베껴
  /// 상황과 맞지 않는 설명이 화면에 나왔다. 규칙만 적는다.
  static const String _localExtra =
      'Two more rules, they matter:\n'
      '- "name": two or three everyday words, the way the owner would name it. '
      'No identifiers, no underscores, no product or robot names.\n'
      '- "reasoning": exactly one short sentence, told to the owner, describing '
      'what the robot does for THIS moment. Do not restate the request. Do not '
      'mention behavior names, speed, amplitude, or why you chose them. Do not '
      'copy any sentence from these instructions.';

  Future<String> _post(GenerationRequest r, {CancelToken? cancel}) async {
    cancel?.throwIfCancelled();

    final body = {
      'model': model,
      'stream': false,
      // Ollama 는 JSON Schema 를 그대로 받는다 (0.5+).
      'format': OpenAIClient.jsonSchema,
      // qwen3 류의 생각 과정을 끈다 — 느리기만 하고 결과는 어차피 JSON 이다.
      'think': false,
      'options': {'temperature': 0.8},
      'messages': [
        {'role': 'system', 'content': '${OpenAIClient.systemPrompt}\n\n$_localExtra'},
        {'role': 'user', 'content': OpenAIClient.userText(r)},
      ],
    };

    final http.Response res;
    try {
      res = await _http.post(
        Uri.parse('$host/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (e) {
      // 맥이 꺼져 있거나 다른 Wi-Fi 다. 재시도해도 같다.
      throw GenerationException(GenerationFailure.network, '$e');
    }

    if (res.statusCode == 404) {
      // 모델을 안 받아 뒀다.
      throw GenerationException(
        GenerationFailure.unsupported,
        '$model 모델이 없습니다 (ollama pull $model)',
      );
    }
    if (res.statusCode >= 400) {
      throw GenerationException(
        GenerationFailure.invalidResponse,
        'HTTP ${res.statusCode}',
      );
    }
    return utf8.decode(res.bodyBytes);
  }

  GenerationResult _parse(String raw, GenerationRequest request) {
    Map<String, Object?> envelope;
    try {
      envelope = jsonDecode(raw) as Map<String, Object?>;
    } catch (_) {
      throw GenerationException(GenerationFailure.invalidResponse, '응답이 JSON 이 아닙니다');
    }

    final message = envelope['message'];
    final content = message is Map ? message['content'] : null;
    if (content is! String || content.trim().isEmpty) {
      throw GenerationException(GenerationFailure.invalidResponse, '응답 본문이 비었습니다');
    }

    Map<String, Object?> parsed;
    try {
      parsed = jsonDecode(content) as Map<String, Object?>;
    } catch (_) {
      throw GenerationException(GenerationFailure.invalidResponse, '본문이 JSON 이 아닙니다');
    }

    final steps = ((parsed['steps'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => RecipeStep.fromJson(e.cast<String, Object?>()))
        .toList();

    if (steps.isEmpty) {
      throw GenerationException(GenerationFailure.invalidResponse, 'steps 가 비었습니다');
    }

    final spec = MotionSpec(
      id: 'spec.${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
      name: (parsed['name'] as String? ?? '').trim(),
      face: parsed['face'] as String? ?? 'neutral',
      mode: SpecMode.recipe,
      recipe: Recipe(steps: steps),
      reasoning: (parsed['reasoning'] as String? ?? '').trim(),
      signatureSnapshot: request.signature,
      version: (request.previousSpec?.version ?? 0) + 1,
    );

    return GenerationResult(spec: spec, source: GenerationSource.ollama, raw: raw);
  }

  void dispose() => _http.close();
}
