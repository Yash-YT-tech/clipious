import 'package:clipious/utils.dart';
import 'package:clipious/utils/views/components/device_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    Orientation orientation = Orientation.portrait,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: DeviceWidget(
            orientation: orientation,
            phone: const Text('phone-layout'),
            tablet: const Text('tablet-layout'),
          ),
        ),
      ),
    );
  }

  testWidgets('533dp portrait uses phone layout', (tester) async {
    await pumpAt(tester, const Size(533, 853));
    expect(find.text('phone-layout'), findsOneWidget);
    expect(find.text('tablet-layout'), findsNothing);
  });

  testWidgets('533dp landscape uses wide layout', (tester) async {
    await pumpAt(tester, const Size(853, 533),
        orientation: Orientation.landscape);
    expect(find.text('tablet-layout'), findsOneWidget);
    expect(find.text('phone-layout'), findsNothing);
  });

  testWidgets('600dp+ portrait uses wide layout', (tester) async {
    await pumpAt(tester, const Size(600, 960));
    expect(find.text('tablet-layout'), findsOneWidget);
  });

  testWidgets('wide but short landscape phone stays compact', (tester) async {
    await pumpAt(tester, const Size(800, 360),
        orientation: Orientation.landscape);
    expect(find.text('phone-layout'), findsOneWidget);
    expect(find.text('tablet-layout'), findsNothing);
  });
}
