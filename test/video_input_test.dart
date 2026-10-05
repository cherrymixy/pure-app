import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:pure_app/services/thumbnail_store.dart';
import 'package:pure_app/services/video_input_service.dart';

/// 1x1 JPEG.
final _jpeg = base64Decode(
  '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0a'
  'HBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAA'
  'AAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==',
);

void main() {
  group('frameTimestampsMs — 구간 안에서만 고르게 뽑는다', () {
    test('PRD 예시: 48초 영상의 0:06~0:36 구간', () {
      final ts = VideoInputService.frameTimestampsMs(startSec: 6, endSec: 36);
      expect(ts, hasLength(8));
      for (final t in ts) {
        expect(t, greaterThanOrEqualTo(6000), reason: '구간 앞을 벗어났다');
        expect(t, lessThanOrEqualTo(36000), reason: '구간 뒤를 벗어났다');
      }
      // 간격이 일정하다.
      final gaps = [
        for (var i = 1; i < ts.length; i++) ts[i] - ts[i - 1],
      ];
      expect(gaps.toSet(), hasLength(1), reason: '간격이 균등해야 한다');
      expect(gaps.first, 3750, reason: '30초 / 8장');
    });

    test('양 끝을 집지 않는다 (첫 프레임 페이드인·마지막 끊김 회피)', () {
      final ts = VideoInputService.frameTimestampsMs(startSec: 0, endSec: 8);
      expect(ts.first, greaterThan(0));
      expect(ts.last, lessThan(8000));
      expect(ts.first, 500);
      expect(ts.last, 7500);
    });

    test('30초 이하 영상은 전체가 구간', () {
      final range = VideoInputService.defaultRange(12);
      expect(range, (0.0, 12.0));
      final ts = VideoInputService.frameTimestampsMs(
        startSec: range.$1,
        endSec: range.$2,
      );
      expect(ts, hasLength(8));
      expect(ts.last, lessThan(12000));
    });

    test('30초 초과 영상은 앞 30초가 기본 구간', () {
      expect(VideoInputService.defaultRange(48), (0.0, 30.0));
      expect(VideoInputService.defaultRange(30), (0.0, 30.0));
      expect(VideoInputService.defaultRange(30.5), (0.0, 30.0));
    });

    test('아주 짧은 영상도 8장을 만든다', () {
      final ts = VideoInputService.frameTimestampsMs(startSec: 0, endSec: 0.4);
      expect(ts, hasLength(8));
      expect(ts.first, greaterThanOrEqualTo(0));
      expect(ts.last, lessThanOrEqualTo(400));
    });

    test('구간이 0 이어도 터지지 않는다', () {
      final ts = VideoInputService.frameTimestampsMs(startSec: 5, endSec: 5);
      expect(ts, hasLength(8));
      expect(ts.every((t) => t == 5000), isTrue);
    });

    test('장수를 바꿔도 구간을 지킨다', () {
      for (final n in [1, 2, 3, 16]) {
        final ts =
            VideoInputService.frameTimestampsMs(startSec: 10, endSec: 20, count: n);
        expect(ts, hasLength(n));
        for (final t in ts) {
          expect(t, inInclusiveRange(10000, 20000));
        }
      }
      expect(VideoInputService.frameTimestampsMs(startSec: 0, endSec: 10, count: 0),
          isEmpty);
    });
  });

  group('clampRange — Trim 시트가 고른 구간을 다듬는다', () {
    test('30초를 넘기면 끝을 당긴다', () {
      expect(VideoInputService.clampRange(10, 60, 90), (10.0, 40.0));
    });

    test('영상 밖으로 나가면 안쪽으로 당긴다', () {
      final r = VideoInputService.clampRange(-5, 200, 48);
      expect(r.$1, greaterThanOrEqualTo(0));
      expect(r.$2, lessThanOrEqualTo(48));
      expect(r.$2 - r.$1, lessThanOrEqualTo(30));
    });

    test('끝이 시작보다 앞이면 뒤집지 않고 최소 길이를 준다', () {
      final r = VideoInputService.clampRange(20, 10, 48);
      expect(r.$2, greaterThan(r.$1));
    });

    test('짧은 영상은 전체를 넘지 않는다', () {
      final r = VideoInputService.clampRange(0, 100, 5);
      expect(r, (0.0, 5.0));
    });
  });

  group('extractFrames', () {
    test('8장을 구간 안 시점으로 요청한다', () async {
      final asked = <int>[];
      final service = VideoInputService(
        frameGrabber: (path, ms) async {
          asked.add(ms);
          return _jpeg;
        },
      );
      final attachment = await service.attachmentFor('/fake/video.mp4');
      expect(attachment, isNull, reason: '길이를 못 읽으면 첨부를 만들지 않는다');

      final svc2 = VideoInputService(
        durationReader: (_) async => const Duration(seconds: 48),
        frameGrabber: (path, ms) async {
          asked.add(ms);
          return _jpeg;
        },
      );
      final a2 = await svc2.attachmentFor('/fake/video.mp4');
      expect(a2, isNotNull);
      expect(a2!.durationSec, 48);
      expect(a2.trimStart, 0);
      expect(a2.trimEnd, 30);

      asked.clear();
      final frames = await svc2.extractFrames(a2);
      expect(frames, hasLength(8));
      expect(asked, hasLength(8));
      for (final ms in asked) {
        expect(ms, inInclusiveRange(0, 30000));
      }
      for (final f in frames) {
        expect(f, startsWith('data:image/jpeg;base64,'));
      }
    });

    test('일부가 실패해도 나머지로 간다', () async {
      var n = 0;
      final service = VideoInputService(
        durationReader: (_) async => const Duration(seconds: 10),
        frameGrabber: (path, ms) async {
          n++;
          return n.isEven ? _jpeg : null;
        },
      );
      final a = await service.attachmentFor('/fake/v.mp4');
      n = 0;
      final frames = await service.extractFrames(a!);
      expect(frames, hasLength(4));
    });

    test('전부 실패하면 빈 목록 (텍스트만으로 생성한다)', () async {
      final service = VideoInputService(
        durationReader: (_) async => const Duration(seconds: 10),
        frameGrabber: (_, __) async => null,
      );
      final a = await service.attachmentFor('/fake/v.mp4');
      expect(await service.extractFrames(a!), isEmpty);
    });

    test('추출이 던져도 삼키지 않고 빈 목록으로 떨어진다', () async {
      final service = VideoInputService(
        durationReader: (_) async => const Duration(seconds: 10),
        frameGrabber: (_, __) async => Uint8List(0),
      );
      final a = await service.attachmentFor('/fake/v.mp4');
      expect(await service.extractFrames(a!), isEmpty);
    });
  });

  group('첨부와 썸네일', () {
    late Directory tmp;
    setUp(() async => tmp = await Directory.systemTemp.createTemp('pure_vid_'));
    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('구간 시작 프레임을 썸네일로 저장한다', () async {
      final store = ThumbnailStore(tmp);
      final service = VideoInputService(
        store: store,
        durationReader: (_) async => const Duration(seconds: 12),
        frameGrabber: (_, __) async => _jpeg,
      );
      final a = await service.attachmentFor('/fake/v.mp4');
      expect(a!.thumbPath, isNotEmpty);
      expect(File(a.thumbPath).existsSync(), isTrue);
    });

    test('원본 경로를 그대로 들고 있다 (앱 밖으로 나가지 않는다)', () async {
      final service = VideoInputService(
        durationReader: (_) async => const Duration(seconds: 5),
        frameGrabber: (_, __) async => _jpeg,
      );
      final a = await service.attachmentFor('/private/var/video.MOV');
      expect(a!.path, '/private/var/video.MOV');
      expect(a.selectedSec, 5);
    });

    test('길이가 0 이면 첨부를 만들지 않는다', () async {
      final service = VideoInputService(
        durationReader: (_) async => Duration.zero,
        frameGrabber: (_, __) async => _jpeg,
      );
      expect(await service.attachmentFor('/fake/v.mp4'), isNull);
    });
  });
}
