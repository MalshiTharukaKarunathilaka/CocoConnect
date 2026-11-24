import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapconnect_mobile/screens/live_machinery_booking.dart';

void main() {
  testWidgets('request dialog has no start/end time to pick', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => requestLiveMachinery(
              context,
              machineId: 1,
              date: DateTime(2030, 3, 4),
              items: const [],
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Request Machinery'), findsOneWidget);
    expect(find.text('Start time'), findsNothing);
    expect(find.text('End time'), findsNothing);
    expect(find.text('Monday, March 4, 2030'), findsOneWidget);
    expect(find.textContaining('8:00 AM - 5:00 PM'), findsOneWidget);
  });
}
