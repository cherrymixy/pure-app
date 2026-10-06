import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pure_app/theme/app_motion.dart';
import 'package:pure_app/widgets/appear.dart';
import 'package:pure_app/widgets/press_scale.dart';

/// STEP 24 연출. 눈으로 봐야 하는 건 시뮬레이터에서 보고, 여기서는 **꺼지는지**를
/// 본다 — '동작 줄이기' 폴백이 조용히 깨지면 아무도 모른다.
void main() {
  /// 주어진 [MediaQueryData] 아래에서 위젯을 띄운다.
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    bool reduceMotion = false,
  }) =>
      tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: child,
          ),
        ),
      );

  group('AppMotion.maybe', () {
    testWidgets('평소에는 길이를 그대로 돌려준다', (tester) async {
      late Duration seen;
      await pump(
        tester,
        Builder(
          builder: (context) {
            seen = AppMotion.maybe(context, AppMotion.enter);
            return const SizedBox();
          },
        ),
      );
      expect(seen, AppMotion.enter);
    });

    testWidgets('동작 줄이기를 켜면 0 이다', (tester) async {
      late Duration seen;
      await pump(
        tester,
        Builder(
          builder: (context) {
            seen = AppMotion.maybe(context, AppMotion.enter);
            return const SizedBox();
          },
        ),
        reduceMotion: true,
      );
      expect(seen, Duration.zero);
    });
  });

  group('Appear', () {
    testWidgets('흐림에서 또렷해지며 올라온다', (tester) async {
      await pump(tester, const Appear(child: Text('hi')));

      // 첫 프레임 뒤 애니메이션이 시작한다.
      await tester.pump();
      final start = tester.widget<Opacity>(find.byType(Opacity)).opacity;
      expect(start, lessThan(1));

      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
      final moved = tester.widget<Transform>(find.byType(Transform));
      expect(moved.transform.getTranslation().y, 0);
    });

    testWidgets('동작 줄이기를 켜면 처음부터 또렷하다', (tester) async {
      await pump(
        tester,
        const Appear(child: Text('hi')),
        reduceMotion: true,
      );
      await tester.pump();
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    });
  });

  group('PressScale', () {
    testWidgets('누르는 동안 작아지고 떼면 돌아온다', (tester) async {
      await pump(
        tester,
        const Center(
          child: PressScale(
            // Listener 는 자식이 히트 테스트를 받아야 포인터를 본다.
            child: ColoredBox(
              color: Color(0xFF000000),
              child: SizedBox(width: 50, height: 50),
            ),
          ),
        ),
      );

      double scale() =>
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
      expect(scale(), 1);

      final gesture = await tester.startGesture(tester.getCenter(find.byType(PressScale)));
      await tester.pump();
      expect(scale(), 0.96);

      await gesture.up();
      await tester.pump();
      expect(scale(), 1);
    });

    testWidgets('enabled 가 false 면 반응하지 않는다', (tester) async {
      await pump(
        tester,
        const Center(
          child: PressScale(
            enabled: false,
            child: ColoredBox(
              color: Color(0xFF000000),
              child: SizedBox(width: 50, height: 50),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.byType(PressScale)));
      await tester.pump();
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        1,
      );
      await gesture.up();
    });
  });
}
