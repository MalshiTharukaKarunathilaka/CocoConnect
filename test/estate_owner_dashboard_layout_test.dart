import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapconnect_mobile/screens/estate_owner_dashboard.dart';
import 'package:kapconnect_mobile/screens/coconuts_page.dart';
import 'package:kapconnect_mobile/widgets/reusable_widgets.dart';

void main() {
  for (final height in [568.0, 640.0, 844.0]) {
    testWidgets('all coconut categories fit at height $height', (tester) async {
      tester.view.physicalSize = Size(390, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: CoconutsPage()));
      await tester.pumpAndSettle();
      final bottomBar = tester.getRect(find.byType(CustomBottomNavigation));
      expect(find.text('1 unit = 1 nut').hitTestable(), findsNWidgets(3));
      expect(find.text('1 unit = 1 kg').hitTestable(), findsNothing);
      for (final title in [
        'Raw Coconuts(with husks)',
        'Dehusked Coconuts',
        'Only Husks',
      ]) {
        final label = find.text(title);
        expect(label.hitTestable(), findsOneWidget);
        final card = find.ancestor(
          of: label,
          matching: find.byType(CoconutProductCard),
        );
        expect(tester.getRect(card).bottom, lessThan(bottomBar.top));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('four complete dashboard rows fit at height $height', (
      tester,
    ) async {
      tester.view.physicalSize = Size(390, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: EstateOwnerDashboard()));
      final viewport = tester.getRect(find.byType(GridView));
      for (final title in [
        'Coconuts',
        'Fertilizer',
        'Spices',
        'Machinery',
        'Livestock',
        'Day Jobs',
        'Vegetables',
        'Skilled Jobs',
      ]) {
        final card = find.ancestor(
          of: find.text(title),
          matching: find.byType(DashboardCategoryCard),
        );
        final bounds = tester.getRect(card);
        expect(bounds.top, greaterThanOrEqualTo(viewport.top));
        expect(bounds.bottom, lessThanOrEqualTo(viewport.bottom - 8));
      }
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(GridView), const Offset(0, -1000));
      await tester.pumpAndSettle();
      for (final title in [
        'Fruits',
        'Other Goods',
        'Equipment',
        'Irrigation',
        'Miscellaneous',
      ]) {
        expect(find.text(title).hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
