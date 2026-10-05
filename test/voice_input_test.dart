import 'package:flutter_test/flutter_test.dart';

import 'package:pure_app/providers/voice_provider.dart';
import 'package:pure_app/services/voice_input_service.dart';

/// 플러그인을 부르지 않는 서비스. 상태 전이와 배선만 본다.
///
/// 음성 인식 자체는 실기기에서만 의미 있게 확인된다 — 시뮬레이터 마이크는
/// 신뢰할 수 없다는 게 조사 결과였다.
class _TestService extends VoiceInputService {
  bool started = false;
  bool stopped = false;
  bool cancelled = false;

  @override
  Future<bool> initialize() async {
    markInitialized();
    return true;
  }

  @override
  Future<bool> start() async {
    started = true;
    markListening();
    return true;
  }

  @override
  Future<void> stop() async {
    stopped = true;
    emitPlatformStatus('done');
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
    markInitialized();
  }
}

void main() {
  group('VoiceInputService — 설정값과 상태 전이', () {
    test('PRD 값: 영어 · 2초 무음 종료', () {
      expect(VoiceInputService.localeId, 'en_US');
      expect(VoiceInputService.silenceTimeout, const Duration(seconds: 2));
      expect(VoiceInputService.maxListen, const Duration(seconds: 30));
    });

    test('중간 결과는 듣는 중을 유지하고, 최종 결과에서 끝난다', () async {
      final s = _TestService();
      await s.start();
      expect(s.isListening, isTrue);

      s.emitResult('someone', isFinal: false);
      expect(s.transcript, 'someone');
      expect(s.isListening, isTrue, reason: '중간 결과로 끝나면 안 된다');

      s.emitResult('someone just came home', isFinal: true);
      expect(s.transcript, 'someone just came home');
      expect(s.status, VoiceStatus.done);
      await s.dispose();
    });

    test('음량을 0~1 로 편다', () async {
      final s = _TestService();
      final seen = <double>[];
      final sub = s.soundLevel.listen(seen.add);

      s.emitLevel(-10);
      s.emitLevel(-2);
      s.emitLevel(4);
      s.emitLevel(100);
      await Future<void>.delayed(Duration.zero);

      expect(seen, hasLength(4));
      expect(seen[0], 0.0, reason: '하한 아래는 0');
      expect(seen[1], 0.0);
      expect(seen[2], closeTo(0.5, 1e-9));
      expect(seen[3], 1.0, reason: '상한 위는 1');
      await sub.cancel();
      await s.dispose();
    });

    test('권한 거부는 따로 구분한다 (01-E1 시트를 띄워야 한다)', () async {
      final s = _TestService();
      await s.start();
      s.emitError('speech_recognition_permission_denied');
      expect(s.status, VoiceStatus.permissionDenied);
      expect(s.isPermissionDenied, isTrue);
      await s.dispose();
    });

    test('"아무 말 안 함"은 오류가 아니라 종료다', () async {
      for (final msg in ['error_no_match', 'error_speech_timeout']) {
        final s = _TestService();
        await s.start();
        s.emitError(msg);
        expect(s.status, VoiceStatus.done, reason: msg);
        expect(s.status, isNot(VoiceStatus.error));
        await s.dispose();
      }
    });

    test('그 밖의 오류는 error 로 올린다', () async {
      final s = _TestService();
      await s.start();
      s.emitError('error_audio');
      expect(s.status, VoiceStatus.error);
      await s.dispose();
    });

    test('플랫폼이 notListening 을 보내면 끝난다 (2초 무음 자동 종료 경로)', () async {
      final s = _TestService();
      await s.start();
      s.emitPlatformStatus('notListening');
      expect(s.status, VoiceStatus.done);
      await s.dispose();
    });

    test('cancel 은 받아 둔 문장을 버린다', () async {
      final s = _TestService();
      await s.start();
      s.emitResult('throw me away', isFinal: false);
      expect(s.transcript, isNotEmpty);
      await s.cancel();
      expect(s.status, VoiceStatus.idle);
      await s.dispose();
    });
  });

  group('VoiceProvider — 소비자 둘을 가른다', () {
    test('홈 입력창: 최종 결과를 한 번 전달한다 (자동 전송 X)', () async {
      final s = _TestService();
      final p = VoiceProvider(s);
      final delivered = <String>[];

      await p.start(
        consumer: VoiceConsumer.composer,
        onFinal: delivered.add,
      );
      expect(s.started, isTrue);
      expect(p.consumer, VoiceConsumer.composer);

      s.emitResult('someone came', isFinal: false);
      await Future<void>.delayed(Duration.zero);
      expect(p.text, 'someone came', reason: '실시간 자막');
      expect(delivered, isEmpty, reason: '중간 결과로 전달하면 안 된다');

      s.emitResult('someone came home', isFinal: true);
      await Future<void>.delayed(Duration.zero);
      expect(delivered, ['someone came home']);
      p.dispose();
    });

    test('최종 결과와 done 상태가 겹쳐도 두 번 보내지 않는다', () async {
      final s = _TestService();
      final p = VoiceProvider(s);
      final delivered = <String>[];

      await p.start(consumer: VoiceConsumer.questionFlow, onFinal: delivered.add);
      s.emitResult('a loud noise', isFinal: true);
      s.emitPlatformStatus('done');
      await Future<void>.delayed(Duration.zero);

      expect(delivered, hasLength(1),
          reason: '질문형에서 같은 답이 두 번 전송되면 단계가 건너뛴다');
      p.dispose();
    });

    test('수동 종료도 지금까지 들은 것을 전달한다', () async {
      final s = _TestService();
      final p = VoiceProvider(s);
      final delivered = <String>[];

      await p.start(consumer: VoiceConsumer.composer, onFinal: delivered.add);
      s.emitResult('half a sentence', isFinal: false);
      await Future<void>.delayed(Duration.zero);
      await p.stop();
      await Future<void>.delayed(Duration.zero);

      expect(s.stopped, isTrue);
      expect(delivered, ['half a sentence']);
      p.dispose();
    });

    test('빈 결과는 전달하지 않는다', () async {
      final s = _TestService();
      final p = VoiceProvider(s);
      final delivered = <String>[];

      await p.start(consumer: VoiceConsumer.composer, onFinal: delivered.add);
      s.emitResult('   ', isFinal: true);
      await Future<void>.delayed(Duration.zero);
      expect(delivered, isEmpty);
      p.dispose();
    });

    test('cancel 하면 그 뒤 결과는 전달되지 않는다', () async {
      final s = _TestService();
      final p = VoiceProvider(s);
      final delivered = <String>[];

      await p.start(consumer: VoiceConsumer.composer, onFinal: delivered.add);
      await p.cancel();
      s.emitResult('too late', isFinal: true);
      await Future<void>.delayed(Duration.zero);

      expect(s.cancelled, isTrue);
      expect(delivered, isEmpty);
      expect(p.consumer, isNull);
      p.dispose();
    });

    test('다시 시작하면 전달 잠금이 풀린다', () async {
      final s = _TestService();
      final p = VoiceProvider(s);
      final delivered = <String>[];

      await p.start(consumer: VoiceConsumer.composer, onFinal: delivered.add);
      s.emitResult('first', isFinal: true);
      await Future<void>.delayed(Duration.zero);

      await p.start(consumer: VoiceConsumer.questionFlow, onFinal: delivered.add);
      s.emitResult('second', isFinal: true);
      await Future<void>.delayed(Duration.zero);

      expect(delivered, ['first', 'second']);
      p.dispose();
    });

    test('파형 음량이 Provider 로 올라온다', () async {
      final s = _TestService();
      final p = VoiceProvider(s);
      await p.start(consumer: VoiceConsumer.composer, onFinal: (_) {});

      s.emitLevel(4);
      await Future<void>.delayed(Duration.zero);
      expect(p.level, closeTo(0.5, 1e-9));
      p.dispose();
    });
  });
}
