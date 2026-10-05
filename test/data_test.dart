import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:pure_app/data/behaviors.dart';
import 'package:pure_app/data/chips.dart';
import 'package:pure_app/data/demo_recipes.dart';
import 'package:pure_app/data/question_tree.dart';
import 'package:pure_app/data/seed.dart';
import 'package:pure_app/data/signature_options.dart';
import 'package:pure_app/data/situations.dart';
import 'package:pure_app/data/strings.dart';
import 'package:pure_app/models/clip.dart';
import 'package:pure_app/models/message.dart';
import 'package:pure_app/models/motion_signature.dart';
import 'package:pure_app/models/motion_spec.dart';
import 'package:pure_app/models/recipe.dart';
import 'package:pure_app/models/saved_motion.dart';

void main() {
  group('허용 목록 — sim 과 어긋나면 재생이 조용히 죽는다', () {
    test('동작 15종, 얼굴 7종', () {
      expect(kBehaviors, hasLength(15));
      expect(kFaces, hasLength(7));
      expect(kBehaviors.toSet(), hasLength(15), reason: '중복 없음');
      expect(kFaces.toSet(), hasLength(7));
    });

    test('동작 이름이 sim/src/engine/behaviors.ts 와 같다', () {
      expect(kBehaviors, [
        'idle', 'doze', 'sleep', 'wake', 'nod', 'shake', 'look_around',
        'curious', 'happy', 'sad', 'alert', 'greet', 'sweep', 'focus', 'home',
      ]);
    });

    test('faces.json 매핑이 15종을 모두 덮고, 값은 전부 허용 표정이다', () {
      for (final b in kBehaviors) {
        expect(kDefaultFaceForBehavior.containsKey(b), isTrue, reason: '$b 매핑 없음');
        expect(kFaces, contains(kDefaultFaceForBehavior[b]));
      }
    });

    test('프롬프트용 설명이 15종·7종을 전부 덮는다', () {
      for (final b in kBehaviors) {
        expect(kBehaviorDescriptions[b], isNotNull, reason: '$b 설명 없음');
        expect(kBehaviorDescriptions[b], isNotEmpty);
      }
      for (final f in kFaces) {
        expect(kFaceDescriptions[f], isNotNull, reason: '$f 설명 없음');
      }
      expect(kBehaviorDescriptions, hasLength(15));
      expect(kFaceDescriptions, hasLength(7));
    });

    test('루프 동작 6종', () {
      expect(kLoopingBehaviors, {'idle', 'doze', 'sleep', 'sad', 'sweep', 'focus'});
      for (final b in kLoopingBehaviors) {
        expect(kBehaviors, contains(b));
      }
    });

    test('관절 이름은 계약 이름이다 (sim 내부 채널명이 아님)', () {
      expect(kJoints,
          ['base_yaw', 'shoulder_pitch', 'elbow_pitch', 'head_pan', 'head_tilt']);
      expect(kJoints, isNot(contains('wrist_roll')));
      expect(kJoints, isNot(contains('wrist_pitch')));
      expect(kJoints, isNot(contains('base_pitch')));
    });
  });

  group('데모 레시피 — 전시장 와이파이가 죽어도 도는 길', () {
    test('모든 동작·표정이 허용 목록 안이다', () {
      for (final d in [...kDemoRecipes, kDemoFallback]) {
        expect(kFaces, contains(d.face), reason: '${d.id} 의 face');
        expect(d.recipe.steps, isNotEmpty, reason: '${d.id} 가 비었다');
        for (final s in d.recipe.steps) {
          expect(kBehaviors, contains(s.behavior), reason: '${d.id} 의 ${s.behavior}');
          if (s.face != null) {
            expect(kFaces, contains(s.face), reason: '${d.id} 의 step face');
          }
        }
      }
    });

    test('PRD 범위를 지킨다 (speed 0.5~1.6 / amplitude 0.4~1.5 / repeat 1~4 / steps ≤6)', () {
      for (final d in [...kDemoRecipes, kDemoFallback]) {
        expect(d.recipe.steps.length, lessThanOrEqualTo(6), reason: d.id);
        for (final s in d.recipe.steps) {
          expect(s.speed, inInclusiveRange(0.5, 1.6), reason: '${d.id} speed');
          expect(s.amplitude, inInclusiveRange(0.4, 1.5), reason: '${d.id} amplitude');
          expect(s.repeat, inInclusiveRange(1, 4), reason: '${d.id} repeat');
        }
      }
    });

    test('칩 5개마다 레시피가 있다', () {
      for (final c in kHomeChips) {
        final r = demoRecipeForChip(c.id);
        expect(r.id, isNot(kDemoFallback.id), reason: '${c.id} 에 레시피 없음');
      }
    });

    test('질문 트리의 모든 how 선택지에 리프 레시피가 있다', () {
      for (final b in kQuestionTree) {
        for (final h in b.howOptions) {
          final r = demoRecipeForLeaf(chipId: b.chipId, howOptionId: h.id);
          expect(r.howOptionId, h.id,
              reason: '${b.chipId}/${h.id} 가 칩 기본으로 떨어졌다');
        }
      }
    });

    test('id 가 중복되지 않는다', () {
      final ids = kDemoRecipes.map((d) => d.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });
  });

  group('질문 트리', () {
    test('칩 5개마다 가지가 있고 선택지는 각 3개다', () {
      expect(kQuestionTree, hasLength(kHomeChips.length));
      for (final b in [...kQuestionTree, kFallbackBranch]) {
        expect(b.whenOptions, hasLength(3), reason: b.chipId);
        expect(b.howOptions, hasLength(3), reason: b.chipId);
      }
    });

    test('예시 동작이 허용 목록 안이다', () {
      for (final b in [...kQuestionTree, kFallbackBranch]) {
        for (final o in b.whenOptions) {
          expect(kBehaviors, contains(o.exampleBehavior), reason: o.id);
        }
      }
    });

    test('원형 버튼 라벨은 2줄 이하다', () {
      for (final b in [...kQuestionTree, kFallbackBranch]) {
        for (final o in [...b.whenOptions.map((e) => e.label), ...b.howOptions.map((e) => e.label)]) {
          expect('\n'.allMatches(o).length, lessThanOrEqualTo(1), reason: o);
        }
      }
    });

    test('모르는 칩은 기본 가지로 떨어진다', () {
      expect(branchForChip('nope').chipId, kFallbackBranch.chipId);
      expect(branchForChip(null).chipId, kFallbackBranch.chipId);
    });
  });

  group('시그니처 선택지', () {
    test('성격 3 · 관계 3 · 표현 3', () {
      expect(kPersonalityOptions, hasLength(3));
      expect(kRelationshipOptions, hasLength(3));
      expect(kExpressionOptions, hasLength(3));
    });

    test('성격의 대기 모션과 관계의 인사 동작이 허용 목록 안이다', () {
      for (final o in kPersonalityOptions) {
        expect(kBehaviors, contains(o.idleBehavior), reason: o.id);
      }
      for (final o in kRelationshipOptions) {
        expect(kBehaviors, contains(o.greetBehavior), reason: '${o.value}');
      }
    });

    test('표현 배율이 PRD §6-9 와 같다 (A 1.2 / B 0.8 / between 1.0)', () {
      expect(expressionFor(Expression.quickBouncy).speedFactor, 1.2);
      expect(expressionFor(Expression.slowSmooth).speedFactor, 0.8);
      expect(expressionFor(Expression.inBetween).speedFactor, 1.0);
    });

    test('모든 enum 값이 선택지로 덮인다', () {
      for (final v in Relationship.values) {
        expect(() => relationshipFor(v), returnsNormally);
      }
      for (final v in Expression.values) {
        expect(() => expressionFor(v), returnsNormally);
      }
    });

    test('시드 시그니처는 Lively 로 읽힌다', () {
      expect(personalityFor(MotionSignature.seed).id, 'lively');
      expect(signatureSummary(MotionSignature.seed), 'LIVELY, BOUNCY');
    });
  });

  group('상황 · 칩 · 문구', () {
    test('상황 4종에 라벨이 다 있다', () {
      for (final s in Situation.values) {
        expect(kSituationLabels[s], isNotNull);
        expect(kSituationLabels[s], isNotEmpty);
      }
      expect(kSituationOrder.toSet(), Situation.values.toSet());
    });

    test('onlyWhenAsked 만 자동 재생이 아니다', () {
      expect(isAutoSituation(Situation.onlyWhenAsked), isFalse);
      expect(isAutoSituation(Situation.comesHome), isTrue);
      expect(playsAutomaticallyWhen(Situation.comesHome),
          'Plays automatically when someone comes home');
    });

    test('칩 5개, id 중복 없음', () {
      expect(kHomeChips, hasLength(5));
      expect(kHomeChips.map((c) => c.id).toSet(), hasLength(5));
      expect(chipById('cameHome')?.label, 'Someone came home');
    });

    test('fill 이 자리표시자를 채운다', () {
      expect(fill(S.homeGreeting, {'name': 'SeungA'}), "Hi SeungA, what’s happening?");
      expect(fill(S.playingBar, {'time': '0:03'}), 'Purebot is moving 0:03');
    });
  });

  group('시드', () {
    test('프로필·로봇이 PRD 값과 같다', () {
      expect(kSeedProfile.name, 'SeungA');
      expect(kSeedProfile.email, 'seunga@purebot.app');
      expect(kSeedRobot.name, 'Purebot');
      expect(kSeedRobot.model, 'Purebot Arm');
    });

    test('라이브러리 샘플 3개 — 같은 상황에 auto 가 둘 이상이면 안 된다', () {
      final lib = seedLibrary();
      expect(lib, hasLength(3));
      final autoSituations =
          lib.where((m) => m.kind == ReactionKind.auto).map((m) => m.situation).toList();
      expect(autoSituations.toSet(), hasLength(autoSituations.length));
    });

    test('샘플의 레시피도 허용 목록 안이다', () {
      for (final m in seedLibrary()) {
        for (final s in m.spec.recipe.steps) {
          expect(kBehaviors, contains(s.behavior), reason: m.name);
        }
        expect(kFaces, contains(m.spec.face));
      }
    });

    test('알림·행동 기록 시드가 비어 있지 않다', () {
      expect(seedNotifications(), isNotEmpty);
      expect(seedActivity(), isNotEmpty);
    });
  });

  group('JSON 왕복', () {
    test('MotionSignature', () {
      const s = MotionSignature(lively: 33, bold: 77, relationship: Relationship.onlyNeeded);
      final back = MotionSignature.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>);
      expect(back, s);
    });

    test('Recipe — sim 계약 모양을 지킨다', () {
      const r = Recipe(steps: [
        RecipeStep(behavior: 'greet', speed: 1.2, amplitude: 1.1, repeat: 2, face: 'smile'),
      ]);
      final json = r.toJson();
      final step = (json['steps']! as List).first as Map<String, Object?>;
      expect(step.keys, containsAll(['behavior', 'speed', 'amplitude', 'repeat', 'face']));
      final back = Recipe.fromJson(jsonDecode(jsonEncode(json)) as Map<String, Object?>);
      expect(back.steps.single.behavior, 'greet');
      expect(back.steps.single.repeat, 2);
    });

    test('face 가 없으면 키 자체가 빠진다 (sim 이 null 을 거부한다)', () {
      const step = RecipeStep(behavior: 'nod');
      expect(step.toJson().containsKey('face'), isFalse);
    });

    test('Clip — 계약 관절 이름과 format 을 유지한다', () {
      const c = Clip(duration: 2.0, tracks: {
        'head_pan': [ClipKey(t: 0, value: 0), ClipKey(t: 2, value: 60, easing: 'ease_out')],
      });
      final json = c.toJson();
      expect(json['format'], 'lelamp.clip/1');
      expect((json['tracks']! as Map).keys, ['head_pan']);
      final back = Clip.fromJson(jsonDecode(jsonEncode(json)) as Map<String, Object?>);
      expect(back.keyCount, 2);
      expect(back.tracks['head_pan']!.last.easing, 'ease_out');
    });

    test('MotionSpec — 시그니처 스냅샷이 보존된다', () {
      final spec = MotionSpec(
        id: 'x',
        name: 'Test',
        face: 'smile',
        mode: SpecMode.recipe,
        recipe: const Recipe(steps: [RecipeStep(behavior: 'nod')]),
        signatureSnapshot: const MotionSignature(lively: 10, bold: 90),
        version: 3,
      );
      final back = MotionSpec.fromJson(
          jsonDecode(jsonEncode(spec.toJson())) as Map<String, Object?>);
      expect(back.signatureSnapshot.lively, 10);
      expect(back.signatureSnapshot.bold, 90);
      expect(back.version, 3);
      expect(back.effectiveMode, SpecMode.recipe);
    });

    test('SavedMotion · Chat', () {
      final m = seedLibrary().first;
      final back =
          SavedMotion.fromJson(jsonDecode(jsonEncode(m.toJson())) as Map<String, Object?>);
      expect(back.name, m.name);
      expect(back.situation, m.situation);
      expect(back.kind, m.kind);

      final chat = Chat(
        id: 'c1',
        messages: [
          Message(
            id: 'm1',
            sender: Sender.user,
            status: MessageStatus.done,
            createdAt: DateTime(2026, 10, 6),
            text: 'hi',
          ),
        ],
        createdAt: DateTime(2026, 10, 6),
        lastActiveAt: DateTime(2026, 10, 6),
      );
      final chatBack =
          Chat.fromJson(jsonDecode(jsonEncode(chat.toJson())) as Map<String, Object?>);
      expect(chatBack.messages.single.text, 'hi');
      expect(chatBack.replyCount, 0);
    });

    test('clip 모드인데 clip 이 없으면 recipe 로 본다', () {
      const spec = MotionSpec(
        id: 'x',
        name: 'T',
        face: 'neutral',
        mode: SpecMode.clip,
        recipe: Recipe(steps: [RecipeStep(behavior: 'nod')]),
        signatureSnapshot: MotionSignature.seed,
      );
      expect(spec.effectiveMode, SpecMode.recipe);
    });
  });
}
