import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapconnect_mobile/screens/signup_page.dart';

void main() {
  testWidgets(
    'each role shows its own fields under the form, on the same page',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: SignupPage()));
      tester.takeException(); // test-font overflow in the existing phone row

      expect(find.text('Your estate'), findsOneWidget);
      expect(find.textContaining('I confirm my details'), findsOneWidget);
      expect(find.text('Machinery provider details'), findsNothing);

      await tester.tap(find.text('Service Provider'));
      await tester.pumpAndSettle();
      tester.takeException(); // test-font overflow in the existing phone row
      expect(find.byType(SignupPage), findsOneWidget);
      expect(find.text('Machinery provider details'), findsOneWidget);
      expect(find.text('NIC Number'), findsOneWidget);
      expect(find.textContaining('I confirm my details'), findsOneWidget);
      expect(find.text('Your estate'), findsNothing);

      await tester.tap(find.text('Buyer'));
      await tester.pumpAndSettle();
      tester.takeException(); // test-font overflow in the existing phone row
      expect(find.text('Machinery provider details'), findsNothing);
      expect(find.text('Buyer'), findsWidgets);
      expect(find.textContaining('I confirm my details'), findsOneWidget);
    },
  );
}
