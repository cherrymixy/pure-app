import 'package:flutter_test/flutter_test.dart';

import 'package:pure_app/config/env.dart';
import 'package:pure_app/sim/sim_controller.dart';

void main() {
  group('Env', () {
    test('키 없이 빌드하면 데모 모드다', () {
      expect(Env.hasApiKey, isFalse);
      expect(Env.apiKey, isNull);
    });

    test('모델 기본값이 PRD 와 일치한다', () {
      expect(Env.model, 'gpt-4o-mini');
      expect(Env.visionModel, 'gpt-4o');
    });
  });

  group('SimEvent.parse — sim/src/runtime.ts 의 SimEvent 와 같은 모양', () {
    test('ready 에서 관절 범위를 계약 이름으로 읽는다', () {
      final e = SimEvent.parse({
        'type': 'ready',
        'limits': {
          'base_yaw': [-150, 150],
          'head_tilt': [-33, 42],
        },
        'behaviors': ['idle', 'greet'],
        'faces': ['neutral', 'heart'],
      });
      expect(e, isA<SimReady>());
      final ready = e! as SimReady;
      expect(ready.limits['head_tilt'], (-33.0, 42.0));
      expect(ready.behaviors, ['idle', 'greet']);
      expect(ready.faces, ['neutral', 'heart']);
    });

    test('playing / ended 를 구분한다', () {
      final playing = SimEvent.parse({
        'type': 'playing',
        'id': 'p1',
        'duration': 2.5,
        'behavior': 'greet',
      });
      expect(playing, isA<SimPlaying>());
      expect((playing! as SimPlaying).durationSec, 2.5);

      final ended = SimEvent.parse({'type': 'ended', 'id': 'p1'});
      expect((ended! as SimEnded).id, 'p1');
    });

    test('JSON 문자열로 와도 읽는다', () {
      final e = SimEvent.parse('{"type":"error","message":"boom"}');
      expect((e! as SimError).message, 'boom');
    });

    test('모르는 타입은 null 로 흘린다 (던지지 않는다)', () {
      expect(SimEvent.parse({'type': 'nope'}), isNull);
      expect(SimEvent.parse(null), isNull);
      expect(SimEvent.parse(42), isNull);
    });
  });
}
