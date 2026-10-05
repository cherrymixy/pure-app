import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/env.dart';
import '../../data/behaviors.dart';
import '../../models/motion_signature.dart';
import '../../models/motion_spec.dart';
import '../../models/recipe.dart';
import '../../data/signature_options.dart';
import 'generation_client.dart';

/// OpenAI 호출.
///
/// 서버가 없다. 앱이 직접 부른다. 키는 `--dart-define` 으로만 들어오고 코드·git·로그에
/// 남지 않는다 (CLAUDE.md 규칙 12).
class OpenAIClient implements GenerationClient {
  OpenAIClient({http.Client? httpClient, this.endpoint = _defaultEndpoint})
      : _http = httpClient ?? http.Client();

  static const String _defaultEndpoint = 'https://api.openai.com/v1/chat/completions';

  final http.Client _http;
  final String endpoint;

  /// 20초에 지연 안내, 60초에 실패 (PRD §6-6).
  static const Duration delayNotice = Duration(seconds: 20);
  static const Duration hardTimeout = Duration(seconds: 60);

  /// 네트워크 오류 재시도 간격.
  static const List<Duration> retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  /// 키가 없으면 부를 가치가 없다.
  @override
  bool get isAvailable => Env.hasApiKey;

  @override
  Future<GenerationResult> generate(
    GenerationRequest request, {
    CancelToken? cancel,
    void Function()? onDelay,
  }) async {
    if (!Env.hasApiKey) {
      throw GenerationException(GenerationFailure.auth, 'API 키가 없습니다');
    }
    cancel?.throwIfCancelled();

    Timer? delayTimer;
    if (onDelay != null) delayTimer = Timer(delayNotice, onDelay);

    try {
      final body = _buildBody(request);
      final raw = await _postWithRetry(body, cancel: cancel)
          .timeout(hardTimeout, onTimeout: () {
        throw GenerationException(GenerationFailure.timeout, '60초를 넘겼습니다');
      });
      cancel?.throwIfCancelled();
      return _parse(raw, request);
    } finally {
      delayTimer?.cancel();
    }
  }

  // ---------------------------------------------------------------- 전송

  Future<String> _postWithRetry(Map<String, Object?> body, {CancelToken? cancel}) async {
    Object? lastError;
    for (var attempt = 0; attempt <= retryDelays.length; attempt++) {
      cancel?.throwIfCancelled();
      try {
        final res = await _http.post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${Env.apiKey}',
          },
          body: jsonEncode(body),
        );

        if (res.statusCode == 401 || res.statusCode == 403) {
          throw GenerationException(GenerationFailure.auth, 'HTTP ${res.statusCode}');
        }
        if (res.statusCode >= 500 || res.statusCode == 429) {
          // 서버 쪽 문제 — 재시도할 값어치가 있다.
          lastError = GenerationException(
            GenerationFailure.network,
            'HTTP ${res.statusCode}',
          );
        } else if (res.statusCode >= 400) {
          throw GenerationException(
            GenerationFailure.invalidResponse,
            'HTTP ${res.statusCode}: ${_short(res.body)}',
          );
        } else {
          return utf8.decode(res.bodyBytes);
        }
      } on GenerationException {
        rethrow;
      } catch (e) {
        lastError = e;
      }

      if (attempt < retryDelays.length) {
        await Future<void>.delayed(retryDelays[attempt]);
      }
    }
    throw GenerationException(
      GenerationFailure.network,
      lastError?.toString() ?? '네트워크 오류',
    );
  }

  static String _short(String s) => s.length > 200 ? '${s.substring(0, 200)}…' : s;

  // ---------------------------------------------------------------- 요청 본문

  Map<String, Object?> _buildBody(GenerationRequest r) {
    final useVision = r.hasFrames;
    return {
      'model': useVision ? Env.visionModel : Env.model,
      'temperature': 0.8,
      'max_tokens': 800,
      'response_format': responseFormat,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': _userContent(r)},
      ],
    };
  }

  /// 텍스트만이면 문자열, 프레임이 있으면 블록 배열.
  Object _userContent(GenerationRequest r) {
    final preamble = _userText(r);
    if (!r.hasFrames) return preamble;
    return [
      {'type': 'text', 'text': preamble},
      for (final f in r.frames)
        {
          'type': 'image_url',
          'image_url': {'url': f},
        },
    ];
  }

  String _userText(GenerationRequest r) {
    final b = StringBuffer();
    b.writeln(describeSignature(r.signature));
    b.writeln();

    if (r.isFeedback && r.previousSpec != null) {
      b.writeln('You already made this motion:');
      b.writeln(jsonEncode({
        'name': r.previousSpec!.name,
        'face': r.previousSpec!.face,
        'steps': r.previousSpec!.recipe.steps.map((s) => s.toJson()).toList(),
      }));
      b.writeln();
      b.writeln('Change it based on this note, and keep everything else:');
      b.writeln('"${r.feedback!.trim()}"');
    } else {
      final text = r.text?.trim();
      if (r.hasFrames) {
        b.writeln(
          r.frames.length > 1
              ? 'These ${r.frames.length} frames are in order from a short video. '
                  'Read what changes between them — that tells you how fast and how '
                  'big the movement should be.'
              : 'Read this image: the scene, who is in it, and the mood.',
        );
        if (text != null && text.isNotEmpty) {
          b.writeln();
          b.writeln('What the person also said: "$text"');
        }
      } else {
        b.writeln('What just happened: "${text ?? ''}"');
      }
    }
    return b.toString().trim();
  }

  /// 시그니처를 사람이 읽는 문장으로. 추상적인 숫자보다 결과가 좋다.
  static String describeSignature(MotionSignature s) {
    final p = personalityFor(s);
    final rel = relationshipFor(s.relationship);
    final exp = expressionFor(s.expression);
    return 'This robot\'s personality: ${p.label} — ${p.description}. '
        'It ${rel.label.toLowerCase()} (${rel.description.toLowerCase()}). '
        'Its movement is ${exp.label.toLowerCase()} — ${exp.description.toLowerCase()}.';
  }

  // ---------------------------------------------------------------- 프롬프트

  /// 시스템 프롬프트.
  ///
  /// 참고 레포(`_ref/pure-web/app/api/analyze/route.ts`)에서 계승한 것은 셋뿐이다:
  /// 제품 고정 제약, 프레임 시퀀스 읽기, 맥락→상태→움직임의 추론 사슬. 출력 스키마와
  /// 상태 차원은 완전히 다르므로 새로 썼고, 언어도 영어로 바꿨다 (reasoning 이 화면에
  /// 노출되는데 UI 가 영어다).
  static final String systemPrompt = _buildSystemPrompt();

  static String _buildSystemPrompt() {
    final behaviors = kBehaviors
        .map((b) => '  $b — ${kBehaviorDescriptions[b]}')
        .join('\n');
    final faces = kFaces.map((f) => '  $f — ${kFaceDescriptions[f]}').join('\n');

    return '''
You design motion for PURE Desk, a small desk robot.

THE ROBOT IS FIXED. It has five joints (a turning base, a shoulder, an elbow, and a head
that pans and tilts) and a small screen for a face. It cannot walk, roll, speak, grab, or
light up. Never invent a new capability, a new behavior name, or a new product. You only
arrange what already exists.

HOW TO THINK
Context -> inner state -> movement. First read what just happened. Then decide what the
robot would feel about it. Only then choose the movements that would show that feeling to
someone watching from across a desk.

WHAT YOU CHOOSE FROM
Behaviors:
$behaviors

Faces:
$faces

READING INPUT
The person may describe the situation in words, show you a single image, or show you a
sequence of frames taken from a short video. With a sequence, compare the frames: how much
things move between them tells you how fast and how large the robot's movement should be.
A still scene calls for a small, slow motion; a busy one calls for a quick, large one.

RULES FOR YOUR ANSWER
- steps: 1 to 6. Each step is one behavior. Order them so they read as one continuous
  reaction, not a list. Two or three steps is usually enough.
- speed: 0.5 (slow) to 1.6 (fast). amplitude: 0.4 (small) to 1.5 (large).
- repeat: 1 to 4. Use more than 1 only when repeating actually reads as insistence or
  excitement.
- face on a step changes the expression at that moment; leave it null to keep the
  behavior's own face.
- face at the top level is the expression the robot settles into.
- name: 1 to 20 characters, English, what a person would call this motion. Plain words,
  no quotes, no emoji. For example "Welcome home" or "Shy nod".
- reasoning: one or two sentences of English, written for the person who will read it on
  their phone. Say what you understood about the situation and why the robot moves this
  way. Do not list the step names back.
- Match the robot's personality given below. A calm robot should not bounce; a bold one
  should not shrink.
''';
  }

  // ---------------------------------------------------------------- 스키마

  /// 구조화 출력 스키마.
  ///
  /// `strict: true` 는 minimum/maximum/maxItems 를 **지원하지 않는다**. 범위는 전부
  /// 파싱 후 `motion_engine.validateRecipe` 가 강제한다. 또 모든 property 가
  /// required 여야 해서 선택 필드 face 는 `["string","null"]` 로 선언한다.
  static Map<String, Object?> get responseFormat => {
        'type': 'json_schema',
        'json_schema': {
          'name': 'pure_motion',
          'strict': true,
          'schema': {
            'type': 'object',
            'additionalProperties': false,
            'properties': {
              'name': {'type': 'string'},
              'face': {'type': 'string', 'enum': kFaces},
              'reasoning': {'type': 'string'},
              'steps': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'additionalProperties': false,
                  'properties': {
                    'behavior': {'type': 'string', 'enum': kBehaviors},
                    'speed': {'type': 'number'},
                    'amplitude': {'type': 'number'},
                    'repeat': {'type': 'integer'},
                    'face': {
                      'type': ['string', 'null'],
                      'enum': [...kFaces, null],
                    },
                  },
                  'required': ['behavior', 'speed', 'amplitude', 'repeat', 'face'],
                },
              },
            },
            'required': ['name', 'face', 'reasoning', 'steps'],
          },
        },
      };

  // ---------------------------------------------------------------- 파싱

  GenerationResult _parse(String raw, GenerationRequest request) {
    Map<String, Object?> envelope;
    try {
      envelope = jsonDecode(raw) as Map<String, Object?>;
    } catch (_) {
      throw GenerationException(GenerationFailure.invalidResponse, '응답이 JSON 이 아닙니다');
    }

    final choices = envelope['choices'] as List?;
    Map<String, Object?>? message;
    if (choices != null && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map) {
        final m = first['message'];
        if (m is Map) message = m.cast<String, Object?>();
      }
    }

    final content = message?['content'];
    if (content is! String || content.trim().isEmpty) {
      final refusal = message?['refusal'];
      throw GenerationException(
        GenerationFailure.invalidResponse,
        refusal == null ? '응답 본문이 비었습니다' : '모델이 거절했습니다: $refusal',
      );
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

    return GenerationResult(spec: spec, source: GenerationSource.openai, raw: raw);
  }

  void dispose() => _http.close();
}
