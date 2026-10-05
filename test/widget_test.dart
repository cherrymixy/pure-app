import 'package:flutter_test/flutter_test.dart';

import 'package:pure_app/config/env.dart';
import 'package:pure_app/main.dart';

void main() {
  testWidgets('스캐폴드가 워드마크를 렌더한다', (tester) async {
    await tester.pumpWidget(const PureApp());
    expect(find.text('PURE'), findsOneWidget);
  });

  testWidgets('키 주입 여부에 따라 모드 표시가 갈린다', (tester) async {
    await tester.pumpWidget(const PureApp());
    // --dart-define 없이 돌리는 기본 테스트 실행에서는 데모 모드여야 한다.
    expect(Env.hasApiKey, isFalse);
    expect(find.text('Demo mode (no API key)'), findsOneWidget);
  });

  test('모델 기본값이 PRD 와 일치한다', () {
    expect(Env.model, 'gpt-4o-mini');
    expect(Env.visionModel, 'gpt-4o');
    expect(Env.apiKey, isNull);
  });
}
