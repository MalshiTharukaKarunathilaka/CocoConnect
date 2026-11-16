import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kapconnect_mobile/services/auth_service.dart';
import 'package:kapconnect_mobile/widgets/app_bottom_nav.dart';
import 'package:kapconnect_mobile/widgets/owner_widgets.dart';
import 'package:kapconnect_mobile/widgets/buyer_widgets.dart';
import 'package:kapconnect_mobile/widgets/role_navigation_page.dart';
import 'package:kapconnect_mobile/screens/orders/orders_page.dart';
import 'package:kapconnect_mobile/screens/chat/chats_page.dart';
import 'package:kapconnect_mobile/screens/buyer/buyer_profile_page.dart';
import 'package:kapconnect_mobile/screens/estate_owner_profile_page.dart';

final _client = MockClient((request) async {
  if (request.url.path == '/api/activity') {
    return http.Response(
      jsonEncode({
        'pending': [],
        'negotiations': [],
        'deals': [],
        'transactions': [],
      }),
      200,
    );
  }
  if ([
    '/api/chats',
    '/api/notifications',
    '/api/buyer/requests',
    '/api/buyer/orders',
  ].contains(request.url.path)) {
    return http.Response('[]', 200);
  }
  return http.Response('{}', 200);
});

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => AuthService.currentUser = null);
  for (final role in ['BUYER', 'ESTATE_OWNER']) {
    testWidgets(
      '$role has one menu with actions preserved and keyboard clearance',
      (tester) async {
        AuthService.currentUser = AppUser(
          id: 1,
          name: 'Test',
          phone: '0770000000',
          role: role,
        );
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await http.runWithClient(() async {
          final pages = <Widget>[
            const OwnerPage(child: Text('Page content')),
            const OwnerPage(
              bottom: Text('Booking action'),
              child: Text('Page content'),
            ),
            const OwnerPage(
              bottom: AppBottomNav(current: AppTab.orders),
              child: Text('Page content'),
            ),
            const RoleNavigationPage(
              child: Scaffold(body: Text('Page content')),
            ),
            if (role == 'BUYER')
              const BuyerScaffold(body: Text('Page content')),
          ];
          for (final page in pages) {
            await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: page));
            await tester.pumpAndSettle();
            expect(find.byType(AppBottomNav), findsOneWidget);
            for (final label in [
              'Dashboard',
              'Orders',
              'Chats',
              'Alerts',
              'Profile',
            ]) {
              expect(find.text(label).hitTestable(), findsOneWidget);
            }
            expect(tester.takeException(), isNull);
            tester.view.viewInsets = const FakeViewPadding(bottom: 230);
            await tester.pumpAndSettle();
            expect(
              tester.getBottomRight(find.byType(AppBottomNav)).dy,
              lessThanOrEqualTo(470),
            );
            if (page is OwnerPage && page.bottom is Text) {
              expect(find.text('Booking action'), findsOneWidget);
            }
            expect(tester.takeException(), isNull);
            tester.view.resetViewInsets();
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          }
        }, () => _client);
      },
    );

    testWidgets(
      '$role can switch sections and return home from a nested page',
      (tester) async {
        AuthService.currentUser = AppUser(
          id: 1,
          name: 'Test',
          phone: '0770000000',
          role: role,
        );
        await http.runWithClient(() async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => FilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const OwnerPage(child: Text('Nested page')),
                      ),
                    ),
                    child: const Text('Open nested page'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open nested page'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Dashboard'));
          await tester.pumpAndSettle();
          expect(find.text('Open nested page'), findsOneWidget);
          expect(find.text('Nested page'), findsNothing);
          await tester.tap(find.text('Open nested page'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Orders'));
          await tester.pumpAndSettle();
          expect(find.byType(OrdersPage), findsOneWidget);
          expect(find.byType(AppBottomNav), findsOneWidget);
          await tester.tap(find.text('Profile'));
          await tester.pumpAndSettle();
          expect(
            find.byType(
              role == 'BUYER' ? BuyerProfilePage : EstateOwnerProfilePage,
            ),
            findsOneWidget,
          );
          expect(find.byType(AppBottomNav), findsOneWidget);
          await tester.tap(find.text('Chats'));
          await tester.pumpAndSettle();
          expect(find.byType(ChatsPage), findsOneWidget);
          expect(find.byType(AppBottomNav), findsOneWidget);
          await tester.tap(find.text('Dashboard'));
          await tester.pumpAndSettle();
          expect(find.text('Open nested page'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }, () => _client);
      },
    );
  }

  testWidgets(
    'role wrapper leaves provider and signed-out screens without buyer navigation',
    (tester) async {
      for (final role in [null, 'SERVICE_PROVIDER', 'WORKER']) {
        AuthService.currentUser = role == null
            ? null
            : AppUser(
                id: 1,
                name: 'Other role',
                phone: '0770000000',
                role: role,
              );
        await tester.pumpWidget(
          const MaterialApp(
            home: RoleNavigationPage(
              child: Scaffold(body: Text('Other screen')),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(AppBottomNav), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}
