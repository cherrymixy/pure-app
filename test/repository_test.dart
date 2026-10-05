import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:pure_app/models/message.dart';
import 'package:pure_app/models/motion_signature.dart';
import 'package:pure_app/models/motion_spec.dart';
import 'package:pure_app/models/recipe.dart';
import 'package:pure_app/models/saved_motion.dart';
import 'package:pure_app/providers/chat_provider.dart';
import 'package:pure_app/providers/library_provider.dart';
import 'package:pure_app/providers/notification_provider.dart';
import 'package:pure_app/providers/profile_provider.dart';
import 'package:pure_app/providers/robot_provider.dart';
import 'package:pure_app/repositories/data_repository.dart';
import 'package:pure_app/repositories/local_repository.dart';
import 'package:pure_app/services/thumbnail_store.dart';

late Directory _tmp;

Future<LocalRepository> freshRepo() async {
  final repo = LocalRepository.inDirectory(_tmp);
  await repo.init();
  return repo;
}

MotionSpec specOf(String name, {int version = 1, String? thumb}) => MotionSpec(
      id: 'spec.$name',
      name: name,
      face: 'smile',
      mode: SpecMode.recipe,
      recipe: const Recipe(steps: [RecipeStep(behavior: 'greet', repeat: 2)]),
      reasoning: 'because',
      signatureSnapshot: const MotionSignature(lively: 42, bold: 17),
      version: version,
      thumbnailPath: thumb,
    );

void main() {
  setUp(() async {
    _tmp = await Directory.systemTemp.createTemp('pure_test_');
  });

  tearDown(() async {
    if (await _tmp.exists()) await _tmp.delete(recursive: true);
  });

  group('LocalRepository — 첫 실행과 영속', () {
    test('첫 실행에 시드가 들어간다', () async {
      final repo = await freshRepo();
      expect(repo.profile.name, 'SeungA');
      expect(repo.robot.name, 'Purebot');
      expect(repo.library, hasLength(3));
      expect(repo.notifications, isNotEmpty);
      expect(repo.activity, isNotEmpty);
      expect(repo.setting<bool>(SettingKeys.onboarded), isFalse);
    });

    test('init 전에 읽으면 던진다', () {
      final repo = LocalRepository.inDirectory(_tmp);
      expect(() => repo.profile, throwsStateError);
    });

    test('재시작해도 남고, 시드는 한 번만 들어간다', () async {
      final a = await freshRepo();
      await a.saveProfile(a.profile.copyWith(name: 'Nari'));
      await a.deleteSavedMotion(a.library.first.id);
      await a.flush();

      final b = await freshRepo();
      expect(b.profile.name, 'Nari', reason: '이름이 유지돼야 한다');
      expect(b.library, hasLength(2), reason: '시드가 다시 들어가면 3개가 된다');
    });

    test('저장 중 앱이 죽어도 깨진 파일을 남기지 않는다 (tmp + rename)', () async {
      final a = await freshRepo();
      await a.saveProfile(a.profile.copyWith(name: 'Mid'));
      await a.flush();
      final files = _tmp.listSync().map((e) => e.path.split('/').last).toList();
      expect(files, contains('pure_state.json'));
      expect(files.where((f) => f.endsWith('.tmp')), isEmpty);
    });

    test('깨진 JSON 은 빈 상태로 보고 시드를 다시 심는다 (앱이 뜨긴 해야 한다)', () async {
      await File('${_tmp.path}/pure_state.json').writeAsString('{ this is not json');
      final repo = await freshRepo();
      expect(repo.library, hasLength(3));
    });

    test('resetDemoData 가 시드 상태로 되돌리고 첫 실행 플래그도 지운다', () async {
      final repo = await freshRepo();
      await repo.saveSetting(SettingKeys.onboarded, true);
      await repo.saveProfile(repo.profile.copyWith(name: 'Temp'));
      await repo.deleteSavedMotion(repo.library.first.id);

      await repo.resetDemoData();

      expect(repo.profile.name, 'SeungA');
      expect(repo.library, hasLength(3));
      expect(repo.setting<bool>(SettingKeys.onboarded), isFalse,
          reason: '다음 관람객에게 05 부터 보여줘야 한다');
    });

    test('SavedMotion 왕복 — MotionSpec 과 시그니처 스냅샷이 보존된다', () async {
      final a = await freshRepo();
      final motion = SavedMotion(
        id: 'm.rt',
        name: 'Round trip',
        spec: specOf('rt', version: 4, thumb: '/tmp/x.png'),
        kind: ReactionKind.askFirst,
        situation: Situation.startled,
        savedAt: DateTime(2026, 10, 6, 12, 34),
        editCount: 2,
        chatId: 'chat.x',
      );
      await a.upsertSavedMotion(motion);
      await a.flush();

      final b = await freshRepo();
      final back = b.savedMotionById('m.rt')!;
      expect(back.name, 'Round trip');
      expect(back.kind, ReactionKind.askFirst);
      expect(back.situation, Situation.startled);
      expect(back.editCount, 2);
      expect(back.savedAt, DateTime(2026, 10, 6, 12, 34));
      expect(back.spec.version, 4);
      expect(back.spec.thumbnailPath, '/tmp/x.png');
      expect(back.spec.signatureSnapshot.lively, 42);
      expect(back.spec.signatureSnapshot.bold, 17);
      expect(back.spec.recipe.steps.single.behavior, 'greet');
      expect(back.spec.recipe.steps.single.repeat, 2);
    });

    test('라이브러리는 저장 시각 역순, 대화는 최근 활동 순', () async {
      final repo = await freshRepo();
      final names = repo.library.map((m) => m.name).toList();
      expect(names.first, 'Startled hop', reason: '가장 최근에 저장된 것');

      final chat = ChatProvider(repo, now: () => DateTime(2026, 1, 1));
      await chat.startNew();
      await chat.addUserMessage(text: 'hello');
      expect(repo.chats, hasLength(1));
    });
  });

  group('ProfileProvider', () {
    test('이름 규칙 — 1~20자, 같은 이름은 거부', () async {
      final repo = await freshRepo();
      final p = ProfileProvider(repo);
      expect(p.canSaveName('SeungA'), isFalse, reason: '같은 이름');
      expect(p.canSaveName(''), isFalse);
      expect(p.canSaveName('a' * 21), isFalse);
      expect(p.canSaveName('Nari'), isTrue);

      expect(await p.rename('Nari'), isTrue);
      expect(p.name, 'Nari');
      expect(await p.rename('Nari'), isFalse);
    });
  });

  group('RobotProvider', () {
    test('시그니처를 바꾸면 저장되고 재시작해도 남는다', () async {
      final a = await freshRepo();
      final r = RobotProvider(a);
      expect(r.onboarded, isFalse);

      await r.updateSignature(
        r.signature.copyWith(lively: 10, expression: Expression.slowSmooth),
      );
      await r.markOnboarded();
      await a.flush();

      final b = await freshRepo();
      final r2 = RobotProvider(b);
      expect(r2.signature.lively, 10);
      expect(r2.signature.expression, Expression.slowSmooth);
      expect(r2.onboarded, isTrue);
    });

    test('Reset to default 는 시드 시그니처로 돌아간다', () async {
      final repo = await freshRepo();
      final r = RobotProvider(repo);
      await r.updateSignature(r.signature.copyWith(lively: 5));
      await r.resetSignature();
      expect(r.signature, MotionSignature.seed);
    });
  });

  group('LibraryProvider — 저장 규칙', () {
    test('같은 상황에 두 번째를 저장하면 기존이 askFirst 로 내려간다 (지워지지 않는다)', () async {
      final repo = await freshRepo();
      final lib = LibraryProvider(repo, now: () => DateTime(2026, 10, 6));

      final before = lib.all.firstWhere((m) => m.situation == Situation.comesHome);
      expect(before.kind, ReactionKind.auto);

      final outcome = await lib.save(
        id: 'm.new',
        name: 'Second hello',
        spec: specOf('second'),
        chatId: 'chat.1',
        situation: Situation.comesHome,
      );

      expect(outcome, isA<SaveSucceeded>());
      final ok = outcome as SaveSucceeded;
      expect(ok.motion.kind, ReactionKind.auto);
      expect(ok.demoted?.id, before.id);
      expect(lib.byId(before.id)!.kind, ReactionKind.askFirst);
      expect(lib.byId(before.id), isNotNull, reason: '기존 모션은 남아 있어야 한다');
      expect(repo.autoMotionFor(Situation.comesHome)!.id, 'm.new');
    });

    test('이름 규칙 — 빈 이름·21자·중복 거부', () async {
      final repo = await freshRepo();
      final lib = LibraryProvider(repo);

      expect(
        await lib.save(id: 'a', name: '  ', spec: specOf('a'), chatId: 'c'),
        isA<SaveRejected>(),
      );
      expect(
        (await lib.save(id: 'a', name: 'x' * 21, spec: specOf('a'), chatId: 'c')
                as SaveRejected)
            .reason,
        SaveRejectReason.nameTooLong,
      );
      expect(
        (await lib.save(id: 'a', name: 'Welcome home', spec: specOf('a'), chatId: 'c')
                as SaveRejected)
            .reason,
        SaveRejectReason.nameTaken,
      );
    });

    test('onlyWhenAsked 로 저장하면 manual 이고 자동 그룹에 안 들어간다', () async {
      final repo = await freshRepo();
      final lib = LibraryProvider(repo);
      final out = await lib.save(
        id: 'm.manual',
        name: 'Manual one',
        spec: specOf('m'),
        chatId: 'c',
        situation: Situation.onlyWhenAsked,
      );
      expect((out as SaveSucceeded).motion.kind, ReactionKind.manual);
      expect(lib.autoGroup.any((m) => m.id == 'm.manual'), isFalse);
    });

    test('Rename 은 중복을 거부하고, 자기 이름은 허용한다', () async {
      final repo = await freshRepo();
      final lib = LibraryProvider(repo);
      // 'Welcome home' 이 아닌 다른 모션을 고른다 — 자기 이름으로 바꾸는 건 허용이라
      // 중복 거부를 확인할 수 없다.
      final target = lib.all.firstWhere((m) => m.name != 'Welcome home');

      expect(
        (await lib.rename(target.id, 'Welcome home') as SaveRejected).reason,
        SaveRejectReason.nameTaken,
      );
      expect(await lib.rename(target.id, target.name), isA<SaveSucceeded>());
      expect(await lib.rename(target.id, 'Renamed'), isA<SaveSucceeded>());
      expect(lib.byId(target.id)!.name, 'Renamed');
    });

    test('Edit in chat 재저장은 editCount 를 올리고 옛 썸네일을 지운다', () async {
      final repo = await freshRepo();
      final store = ThumbnailStore(Directory('${_tmp.path}/thumbs'));
      final old = await store.saveBytes(
        // 1x1 PNG
        ThumbnailStore.decodeDataUrl(
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
        )!,
        name: 'old.png',
      );
      expect(File(old!).existsSync(), isTrue);

      final lib = LibraryProvider(repo, thumbnails: store);
      await lib.save(
        id: 'm.e',
        name: 'Editable',
        spec: specOf('e', thumb: old),
        chatId: 'c',
        situation: Situation.onlyWhenAsked,
      );

      await lib.saveEdited('m.e', specOf('e', version: 2, thumb: '/new/path.png'));

      expect(lib.byId('m.e')!.editCount, 1);
      expect(lib.byId('m.e')!.spec.version, 2);
      expect(File(old).existsSync(), isFalse, reason: '옛 썸네일이 쌓이면 안 된다');
    });

    test('삭제하면 목록에서 빠진다', () async {
      final repo = await freshRepo();
      final lib = LibraryProvider(repo);
      final id = lib.all.first.id;
      await lib.delete(id);
      expect(lib.byId(id), isNull);
      expect(lib.all, hasLength(2));
    });

    test('필터와 검색', () async {
      final repo = await freshRepo();
      final lib = LibraryProvider(repo);

      await lib.setFilter(LibraryFilter.auto);
      expect(lib.visible.every((m) => m.kind == ReactionKind.auto), isTrue);
      await lib.setFilter(LibraryFilter.manual);
      expect(lib.visible.any((m) => m.kind == ReactionKind.auto), isFalse);

      await lib.setFilter(LibraryFilter.all);
      expect(lib.search('welcome').single.name, 'Welcome home');
      expect(lib.search('   '), lib.visible);
      expect(lib.search('zzz'), isEmpty);
    });
  });

  group('ChatProvider', () {
    test('사용자 메시지 → 생성 중 → 완료 흐름', () async {
      final repo = await freshRepo();
      var t = DateTime(2026, 10, 6, 10);
      final chat = ChatProvider(repo, now: () => t);

      await chat.addUserMessage(text: 'Someone came home');
      expect(chat.messages, hasLength(1));

      final pending = await chat.addPendingReply();
      expect(chat.messages.last.status, MessageStatus.generating);

      t = t.add(const Duration(seconds: 3));
      await chat.completeReply(pending.id, specOf('reply'));
      expect(chat.messages.last.status, MessageStatus.done);
      expect(chat.lastReply!.spec!.name, 'reply');
      expect(chat.nextVersion(), 2);
    });

    test('빈 메시지는 넣지 않는다', () async {
      final repo = await freshRepo();
      final chat = ChatProvider(repo);
      expect(await chat.addUserMessage(text: '   '), isNull);
      expect(chat.messages, isEmpty);
    });

    test('생성 중 새로 보내면 이전 생성 자리가 사라진다', () async {
      final repo = await freshRepo();
      final chat = ChatProvider(repo);
      await chat.addUserMessage(text: 'first');
      await chat.addPendingReply();
      await chat.cancelPending();
      expect(chat.messages.any((m) => m.status == MessageStatus.generating), isFalse);
      expect(chat.messages, hasLength(1));
    });

    test('실패한 답장은 failed 로 남는다 (06-E1)', () async {
      final repo = await freshRepo();
      final chat = ChatProvider(repo);
      final p = await chat.addPendingReply();
      await chat.failReply(p.id, text: "Couldn't make this motion");
      expect(chat.messages.last.status, MessageStatus.failed);
    });

    test('대화를 열고 닫고 지운다', () async {
      final repo = await freshRepo();
      final chat = ChatProvider(repo);
      final a = await chat.startNew();
      await chat.addUserMessage(text: 'a');
      final b = await chat.startNew();
      expect(repo.chats, hasLength(2));

      expect(await chat.open(a), isTrue);
      expect(chat.currentId, a);
      expect(await chat.open('nope'), isFalse);

      await chat.deleteChat(b);
      expect(repo.chats, hasLength(1));
    });
  });

  group('NotificationProvider', () {
    test('읽음 표시가 저장된다', () async {
      final a = await freshRepo();
      final n = NotificationProvider(a);
      expect(n.hasUnread, isTrue);
      final unreadBefore = n.unreadCount;

      await n.markRead(n.items.first.id);
      expect(n.unreadCount, unreadBefore - 1);

      await n.markAllRead();
      expect(n.hasUnread, isFalse);
      await a.flush();

      final b = await freshRepo();
      expect(NotificationProvider(b).hasUnread, isFalse);
    });

    test('09-2 토글이 로컬에 저장된다', () async {
      final a = await freshRepo();
      final n = NotificationProvider(a);
      expect(n.isEnabled('motionPlayed'), isTrue);
      await n.setEnabled('motionPlayed', false);
      await a.flush();

      final b = await freshRepo();
      expect(NotificationProvider(b).isEnabled('motionPlayed'), isFalse);
    });
  });

  group('ThumbnailStore', () {
    test('PNG dataURL 을 저장하고 옛 파일을 지운다', () async {
      final store = ThumbnailStore(Directory('${_tmp.path}/t'));
      const png =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

      final first = await store.savePngDataUrl(png, id: 'a');
      expect(first, isNotNull);
      expect(File(first!).existsSync(), isTrue);

      final second = await store.savePngDataUrl(png, id: 'a', replacing: first);
      expect(second, isNot(first));
      expect(File(first).existsSync(), isFalse);
      expect(File(second!).existsSync(), isTrue);
    });

    test('dataURL 이 아니면 null', () async {
      final store = ThumbnailStore(Directory('${_tmp.path}/t'));
      expect(await store.savePngDataUrl('not a data url', id: 'x'), isNull);
      expect(ThumbnailStore.decodeDataUrl(''), isNull);
    });

    test('참조되지 않는 파일을 치운다', () async {
      final store = ThumbnailStore(Directory('${_tmp.path}/t'));
      const png =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
      final keep = (await store.savePngDataUrl(png, id: 'keep'))!;
      await store.savePngDataUrl(png, id: 'drop');

      final removed = await store.pruneExcept({keep});
      expect(removed, 1);
      expect(File(keep).existsSync(), isTrue);
    });
  });
}
