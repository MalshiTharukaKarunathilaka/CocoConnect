import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kapconnect_mobile/screens/account_dialogs.dart';
import 'package:kapconnect_mobile/services/auth_service.dart';

void main() {
  for (final role in [
    'BUYER',
    'ESTATE_OWNER',
    'ESTATE_MANAGER',
    'WORKER',
    'SERVICE_PROVIDER',
    'FERTILIZER_SUPPLIER',
    'CDO',
    'REGIONAL_MANAGER',
    'CHAIRMAN',
    'ADMIN',
  ]) {
    testWidgets('$role cancels or confirms logout explicitly', (tester) async {
      SharedPreferences.setMockInitialValues({'auth_token': 'saved-token'});
      final user = AppUser(
        id: 1,
        name: 'Test',
        phone: '0771234567',
        role: role,
      );
      AuthService.currentUser = user;
      addTearDown(() => AuthService.currentUser = null);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => confirmLogOut(context),
                child: const Text('Leave account'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Leave account'));
      await tester.pumpAndSettle();
      expect(find.text('Are you sure you want to log out?'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Log Out'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(AuthService.currentUser, same(user));
      expect(
        (await SharedPreferences.getInstance()).getString('auth_token'),
        'saved-token',
      );
      await tester.tap(find.text('Leave account'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Log Out'));
      await tester.pumpAndSettle();
      expect(AuthService.currentUser, isNull);
      expect(
        (await SharedPreferences.getInstance()).getString('auth_token'),
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
