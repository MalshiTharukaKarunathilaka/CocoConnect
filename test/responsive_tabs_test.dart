import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapconnect_mobile/widgets/owner_widgets.dart';

void main() {
  for (final width in [320.0, 360.0, 412.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'all Orders buttons are visible without horizontal scrolling at $width / $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var selected = -1;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: OwnerTabs(
                    labels: const ['Pending Orders', 'Deals', 'Transactions'],
                    badges: const [99, 99, 0],
                    selected: 2,
                    onSelected: (index) => selected = index,
                  ),
                ),
              ),
            ),
          );
          expect(
            find.descendant(
              of: find.byType(OwnerTabs),
              matching: find.byType(Scrollable),
            ),
            findsNothing,
          );
          for (final label in ['Pending Orders', 'Deals', 'Transactions']) {
            final finder = find.text(label);
            expect(finder.hitTestable(), findsOneWidget);
            final bounds = tester.getRect(finder);
            expect(bounds.left, greaterThanOrEqualTo(0));
            expect(bounds.right, lessThanOrEqualTo(width));
          }
          await tester.tap(find.text('Deals'));
          expect(selected, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
