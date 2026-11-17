import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapconnect_mobile/screens/account_dialogs.dart';
import 'package:kapconnect_mobile/widgets/profile_widgets.dart';

void main() {
  for (final role in [
    'BUYER', 'ESTATE_OWNER', 'WORKER', 'SERVICE_PROVIDER',
    'FERTILIZER_SUPPLIER', 'CDO', 'REGIONAL_MANAGER', 'CHAIRMAN',
  ]) {
    testWidgets('$role profile fits a narrow screen with enlarged text', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var edits = 0;
      await tester.pumpWidget(MaterialApp(home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: Scaffold(body: ListView(
          padding: const EdgeInsets.all(20), children: [
            const ProfileTitle(),
            ProfileIdentityCard(name: 'Samantha Wijesinghe Jayawardena',
              role: roleLabel(role), phone: '0771234567',
              location: 'Coconut Estate, Kurunegala, Sri Lanka'),
            const SizedBox(height: 18),
            const ProfileStatsGrid(children: [
              ProfileStatTile(value: '120', label: 'Completed orders',
                icon: Icons.check_circle_outline),
              ProfileStatTile(value: '4.8', label: 'Average rating',
                icon: Icons.star_outline),
            ]),
            const SizedBox(height: 18),
            ProfileAccountCard(onEdit: () => edits++),
          ],
        )),
      )));
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Edit profile'), 160);
      await tester.ensureVisible(find.text('Edit profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit profile'));
      expect(edits, 1);
      await tester.scrollUntilVisible(find.text('Log out'), 100);
      await tester.ensureVisible(find.text('Log out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
