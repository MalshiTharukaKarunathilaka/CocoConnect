import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kapconnect_mobile/screens/coconuts_page.dart';
import 'package:kapconnect_mobile/screens/dehusked_coconuts_page.dart';

void main() {
  testWidgets(
    'dehusked category opens its selling screen and requests its buyers',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final requests = <Uri>[];
      final client = MockClient((request) async {
        requests.add(request.url);
        if (request.url.path == '/api/owner/estate') {
          return http.Response(
            jsonEncode({'id': 1, 'estate_name': 'Test estate'}),
            200,
          );
        }
        if (request.url.path == '/api/owner/market-stats') {
          return http.Response('{}', 200);
        }
        return http.Response('[]', 200);
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: CoconutsPage()));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dehusked Coconuts'));
        await tester.pumpAndSettle();
        expect(find.byType(DehuskedCoconutsPage), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Interested Buyers'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(DehuskedCoconutsPage),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('Interested Buyers'), findsOneWidget);
        expect(
          requests.any(
            (uri) =>
                uri.path == '/api/owner/buyer-requests' &&
                uri.queryParameters['type'] == 'DEHUSKED_COCONUT',
          ),
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    },
  );
}
