import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kapconnect_mobile/services/api_client.dart';

void main() {
  test(
    'registration response preserves field errors for inline display',
    () async {
      await http.runWithClient(
        () async {
          try {
            await ApiClient.post('/api/auth/signup');
            fail('Expected validation failure');
          } on ApiException catch (error) {
            expect(error.statusCode, 400);
            expect(error.message, 'Select your operating district.');
            expect(error.fieldErrors, {
              'district': 'Select your operating district.',
            });
          }
        },
        () => MockClient(
          (_) async => http.Response(
            '{"message":"Select your operating district.","fieldErrors":{"district":"Select your operating district."}}',
            400,
          ),
        ),
      );
    },
  );

  test('existing errors without field errors remain compatible', () async {
    await http.runWithClient(
      () async {
        try {
          await ApiClient.post('/api/auth/login');
          fail('Expected login failure');
        } on ApiException catch (error) {
          expect(error.message, 'Incorrect phone number or password');
          expect(error.fieldErrors, isEmpty);
        }
      },
      () => MockClient(
        (_) async => http.Response(
          '{"message":"Incorrect phone number or password"}',
          401,
        ),
      ),
    );
  });
}
