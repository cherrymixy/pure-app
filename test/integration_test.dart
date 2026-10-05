import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:pure_app/data/behaviors.dart';
import 'package:pure_app/data/question_tree.dart';
import 'package:pure_app/data/signature_options.dart';
import 'package:pure_app/models/message.dart';
import 'package:pure_app/models/motion_signature.dart';
import 'package:pure_app/models/recipe.dart';
import 'package:pure_app/models/saved_motion.dart';
import 'package:pure_app/providers/chat_provider.dart';
import 'package:pure_app/providers/generation_provider.dart';
import 'package:pure_app/providers/library_provider.dart';
import 'package:pure_app/providers/profile_provider.dart';
import 'package:pure_app/providers/robot_provider.dart';
import 'package:pure_app/repositories/local_repository.dart';
import 'package:pure_app/services/generation/demo_client.dart';
import 'package:pure_app/services/generation/fake_client.dart';
import 'package:pure_app/services/generation/generation_client.dart';
import 'package:pure_app/services/generation/generation_service.dart';
import 'package:pure_app/services/motion_engine.dart';

/// 전체 루프 통합 테스트 (STEP 11).
///
/// 화면이 실제로 부르는 순서 그대로 엮는다 — 생성은 [FakeClient], 시계는 주입,
/// 저장소는 임시 폴더의 진짜 파일. 시뮬레이터는 부르지 않는다(재생은 화면의 일이고
/// 여기서 검증할 수 있는 건 "무엇을 재생하라고 넘기는가" 까지다).
///
/// 이 테스트가 전부 초록이면 **로직 SSOT 동결**이다.
class Harness {
  Harness._(this.dir, this.repo, this.fake, this.service)
      : profile = ProfileProvider(repo),
        robot = RobotProvider(repo),
        chat = ChatProvider(repo, now: () => _clock),
        library = LibraryProvider(repo, now: () => _clock),
        generation = GenerationProvider(service, repo);

  static DateTime _clock = DateTime(2026, 10, 6, 9);

  final Directory dir;
  final LocalRepository repo;
  final FakeClient fake;
  final GenerationService service;

  final ProfileProvider profile;
  final RobotProvider robot;
  final ChatProvider chat;
  final LibraryProvider library;
  final GenerationProvider generation;

  static Future<Harness> create() async {
    _clock = DateTime(2026, 10, 6, 9);
    final dir = await Directory.systemTemp.createTemp('pure_integration_');
    final repo = LocalRepository.inDirectory(dir);
    await repo.init();
    final fake = FakeClient();
    final service = GenerationService(
      primary: fake,
      fallback: DemoClient(thinkingDelay: Duration.zero),
    );
    return Harness._(dir, repo, fake, service);
  }

  /// 시간을 앞으로 돌린다. 60초를 실제로 기다리지 않는다.
  void advance(Duration d) => _clock = _clock.add(d);

  Future<void> dispose() async {
    await repo.flush();
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  // ---------------------------------------------------------------- 화면 흐름

  /// 홈에서 보낸 것을 채팅이 처리하는 순서 (chat_screen.dart `_send`).
  Future<GenerationResult?> sendFromHome(
    String text, {
    String? chipId,
    Situation? situation,
  }) async {
    await chat.addUserMessage(text: text);
    final pending = await chat.addPendingReply();
    final result = await generation.generate(GenerationRequest(
      signature: robot.signature,
      text: text,
      chipId: chipId,
      situation: situation,
    ));
    if (result == null) {
      await chat.failReply(pending.id);
      return null;
    }
    await chat.completeReply(pending.id, result.spec);
    return result;
  }

  /// 저장 시트가 띄우는 이름 제안 (save_sheet.dart 와 같은 규칙).
  /// 시드에 이미 있는 이름이면 번호가 붙는다.
  String suggestName({Situation? situation, String? lastUserText}) =>
      MotionEngine.suggestName(
        situation: situation,
        lastUserText: lastUserText,
        taken: library.all.map((m) => m.name),
      );

  /// 06-5 피드백 재생성 (chat_screen.dart `_sendFeedback`).
  Future<GenerationResult?> sendFeedback(String feedback) async {
    final previous = chat.lastReply?.spec;
    await chat.addUserMessage(text: feedback);
    final pending = await chat.addPendingReply();
    final result = await generation.generate(GenerationRequest(
      signature: robot.signature,
      feedback: feedback,
      previousSpec: previous,
    ));
    if (result == null) {
      await chat.failReply(pending.id);
      return null;
    }
    await chat.completeReply(pending.id, result.spec);
    return result;
  }
}

void main() {
  late Harness h;

  setUp(() async => h = await Harness.create());
  tearDown(() async => h.dispose());

  group('시나리오 1 — 신규 사용자의 해피패스', () {
    test('시그니처 → 칩 → 질문형 3단계 → 저장 → 라이브러리 Auto 그룹', () async {
      // 첫 실행이면 05 를 먼저 본다.
      expect(h.robot.onboarded, isFalse);

      // 05 — Lively / Waits till I'm near / Quick & bouncy.
      await h.robot.updateSignature(
        applyPersonality(h.robot.signature, personalityById('lively')!)
            .copyWith(
          relationship: Relationship.waitsNear,
          expression: Expression.quickBouncy,
        ),
      );
      await h.robot.markOnboarded();
      expect(h.robot.onboarded, isTrue);
      expect(signatureSummary(h.robot.signature), 'LIVELY, BOUNCY');

      final signatureAtCreation = h.robot.signature;

      // 홈에서 칩 "Someone came home" → 질문형 3단계.
      final branch = branchForChip('cameHome');
      final when = branch.whenOptions.first;
      final how = branch.howOptions.first;

      await h.chat.startNew();
      final result = await h.sendFromHome(
        'Someone came home. When: ${when.label}. How: ${how.hint}',
        chipId: 'cameHome',
        situation: when.situation,
      );

      expect(result, isNotNull);
      final spec = result!.spec;

      // 생성 결과가 그때의 시그니처를 스냅샷으로 들고 있다.
      expect(spec.signatureSnapshot, signatureAtCreation);

      // 동작 이름이 전부 허용 목록 안이다.
      for (final s in spec.recipe.steps) {
        expect(kBehaviors, contains(s.behavior));
      }

      // 저장 — 반응 상황은 1단계 답에서 온다. 이름은 저장 시트가 제안하는 값.
      final suggested = h.suggestName(situation: when.situation);
      expect(suggested, 'Welcome home 2',
          reason: '시드에 "Welcome home" 이 있으므로 번호가 붙어야 한다');

      final outcome = await h.library.save(
        id: 'saved.${spec.id}',
        name: suggested,
        spec: spec,
        chatId: h.chat.currentId!,
        situation: when.situation,
      );

      expect(outcome, isA<SaveSucceeded>());
      final saved = (outcome as SaveSucceeded).motion;
      expect(saved.kind, ReactionKind.auto);
      expect(saved.situation, Situation.comesHome);

      // 라이브러리의 자동 재생 그룹에 들어간다.
      expect(h.library.autoGroup.map((m) => m.id), contains(saved.id));
      expect(h.repo.autoMotionFor(Situation.comesHome)!.id, saved.id);
    });

    test('재시작해도 전부 남는다', () async {
      await h.robot.markOnboarded();
      await h.chat.startNew();
      final result = await h.sendFromHome('someone came home', chipId: 'cameHome');
      await h.library.save(
        id: 'saved.keep',
        name: 'Keep me',
        spec: result!.spec,
        chatId: h.chat.currentId!,
        situation: Situation.comesHome,
      );
      await h.repo.flush();

      final reopened = LocalRepository.inDirectory(h.dir);
      await reopened.init();
      final library = LibraryProvider(reopened);
      final robot = RobotProvider(reopened);

      expect(robot.onboarded, isTrue);
      expect(library.byId('saved.keep')?.name, 'Keep me');
      expect(library.byId('saved.keep')!.spec.recipe.steps, isNotEmpty);
      expect(reopened.chats, isNotEmpty);
    });
  });

  group('시나리오 2 — 같은 상황에 두 번째 저장', () {
    test('첫 모션이 askFirst 로 내려가고 새 모션이 auto 가 된다', () async {
      await h.chat.startNew();

      final first = await h.sendFromHome('someone came home', chipId: 'cameHome');
      await h.library.save(
        id: 'saved.first',
        name: 'First hello',
        spec: first!.spec,
        chatId: h.chat.currentId!,
        situation: Situation.comesHome,
      );

      h.advance(const Duration(minutes: 5));
      final second = await h.sendFromHome('someone came home again', chipId: 'cameHome');
      final outcome = await h.library.save(
        id: 'saved.second',
        name: 'Second hello',
        spec: second!.spec,
        chatId: h.chat.currentId!,
        situation: Situation.comesHome,
      );

      final ok = outcome as SaveSucceeded;
      expect(ok.motion.kind, ReactionKind.auto);
      expect(ok.demoted?.id, 'saved.first');

      // 첫 모션은 **지워지지 않고** 물어보고 재생으로 내려간다.
      final first2 = h.library.byId('saved.first')!;
      expect(first2.kind, ReactionKind.askFirst);
      expect(first2.situation, Situation.comesHome);

      // 그 상황의 자동 재생은 하나뿐이다.
      expect(
        h.library.all.where(
          (m) => m.kind == ReactionKind.auto && m.situation == Situation.comesHome,
        ),
        hasLength(1),
      );
    });
  });

  group('시나리오 3 — 채팅과 피드백 버전', () {
    test('답장 v1 → 피드백 → v2, v1 은 그대로 남고 v1 에서도 저장된다', () async {
      await h.chat.startNew();

      h.fake.name = 'First take';
      final v1 = await h.sendFromHome('my cat jumped on the desk');
      expect(v1!.spec.version, 1);

      h.fake.name = 'Softer take';
      h.fake.recipe = const Recipe(steps: [RecipeStep(behavior: 'nod')]);
      final v2 = await h.sendFeedback('more gently, arms not legs');
      expect(v2!.spec.version, 2);

      // 두 답장이 모두 대화에 남아 있다.
      final replies = h.chat.messages
          .where((m) => m.sender == Sender.robot && m.spec != null)
          .toList();
      expect(replies, hasLength(2));
      expect(replies.first.spec!.name, 'First take');
      expect(replies.last.spec!.name, 'Softer take');

      // 이전 버전에서도 저장할 수 있다.
      final outcome = await h.library.save(
        id: 'saved.v1',
        name: 'From v1',
        spec: replies.first.spec!,
        chatId: h.chat.currentId!,
        situation: Situation.onlyWhenAsked,
      );
      expect(outcome, isA<SaveSucceeded>());
      expect(h.library.byId('saved.v1')!.spec.version, 1);
      expect(h.library.byId('saved.v1')!.kind, ReactionKind.manual);
    });

    test('생성 중 새로 보내면 이전 생성 자리가 사라진다', () async {
      await h.chat.startNew();
      await h.chat.addUserMessage(text: 'first');
      await h.chat.addPendingReply();
      expect(h.chat.messages.any((m) => m.status == MessageStatus.generating), isTrue);

      await h.chat.cancelPending();
      expect(h.chat.messages.any((m) => m.status == MessageStatus.generating), isFalse);
    });
  });

  group('시나리오 4 — 실패와 폴백', () {
    test('타임아웃이면 데모로 답이 나온다 (시연은 안 멈춘다)', () async {
      await h.chat.startNew();
      h.fake.failWith = GenerationFailure.timeout;

      final result = await h.sendFromHome('someone came home', chipId: 'cameHome');
      expect(result, isNotNull);
      expect(result!.isDemo, isTrue);
      expect(result.spec.recipe.steps, isNotEmpty);
      expect(h.generation.lastWasDemo, isTrue);

      // 대화에도 정상 답장으로 남는다 — 실패 말풍선이 아니다.
      expect(h.chat.messages.last.status, MessageStatus.done);
    });

    test('네트워크 없음도, 크레딧 없음도 데모로 간다', () async {
      for (final failure in [
        GenerationFailure.network,
        GenerationFailure.quota,
        GenerationFailure.auth,
      ]) {
        final fresh = await Harness.create();
        fresh.fake.failWith = failure;
        await fresh.chat.startNew();
        final r = await fresh.sendFromHome('I am so tired', chipId: 'tired');
        expect(r?.isDemo, isTrue, reason: failure.name);
        await fresh.dispose();
      }
    });

    test('강제 데모 모드를 켜면 실제 생성을 부르지 않는다', () async {
      await h.generation.toggleDemoMode();
      await h.chat.startNew();
      final r = await h.sendFromHome('someone came home', chipId: 'cameHome');
      expect(r!.isDemo, isTrue);
      expect(h.fake.callCount, 0);
    });

    test('GPT 가 허용 목록 밖 동작만 내면 데모로 구해진다', () async {
      await h.chat.startNew();
      h.fake.recipe = const Recipe(steps: [RecipeStep(behavior: 'moonwalk')]);
      final r = await h.sendFromHome('someone came home', chipId: 'cameHome');
      expect(r!.isDemo, isTrue);
      for (final s in r.spec.recipe.steps) {
        expect(kBehaviors, contains(s.behavior));
      }
    });
  });

  group('시나리오 5 — 시그니처 스냅샷 불변', () {
    test('저장 후 시그니처를 바꿔도 저장된 모션은 그대로다', () async {
      await h.chat.startNew();
      await h.robot.updateSignature(
        const MotionSignature(lively: 20, bold: 20, expression: Expression.slowSmooth),
      );
      final before = h.robot.signature;

      final result = await h.sendFromHome('someone came home', chipId: 'cameHome');
      await h.library.save(
        id: 'saved.snap',
        name: 'Snapshot',
        spec: result!.spec,
        chatId: h.chat.currentId!,
        situation: Situation.comesHome,
      );
      final savedRecipe = h.library.byId('saved.snap')!.spec.recipe;

      // 시그니처를 정반대로 바꾼다.
      await h.robot.updateSignature(
        const MotionSignature(lively: 100, bold: 100, expression: Expression.quickBouncy),
      );
      expect(h.robot.signature, isNot(before));

      final after = h.library.byId('saved.snap')!;
      expect(after.spec.signatureSnapshot, before, reason: '스냅샷이 따라 바뀌면 안 된다');
      expect(
        after.spec.recipe.steps.map((s) => s.speed).toList(),
        savedRecipe.steps.map((s) => s.speed).toList(),
        reason: '재생 파라미터도 그대로여야 한다',
      );
    });

    test('시그니처가 재생 파라미터에 반영되고 상한을 지킨다', () async {
      await h.chat.startNew();
      await h.robot.updateSignature(
        const MotionSignature(lively: 100, bold: 100, richness: 100),
      );
      h.fake.recipe = const Recipe(steps: [
        RecipeStep(behavior: 'wake', speed: 1.6, amplitude: 1.5),
      ]);

      final r = await h.sendFromHome('stretch please');
      for (final s in r!.spec.recipe.steps) {
        expect(s.amplitude, lessThanOrEqualTo(MotionEngine.maxEffectiveAmplitude));
        expect(s.speed, lessThanOrEqualTo(MotionEngine.stepSpeedMax));
      }
    });
  });

  group('시나리오 6 — 이름·수정·삭제', () {
    test('프로필 이름을 바꾸면 홈 인사말에 쓰이는 값이 바뀐다', () async {
      expect(h.profile.name, 'SeungA');
      expect(await h.profile.rename('Nari'), isTrue);
      expect(h.profile.name, 'Nari');

      // 같은 이름·빈 이름·21자는 거부.
      expect(h.profile.canSaveName('Nari'), isFalse);
      expect(h.profile.canSaveName(''), isFalse);
      expect(h.profile.canSaveName('x' * 21), isFalse);
    });

    test('Rename 은 중복을 거부하고 Delete 는 목록에서 뺀다', () async {
      final target = h.library.all.firstWhere((m) => m.name != 'Welcome home');

      final rejected = await h.library.rename(target.id, 'Welcome home');
      expect((rejected as SaveRejected).reason, SaveRejectReason.nameTaken);

      expect(await h.library.rename(target.id, 'Renamed'), isA<SaveSucceeded>());
      expect(h.library.byId(target.id)!.name, 'Renamed');

      final count = h.library.all.length;
      await h.library.delete(target.id);
      expect(h.library.byId(target.id), isNull);
      expect(h.library.all, hasLength(count - 1));
    });

    test('Edit in chat 으로 다시 저장하면 editCount 가 오른다', () async {
      await h.chat.startNew();
      final first = await h.sendFromHome('something happened');
      await h.library.save(
        id: 'saved.edit',
        name: 'Editable',
        spec: first!.spec,
        chatId: h.chat.currentId!,
        situation: Situation.onlyWhenAsked,
      );
      expect(h.library.byId('saved.edit')!.editCount, 0);

      final second = await h.sendFeedback('a bit softer');
      await h.library.saveEdited('saved.edit', second!.spec);

      final updated = h.library.byId('saved.edit')!;
      expect(updated.editCount, 1);
      expect(updated.spec.version, 2);
      expect(updated.name, 'Editable', reason: '이름은 유지된다');
    });
  });

  group('시나리오 7 — 전시 운영', () {
    test('Reset demo data 가 시드로 되돌리고 첫 실행 플래그도 지운다', () async {
      await h.robot.markOnboarded();
      await h.profile.rename('Visitor');
      await h.chat.startNew();
      await h.sendFromHome('something');
      await h.library.save(
        id: 'saved.temp',
        name: 'Temp',
        spec: (await h.sendFromHome('again'))!.spec,
        chatId: h.chat.currentId!,
        situation: Situation.onlyWhenAsked,
      );

      await h.repo.resetDemoData();
      h.library.refresh();
      h.profile.refresh();
      h.robot.refresh();

      expect(h.profile.name, 'SeungA');
      expect(h.robot.onboarded, isFalse, reason: '다음 관람객에게 05 부터 보여 줘야 한다');
      expect(h.library.all, hasLength(3));
      expect(h.library.byId('saved.temp'), isNull);
      expect(h.repo.chats, isEmpty);
    });

    test('시드 라이브러리는 같은 상황에 자동 재생이 둘 이상 없다', () async {
      final autos = h.library.all
          .where((m) => m.kind == ReactionKind.auto)
          .map((m) => m.situation)
          .toList();
      expect(autos.toSet(), hasLength(autos.length));
    });
  });
}
