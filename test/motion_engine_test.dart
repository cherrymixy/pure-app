import 'package:flutter_test/flutter_test.dart';

import 'package:pure_app/data/behaviors.dart';
import 'package:pure_app/models/clip.dart';
import 'package:pure_app/models/motion_signature.dart';
import 'package:pure_app/models/recipe.dart';
import 'package:pure_app/models/saved_motion.dart';
import 'package:pure_app/services/motion_engine.dart';

/// robot.xml 에서 오는 실제 범위 (SimReady.limits 와 같은 모양).
const Map<String, (double, double)> kRanges = {
  'base_yaw': (-150, 150),
  'shoulder_pitch': (-35, 55),
  'elbow_pitch': (-120, 33),
  'head_pan': (-160, 160),
  'head_tilt': (-33, 42),
};

void main() {
  group('signatureToParams — 시그니처가 재생으로 번역된다', () {
    test('극단값에서도 PRD 범위를 벗어나지 않는다', () {
      for (final lively in [0, 50, 100]) {
        for (final bold in [0, 50, 100]) {
          for (final richness in [0, 50, 100]) {
            for (final e in Expression.values) {
              final p = MotionEngine.signatureToParams(MotionSignature(
                lively: lively,
                bold: bold,
                richness: richness,
                expression: e,
              ));
              expect(p.speed, inInclusiveRange(MotionEngine.stepSpeedMin, MotionEngine.stepSpeedMax),
                  reason: 'lively=$lively e=$e');
              expect(
                p.amplitude,
                inInclusiveRange(
                    MotionEngine.minSignatureAmplitude, MotionEngine.maxSignatureAmplitude),
                reason: 'bold=$bold richness=$richness',
              );
            }
          }
        }
      }
    });

    test('범위 밖 입력도 안전하게 받는다', () {
      final p = MotionEngine.signatureToParams(
        const MotionSignature(lively: 999, bold: -50, richness: 1000),
      );
      expect(p.speed, inInclusiveRange(0.5, 1.6));
      expect(p.amplitude, inInclusiveRange(0.5, 1.3));
    });

    test('lively 가 높을수록 빠르다', () {
      final slow = MotionEngine.signatureToParams(const MotionSignature(lively: 0));
      final fast = MotionEngine.signatureToParams(const MotionSignature(lively: 100));
      expect(fast.speed, greaterThan(slow.speed));
    });

    test('bold 가 높을수록 크다', () {
      final small = MotionEngine.signatureToParams(const MotionSignature(bold: 0));
      final big = MotionEngine.signatureToParams(const MotionSignature(bold: 100));
      expect(big.amplitude, greaterThan(small.amplitude));
    });

    test('표현 A/B 배율이 PRD §6-9 와 같다', () {
      const base = MotionSignature(lively: 50, expression: Expression.inBetween);
      final between = MotionEngine.signatureToParams(base);
      final quick = MotionEngine.signatureToParams(
          base.copyWith(expression: Expression.quickBouncy));
      final slow =
          MotionEngine.signatureToParams(base.copyWith(expression: Expression.slowSmooth));
      expect(quick.speed / between.speed, closeTo(1.2, 1e-9));
      expect(slow.speed / between.speed, closeTo(0.8, 1e-9));
    });

    test('성격별 대기 모션과 관계별 인사 접두가 허용 목록 안이다', () {
      expect(MotionEngine.idleBehaviorFor(const MotionSignature(lively: 10, bold: 10)), 'doze');
      expect(MotionEngine.idleBehaviorFor(const MotionSignature(lively: 80, bold: 50)),
          'look_around');
      expect(MotionEngine.idleBehaviorFor(const MotionSignature(lively: 65, bold: 85)), 'curious');

      for (final s in [
        const MotionSignature(lively: 0, bold: 0),
        const MotionSignature(lively: 100, bold: 100),
        const MotionSignature(lively: 60, bold: 60),
      ]) {
        expect(kBehaviors, contains(MotionEngine.idleBehaviorFor(s)));
      }
      for (final r in Relationship.values) {
        final prefix = MotionEngine.greetPrefixFor(r);
        if (prefix != null) expect(kBehaviors, contains(prefix));
      }
    });
  });

  group('validateRecipe — GPT 출력의 유일한 방어선', () {
    test('허용 목록 밖 동작은 버린다', () {
      final r = MotionEngine.validateRecipe(const Recipe(steps: [
        RecipeStep(behavior: 'moonwalk'),
        RecipeStep(behavior: 'greet'),
      ]));
      expect(r.ok, isTrue);
      expect(r.value!.steps.single.behavior, 'greet');
      expect(r.reasons.join(), contains('moonwalk'));
    });

    test('쓸 수 있는 단계가 없으면 실패한다', () {
      final r = MotionEngine.validateRecipe(const Recipe(steps: [
        RecipeStep(behavior: 'moonwalk'),
        RecipeStep(behavior: 'breakdance'),
      ]));
      expect(r.ok, isFalse);
      expect(r.reasons.last, contains('남지 않았'));
    });

    test('빈 레시피도 실패한다', () {
      expect(MotionEngine.validateRecipe(const Recipe(steps: [])).ok, isFalse);
    });

    test('범위 밖 값은 조용히 자르되 사유를 남긴다', () {
      final r = MotionEngine.validateRecipe(const Recipe(steps: [
        RecipeStep(behavior: 'greet', speed: 9.0, amplitude: 0.01, repeat: 99),
      ]));
      final step = r.value!.steps.single;
      expect(step.speed, MotionEngine.stepSpeedMax);
      expect(step.amplitude, MotionEngine.stepAmplitudeMin);
      expect(step.repeat, MotionEngine.stepRepeatMax);
      expect(r.reasons, hasLength(3));
    });

    test('NaN·무한대도 안전하게 받는다', () {
      final r = MotionEngine.validateRecipe(Recipe(steps: [
        RecipeStep(behavior: 'nod', speed: double.nan, amplitude: double.infinity),
      ]));
      expect(r.ok, isTrue);
      expect(r.value!.steps.single.speed, 1.0);
      expect(r.value!.steps.single.amplitude.isFinite, isTrue);
    });

    test('단계가 6개를 넘으면 뒤를 버린다', () {
      final r = MotionEngine.validateRecipe(Recipe(
        steps: List.generate(10, (_) => const RecipeStep(behavior: 'nod')),
      ));
      expect(r.value!.steps, hasLength(MotionEngine.maxSteps));
      expect(r.reasons.join(), contains('넘어'));
    });

    test('알 수 없는 표정은 동작 기본값으로 떨군다', () {
      final r = MotionEngine.validateRecipe(const Recipe(steps: [
        RecipeStep(behavior: 'greet', face: 'angry'),
      ]));
      expect(r.value!.steps.single.face, isNull);
      expect(r.reasons.join(), contains('angry'));
    });

    test('멀쩡한 레시피는 손대지 않는다', () {
      const input = Recipe(steps: [
        RecipeStep(behavior: 'greet', speed: 1.2, amplitude: 1.1, repeat: 2, face: 'smile'),
      ]);
      final r = MotionEngine.validateRecipe(input);
      expect(r.changed, isFalse);
      expect(r.value!.steps.single.face, 'smile');
    });
  });

  group('validateClip — Tier 2 방어선', () {
    Clip clipOf(Map<String, List<ClipKey>> tracks, {double duration = 2.0}) =>
        Clip(duration: duration, tracks: tracks);

    test('관절 범위를 넘은 값을 클램프한다', () {
      final r = MotionEngine.validateClip(
        clipOf({
          'head_tilt': [const ClipKey(t: 0, value: 0), const ClipKey(t: 2, value: 400)],
        }),
        jointRanges: kRanges,
      );
      expect(r.ok, isTrue);
      expect(r.value!.tracks['head_tilt']!.last.value, 42);
      expect(r.reasons.join(), contains('클램프'));
    });

    test('알 수 없는 관절은 버린다 (조용히 0 으로 만들지 않는다)', () {
      final r = MotionEngine.validateClip(
        clipOf({
          'wrist_roll': [const ClipKey(t: 0, value: 10)],
          'head_pan': [const ClipKey(t: 0, value: 0), const ClipKey(t: 2, value: 30)],
        }),
        jointRanges: kRanges,
      );
      expect(r.value!.tracks.keys, ['head_pan']);
      expect(r.reasons.join(), contains('wrist_roll'));
    });

    test('쓸 수 있는 관절이 없으면 실패한다', () {
      final r = MotionEngine.validateClip(
        clipOf({'wrist_pitch': [const ClipKey(t: 0, value: 0)]}),
        jointRanges: kRanges,
      );
      expect(r.ok, isFalse);
    });

    test('길이는 1~8초로 자른다', () {
      final short = MotionEngine.validateClip(
        clipOf({'head_pan': [const ClipKey(t: 0, value: 0)]}, duration: 0.2),
        jointRanges: kRanges,
      );
      expect(short.value!.duration, MotionEngine.clipDurationMin);

      final long = MotionEngine.validateClip(
        clipOf({'head_pan': [const ClipKey(t: 0, value: 0)]}, duration: 99),
        jointRanges: kRanges,
      );
      expect(long.value!.duration, MotionEngine.clipDurationMax);
    });

    test('키프레임 24개 상한', () {
      final r = MotionEngine.validateClip(
        clipOf({
          'head_pan': List.generate(
              20, (i) => ClipKey(t: i * 0.1, value: (i.isEven ? 1 : -1) * 2.0)),
          'head_tilt': List.generate(
              20, (i) => ClipKey(t: i * 0.1, value: (i.isEven ? 1 : -1) * 2.0)),
        }),
        jointRanges: kRanges,
      );
      final total = r.value!.keyCount;
      expect(total, lessThanOrEqualTo(MotionEngine.clipMaxKeys));
      expect(r.reasons.join(), contains('키프레임'));
    });

    test('각속도를 넘으면 값을 깎지 않고 시간을 늘린다', () {
      // 0.1초에 100도 = 1000°/s. 상한 180°/s 이므로 약 5.6배로 늘어야 한다.
      final r = MotionEngine.validateClip(
        clipOf({
          'head_pan': [const ClipKey(t: 0, value: 0), const ClipKey(t: 0.1, value: 100)],
        }, duration: 1.0),
        jointRanges: kRanges,
      );
      expect(r.ok, isTrue);
      final keys = r.value!.tracks['head_pan']!;
      // 값은 그대로다 (범위 안이므로).
      expect(keys.last.value, 100);
      // 실제 각속도가 상한 이하로 내려왔다.
      final dt = keys.last.t - keys.first.t;
      final dv = (keys.last.value - keys.first.value).abs();
      expect(dv / dt, lessThanOrEqualTo(MotionEngine.maxDegreesPerSecond + 1e-6));
      expect(r.reasons.join(), contains('각속도'));
    });

    test('최대 길이에 걸려 완전히 보정하지 못하면 사유에 적는다', () {
      final r = MotionEngine.validateClip(
        clipOf({
          'base_yaw': [const ClipKey(t: 0, value: -150), const ClipKey(t: 0.05, value: 150)],
        }, duration: 8.0),
        jointRanges: kRanges,
      );
      expect(r.value!.duration, MotionEngine.clipDurationMax);
      expect(r.reasons.join(), contains('완전히 보정하지 못함'));
    });

    test('알 수 없는 easing 은 ease_in_out 으로', () {
      final r = MotionEngine.validateClip(
        clipOf({
          'head_pan': [const ClipKey(t: 0, value: 0, easing: 'bouncy_wiggle')],
        }),
        jointRanges: kRanges,
      );
      expect(r.value!.tracks['head_pan']!.single.easing, 'ease_in_out');
    });

    test('NaN 키는 버린다', () {
      final r = MotionEngine.validateClip(
        clipOf({
          'head_pan': [
            ClipKey(t: double.nan, value: 10),
            const ClipKey(t: 0, value: 0),
            const ClipKey(t: 1, value: 20),
          ],
        }),
        jointRanges: kRanges,
      );
      expect(r.value!.tracks['head_pan'], hasLength(2));
    });

    test('키는 시각 순으로 정렬된다', () {
      final r = MotionEngine.validateClip(
        clipOf({
          'head_pan': [
            const ClipKey(t: 1.5, value: 10),
            const ClipKey(t: 0.5, value: 0),
            const ClipKey(t: 1.0, value: 5),
          ],
        }),
        jointRanges: kRanges,
      );
      final ts = r.value!.tracks['head_pan']!.map((k) => k.t).toList();
      expect(ts, [0.5, 1.0, 1.5]);
    });

    test('format 이 다르면 실패한다', () {
      final r = MotionEngine.validateClip(
        const Clip(duration: 2, tracks: {}, format: 'something/2'),
      );
      expect(r.ok, isFalse);
    });

    test('범위를 주지 않으면 값 클램프는 건너뛴다', () {
      final r = MotionEngine.validateClip(clipOf({
        'head_tilt': [const ClipKey(t: 0, value: 0), const ClipKey(t: 2, value: 400)],
      }));
      expect(r.value!.tracks['head_tilt']!.last.value, 400);
    });
  });

  group('applySignature — 배율이 두 번 곱해지지 않게', () {
    test('시그니처가 각 단계에 미리 반영된다', () {
      const p = PlaybackParams(speed: 1.2, amplitude: 1.1, idleBehavior: 'idle');
      const r = Recipe(steps: [RecipeStep(behavior: 'greet', speed: 1.0, amplitude: 1.0)]);
      final out = MotionEngine.applySignature(r, p);
      expect(out.steps.single.speed, closeTo(1.2, 1e-9));
      expect(out.steps.single.amplitude, closeTo(1.1, 1e-9));
    });

    test('최악의 조합(시그니처 최대 × 단계 최대)에서도 상한을 넘지 않는다', () {
      final params = MotionEngine.signatureToParams(
        const MotionSignature(lively: 100, bold: 100, richness: 100),
      );
      final r = Recipe(steps: [
        for (final b in ['wake', 'focus', 'happy'])
          RecipeStep(behavior: b, speed: 1.6, amplitude: 1.5),
      ]);
      final out = MotionEngine.applySignature(r, params);
      for (final s in out.steps) {
        expect(s.amplitude, lessThanOrEqualTo(MotionEngine.maxEffectiveAmplitude),
            reason: '${s.behavior} 가 상한을 넘었다 — 로봇이 눈에 띄게 잘린다');
        expect(s.speed, lessThanOrEqualTo(MotionEngine.stepSpeedMax));
      }
    });

    test('반영 후에도 검증을 통과한다', () {
      final params = MotionEngine.signatureToParams(const MotionSignature(bold: 100));
      const r = Recipe(steps: [RecipeStep(behavior: 'greet', amplitude: 1.5)]);
      final out = MotionEngine.validateRecipe(MotionEngine.applySignature(r, params));
      expect(out.ok, isTrue);
      expect(out.changed, isFalse, reason: '이미 범위 안이어야 한다');
    });

    test('동작 이름과 표정은 건드리지 않는다', () {
      const p = PlaybackParams(speed: 0.5, amplitude: 0.5, idleBehavior: 'idle');
      const r = Recipe(steps: [RecipeStep(behavior: 'greet', face: 'smile', repeat: 3)]);
      final out = MotionEngine.applySignature(r, p);
      expect(out.steps.single.behavior, 'greet');
      expect(out.steps.single.face, 'smile');
      expect(out.steps.single.repeat, 3);
    });
  });

  group('applySoftener', () {
    test('속도와 크기를 한 단계 낮춘다', () {
      const input = Recipe(steps: [
        RecipeStep(behavior: 'greet', speed: 1.2, amplitude: 1.2),
      ]);
      final out = MotionEngine.applySoftener(input);
      expect(out.steps.single.speed, lessThan(1.2));
      expect(out.steps.single.amplitude, lessThan(1.2));
      expect(out.steps.single.behavior, 'greet');
    });

    test('여러 번 걸어도 하한 아래로 내려가지 않는다', () {
      var r = const Recipe(steps: [RecipeStep(behavior: 'nod', speed: 0.6, amplitude: 0.5)]);
      for (var i = 0; i < 20; i++) {
        r = MotionEngine.applySoftener(r);
      }
      expect(r.steps.single.speed, greaterThanOrEqualTo(MotionEngine.stepSpeedMin));
      expect(r.steps.single.amplitude, greaterThanOrEqualTo(MotionEngine.stepAmplitudeMin));
    });
  });

  group('demoMatch — 와이파이가 죽어도 뭔가는 재생된다', () {
    test('칩이 주어지면 그 칩의 레시피', () {
      expect(MotionEngine.demoMatch('', chipId: 'cameHome').chipId, 'cameHome');
      expect(MotionEngine.demoMatch('', chipId: 'startled').chipId, 'startled');
    });

    test('질문 트리 리프가 가장 정확하다', () {
      final r = MotionEngine.demoMatch('',
          chipId: 'cameHome', whenOptionId: 'someoneComesHome', howOptionId: 'shyNod');
      expect(r.howOptionId, 'shyNod');
    });

    test('자유 텍스트는 키워드로 고른다', () {
      expect(MotionEngine.demoMatch('someone just came home').chipId, 'cameHome');
      expect(MotionEngine.demoMatch('i am so exhausted today').chipId, 'tired');
      expect(MotionEngine.demoMatch('that was a loud bang').chipId, 'startled');
      expect(MotionEngine.demoMatch('thanks, good job').chipId, 'thankYou');
    });

    test('아무것도 안 맞아도 폴백을 돌려준다 (null 아님)', () {
      final r = MotionEngine.demoMatch('zxcvbnm qwerty');
      expect(r.recipe.steps, isNotEmpty);
    });

    test('고른 레시피는 항상 허용 목록 안이다', () {
      for (final text in ['home', 'tired', 'loud', 'thanks', 'what', 'zzz', '']) {
        final r = MotionEngine.demoMatch(text);
        for (final s in r.recipe.steps) {
          expect(kBehaviors, contains(s.behavior));
        }
      }
    });
  });

  group('suggestName', () {
    test('상황이 있으면 사전 이름', () {
      expect(MotionEngine.suggestName(situation: Situation.comesHome), 'Welcome home');
      expect(MotionEngine.suggestName(situation: Situation.tired), 'Gentle cheer-up');
      expect(MotionEngine.suggestName(situation: Situation.startled), 'Startled hop');
    });

    test('상황이 없으면 마지막 문장에서 뽑는다', () {
      expect(
        MotionEngine.suggestName(lastUserText: 'the cat jumped on my desk'),
        'Cat jumped desk',
      );
      expect(
        MotionEngine.suggestName(
            situation: Situation.onlyWhenAsked, lastUserText: 'I am so very tired'),
        'Tired',
      );
    });

    test('아무것도 없으면 기본 이름', () {
      expect(MotionEngine.suggestName(), 'New motion');
      expect(MotionEngine.suggestName(lastUserText: '   '), 'New motion');
      expect(MotionEngine.suggestName(lastUserText: 'the a is of'), 'New motion');
    });

    test('이미 쓰는 이름이면 번호를 붙인다', () {
      expect(
        MotionEngine.suggestName(
            situation: Situation.comesHome, taken: ['Welcome home']),
        'Welcome home 2',
      );
      expect(
        MotionEngine.suggestName(
            situation: Situation.comesHome, taken: ['Welcome home', 'Welcome home 2']),
        'Welcome home 3',
      );
    });

    test('항상 20자 이하다', () {
      final long = MotionEngine.suggestName(
        lastUserText: 'extraordinarily complicated situation happened',
      );
      expect(long.length, lessThanOrEqualTo(20));

      final collided = MotionEngine.suggestName(
        lastUserText: 'extraordinarily complicated situation happened',
        taken: [long],
      );
      expect(collided.length, lessThanOrEqualTo(20));
      expect(collided, isNot(long));
    });
  });

  group('estimateSeconds', () {
    test('단계가 많을수록 길다', () {
      const one = Recipe(steps: [RecipeStep(behavior: 'nod')]);
      const two = Recipe(steps: [RecipeStep(behavior: 'nod'), RecipeStep(behavior: 'greet')]);
      expect(MotionEngine.estimateSeconds(two),
          greaterThan(MotionEngine.estimateSeconds(one)));
    });

    test('빠를수록 짧다', () {
      const r = Recipe(steps: [RecipeStep(behavior: 'nod')]);
      expect(MotionEngine.estimateSeconds(r, speed: 2.0),
          lessThan(MotionEngine.estimateSeconds(r)));
    });
  });
}
