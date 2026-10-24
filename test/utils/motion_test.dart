import 'package:clipious/globals.dart';
import 'package:clipious/utils/views/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('motion tokens', () {
    test('durations are ordered and routine motion stays below 400ms', () {
      expect(motionFast, const Duration(milliseconds: 100));
      expect(motionShort, const Duration(milliseconds: 150));
      expect(motionBase, const Duration(milliseconds: 200));
      expect(motionMedium, const Duration(milliseconds: 250));
      expect(motionPage, const Duration(milliseconds: 300));
      expect(motionEmphasized,
          lessThanOrEqualTo(const Duration(milliseconds: 400)));
    });

    testWidgets('reduced motion collapses changed animations to zero',
        (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(builder: (context) {
            captured = context;
            return const SizedBox();
          }),
        ),
      );

      expect(isReducedMotion(captured), isTrue);
      expect(motionDuration(captured, motionShort), Duration.zero);
    });

    testWidgets('normal motion keeps the requested duration', (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: Builder(builder: (context) {
            captured = context;
            return const SizedBox();
          }),
        ),
      );

      expect(isReducedMotion(captured), isFalse);
      expect(motionDuration(captured, motionShort), motionShort);
    });
  });
}
