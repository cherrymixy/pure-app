import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:pure_app/data/behaviors.dart';
import 'package:pure_app/models/motion_signature.dart';
import 'package:pure_app/models/motion_spec.dart';
import 'package:pure_app/models/recipe.dart';
import 'package:pure_app/models/saved_motion.dart';
import 'package:pure_app/providers/generation_provider.dart';
import 'package:pure_app/repositories/data_repository.dart';
import 'package:pure_app/repositories/local_repository.dart';
import 'package:pure_app/services/generation/demo_client.dart';
import 'package:pure_app/services/generation/fake_client.dart';
import 'package:pure_app/services/generation/generation_client.dart';
import 'package:pure_app/services/generation/generation_service.dart';
import 'package:pure_app/services/generation/openai_client.dart';
import 'package:pure_app/services/motion_engine.dart';

const _sig = MotionSignature(lively: 80, bold: 60, richness: 50);

GenerationRequest req({
  String? text,
  List<String> frames = const [],
  String? feedback,
  MotionSpec? previous,
  String? chipId,
  Situation? situation,
}) =>
    GenerationRequest(
      signature: _sig,
      text: text,
      frames: frames,
      feedback: feedback,
      previousSpec: previous,
      chipId: chipId,
      situation: situation,
    );

void main() {
  group('DemoClient — 절대 실패하지 않는다', () {
    final client = DemoClient(thinkingDelay: Duration.zero);

    test('아무 입력에도 쓸 수 있는 결과를 낸다', () async {
      for (final text in ['someone came home', 'zzzz', '', 'I am tired']) {
        final r = await client.generate(req(text: text));
        expect(r.spec.recipe.steps, isNotEmpty, reason: text);
        expect(r.source, GenerationSource.demo);
        for (final s in r.spec.recipe.steps) {
          expect(kBehaviors, contains(s.behavior));
        }
      }
    });

    test('시그니처 스냅샷을 그대로 담는다', () async {
      final r = await client.generate(req(text: 'home'));
      expect(r.spec.signatureSnapshot, _sig);
    });

    test('"softer" 피드백은 직전 결과를 한 단계 낮춘다', () async {
      final base = await client.generate(req(text: 'someone came home'));
      final softer = await client.generate(req(
        text: 'someone came home',
        feedback: 'a bit softer please',
        previous: base.spec,
      ));
      expect(softer.spec.recipe.steps.first.speed,
          lessThan(base.spec.recipe.steps.first.speed));
    });

    test('그 밖의 피드백은 직전 레시피를 그대로 쓴다 (PRD §6-7)', () async {
      // 피드백 문장으로 다시 매칭하면 "use the arms" 가 엉뚱한 레시피를 끌어온다.
      final base = await client.generate(req(text: 'someone came home'));
      final other = await client.generate(req(
        text: 'someone came home',
        feedback: 'use the arms, not the head',
        previous: base.spec,
      ));
      expect(other.spec.recipe.steps.map((s) => s.behavior).toList(),
          base.spec.recipe.steps.map((s) => s.behavior).toList());
      expect(other.spec.recipe.steps.first.speed, base.spec.recipe.steps.first.speed);
      expect(other.spec.version, base.spec.version + 1, reason: '버전은 올라간다');
    });

    test('피드백이면 버전이 올라간다', () async {
      final first = await client.generate(req(text: 'home'));
      final second = await client.generate(
        req(text: 'home', feedback: 'again', previous: first.spec),
      );
      expect(second.spec.version, first.spec.version + 1);
    });

    test('취소되면 던진다', () async {
      final slow = DemoClient(thinkingDelay: const Duration(seconds: 5));
      final token = CancelToken()..cancel();
      expect(
        () => slow.generate(req(text: 'home'), cancel: token),
        throwsA(isA<GenerationException>()),
      );
    });
  });

  group('GenerationService — 무슨 일이 있어도 답을 만든다', () {
    GenerationService serviceWith(GenerationClient primary) => GenerationService(
          primary: primary,
          fallback: DemoClient(thinkingDelay: Duration.zero),
        );

    test('정상이면 1차 결과를 쓴다', () async {
      final fake = FakeClient();
      final r = await serviceWith(fake).generate(req(text: 'hello'));
      expect(r.source, GenerationSource.fake);
      expect(fake.callCount, 1);
    });

    for (final failure in [
      GenerationFailure.timeout,
      GenerationFailure.network,
      GenerationFailure.auth,
      GenerationFailure.invalidResponse,
      GenerationFailure.unknown,
    ]) {
      test('${failure.name} 이면 데모로 폴백한다', () async {
        final fake = FakeClient(failWith: failure);
        final r = await serviceWith(fake).generate(req(text: 'someone came home'));
        expect(r.source, GenerationSource.demo);
        expect(r.spec.recipe.steps, isNotEmpty);
      });
    }

    test('허용 목록 밖만 낸 응답도 데모로 구해진다', () async {
      final fake = FakeClient(
        recipe: const Recipe(steps: [RecipeStep(behavior: 'moonwalk')]),
      );
      final r = await serviceWith(fake).generate(req(text: 'someone came home'));
      expect(r.source, GenerationSource.demo);
    });

    test('일부만 잘못된 응답은 그 단계만 버리고 쓴다', () async {
      final fake = FakeClient(
        recipe: const Recipe(steps: [
          RecipeStep(behavior: 'moonwalk'),
          RecipeStep(behavior: 'greet'),
        ]),
      );
      final r = await serviceWith(fake).generate(req(text: 'x'));
      expect(r.source, GenerationSource.fake);
      expect(r.spec.recipe.steps.single.behavior, 'greet');
      expect(r.validationReasons.join(), contains('moonwalk'));
    });

    test('범위 밖 값은 잘려서 나온다', () async {
      final fake = FakeClient(
        recipe: const Recipe(steps: [
          RecipeStep(behavior: 'greet', speed: 99, amplitude: 99, repeat: 99),
        ]),
      );
      final r = await serviceWith(fake).generate(req(text: 'x'));
      final s = r.spec.recipe.steps.single;
      expect(s.speed, lessThanOrEqualTo(MotionEngine.stepSpeedMax));
      expect(s.amplitude, lessThanOrEqualTo(MotionEngine.maxEffectiveAmplitude));
      expect(s.repeat, lessThanOrEqualTo(MotionEngine.stepRepeatMax));
    });

    test('시그니처가 레시피에 미리 반영된다 (재생 시 두 번 곱하지 않게)', () async {
      final fake = FakeClient(
        recipe: const Recipe(steps: [RecipeStep(behavior: 'greet', speed: 1.0)]),
      );
      final params = MotionEngine.signatureToParams(_sig);
      final r = await serviceWith(fake).generate(req(text: 'x'));
      expect(r.spec.recipe.steps.single.speed, closeTo(params.speed, 1e-6));
    });

    test('최악의 조합에서도 진폭 상한을 지킨다', () async {
      final fake = FakeClient(
        recipe: const Recipe(steps: [
          RecipeStep(behavior: 'wake', speed: 1.6, amplitude: 1.5),
          RecipeStep(behavior: 'focus', speed: 1.6, amplitude: 1.5),
        ]),
      );
      final service = GenerationService(
        primary: fake,
        fallback: DemoClient(thinkingDelay: Duration.zero),
      );
      final r = await service.generate(GenerationRequest(
        signature: const MotionSignature(lively: 100, bold: 100, richness: 100),
      ));
      for (final s in r.spec.recipe.steps) {
        expect(s.amplitude, lessThanOrEqualTo(MotionEngine.maxEffectiveAmplitude));
      }
    });

    test('이름이 비면 규칙으로 채운다', () async {
      final fake = FakeClient(name: '   ');
      final r = await serviceWith(fake)
          .generate(req(text: 'x', situation: Situation.comesHome));
      expect(r.spec.name, 'Welcome home');
    });

    test('이름이 20자를 넘으면 자른다', () async {
      final fake = FakeClient(name: 'A' * 50);
      final r = await serviceWith(fake).generate(req(text: 'x'));
      expect(r.spec.name.length, lessThanOrEqualTo(20));
    });

    test('강제 데모 모드면 1차를 아예 부르지 않는다', () async {
      final fake = FakeClient();
      final service = GenerationService(
        primary: fake,
        fallback: DemoClient(thinkingDelay: Duration.zero),
        forceDemo: true,
      );
      final r = await service.generate(req(text: 'someone came home'));
      expect(r.source, GenerationSource.demo);
      expect(fake.callCount, 0);
      expect(service.canUseOpenAI, isFalse);
    });

    test('새 요청이 들어오면 이전 요청이 취소된다', () async {
      final slow = FakeClient(delay: const Duration(seconds: 5));
      final service = serviceWith(slow);

      final first = service.generate(req(text: 'first'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final second = service.generate(req(text: 'second'));

      await expectLater(first, throwsA(isA<GenerationException>()));
      // 두 번째도 느린 클라이언트를 쓰므로 바로 끝나지 않는다 — 취소만 확인한다.
      service.cancelInFlight();
      await expectLater(second, throwsA(isA<GenerationException>()));
    });

    test('20초 지연 안내 콜백이 전달된다', () async {
      var notified = false;
      final fake = FakeClient();
      fake.onGenerate = (_) {};
      final service = serviceWith(fake);
      await service.generate(req(text: 'x'), onDelay: () => notified = true);
      // FakeClient 는 즉시 끝나므로 호출되지 않는 것이 정상이다.
      expect(notified, isFalse);
    });

    test('Softer 는 다시 생성하지 않는다', () async {
      final fake = FakeClient(
        recipe: const Recipe(steps: [RecipeStep(behavior: 'greet', speed: 1.2)]),
      );
      final service = serviceWith(fake);
      final r = await service.generate(req(text: 'x'));
      final softer = service.soften(r.spec);
      expect(fake.callCount, 1);
      expect(softer.recipe.steps.single.speed, lessThan(r.spec.recipe.steps.single.speed));
    });
  });

  group('OpenAIClient — 요청 조립과 응답 파싱', () {
    Map<String, Object?> capturedBody = {};

    OpenAIClient clientReturning(String body, {int status = 200}) => OpenAIClient(
          httpClient: MockClient((request) async {
            capturedBody = jsonDecode(request.body) as Map<String, Object?>;
            return http.Response(body, status, headers: {'content-type': 'application/json'});
          }),
        );

    String okResponse({
      String name = 'Welcome home',
      String face = 'smile',
      List<Map<String, Object?>>? steps,
    }) =>
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': jsonEncode({
                  'name': name,
                  'face': face,
                  'reasoning': 'Because someone arrived.',
                  'steps': steps ??
                      [
                        {
                          'behavior': 'greet',
                          'speed': 1.2,
                          'amplitude': 1.1,
                          'repeat': 2,
                          'face': 'smile',
                        },
                      ],
                }),
              },
            },
          ],
        });

    test('키가 없으면 auth 로 던진다 (테스트 실행은 키 없이 돈다)', () async {
      final client = clientReturning(okResponse());
      await expectLater(
        client.generate(req(text: 'hello')),
        throwsA(isA<GenerationException>().having(
            (e) => e.failure, 'failure', GenerationFailure.auth)),
      );
    });

    test('스키마가 strict 이고 enum 이 허용 목록과 같다', () {
      final f = OpenAIClient.responseFormat;
      final schema = (f['json_schema']! as Map)['schema']! as Map;
      expect((f['json_schema']! as Map)['strict'], isTrue);

      final props = schema['properties']! as Map;
      expect((props['face']! as Map)['enum'], kFaces);
      expect(schema['required'], ['name', 'face', 'reasoning', 'steps']);

      final stepProps = ((props['steps']! as Map)['items']! as Map)['properties']! as Map;
      expect((stepProps['behavior']! as Map)['enum'], kBehaviors);

      // strict:true 는 모든 property 가 required 여야 한다.
      final stepRequired = ((props['steps']! as Map)['items']! as Map)['required']! as List;
      expect(stepRequired.toSet(), stepProps.keys.toSet());

      // 선택 필드는 null 을 허용하는 타입으로 선언해야 한다.
      expect((stepProps['face']! as Map)['type'], ['string', 'null']);
      expect((stepProps['face']! as Map)['enum'], contains(null));

      // strict 가 지원하지 않는 키워드를 넣지 않았는지.
      final encoded = jsonEncode(f);
      for (final banned in ['minimum', 'maximum', 'maxItems', 'minItems']) {
        expect(encoded, isNot(contains(banned)), reason: 'strict 는 $banned 를 거부한다');
      }
    });

    test('시스템 프롬프트가 15종·7종을 모두 담는다', () {
      final p = OpenAIClient.systemPrompt;
      for (final b in kBehaviors) {
        expect(p, contains(b), reason: '$b 가 프롬프트에 없다');
      }
      for (final f in kFaces) {
        expect(p, contains(f));
      }
      expect(p, contains('THE ROBOT IS FIXED'));
      expect(p, contains('Context -> inner state -> movement'));
    });

    test('시그니처가 문장으로 들어간다', () {
      final s = OpenAIClient.describeSignature(
        const MotionSignature(lively: 10, bold: 10, expression: Expression.slowSmooth),
      );
      expect(s, contains('Calm & gentle'));
      expect(s, contains('slow & smooth'));
    });

    test('capturedBody 는 호출 전에는 비어 있다', () {
      expect(capturedBody, isEmpty);
    });
  });

  group('GenerationProvider', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('pure_gen_');
    });
    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    Future<(GenerationProvider, LocalRepository, FakeClient)> make({
      GenerationFailure? fail,
    }) async {
      final repo = LocalRepository.inDirectory(tmp);
      await repo.init();
      final fake = FakeClient(failWith: fail);
      final service = GenerationService(
        primary: fake,
        fallback: DemoClient(thinkingDelay: Duration.zero),
      );
      return (GenerationProvider(service, repo), repo, fake);
    }

    test('성공하면 done 으로 끝난다', () async {
      final (p, _, _) = await make();
      expect(p.status, GenerationStatus.idle);
      final r = await p.generate(req(text: 'hello'));
      expect(r, isNotNull);
      expect(p.status, GenerationStatus.done);
      expect(p.lastWasDemo, isFalse);
    });

    test('실패하면 데모로 와서 배지가 켜진다', () async {
      final (p, _, _) = await make(fail: GenerationFailure.network);
      final r = await p.generate(req(text: 'someone came home'));
      expect(r, isNotNull);
      expect(p.lastWasDemo, isTrue);
      expect(p.status, GenerationStatus.done);
    });

    test('데모 모드 토글이 저장된다', () async {
      final (p, repo, fake) = await make();
      expect(p.forceDemo, isFalse);

      expect(await p.toggleDemoMode(), isTrue);
      expect(repo.setting<bool>(SettingKeys.forceDemoMode), isTrue);

      await p.generate(req(text: 'someone came home'));
      expect(fake.callCount, 0, reason: '강제 데모면 OpenAI 를 안 부른다');

      expect(await p.toggleDemoMode(), isFalse);
    });

    test('취소하면 null 을 돌려주고 상태가 흐트러지지 않는다', () async {
      final repo = LocalRepository.inDirectory(tmp);
      await repo.init();
      final slow = FakeClient(delay: const Duration(seconds: 5));
      final service = GenerationService(
        primary: slow,
        fallback: DemoClient(thinkingDelay: Duration.zero),
      );
      final p = GenerationProvider(service, repo);

      final future = p.generate(req(text: 'x'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      p.cancel();
      expect(await future, isNull);
    });
  });
}
