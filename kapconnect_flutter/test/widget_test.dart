import 'package:flutter_test/flutter_test.dart';
import 'package:kapconnect/main.dart';

void main() {
  testWidgets('dashboard renders', (tester) async {
    await tester.pumpWidget(const KapConnectApp());
    expect(find.text('KapConnect'), findsOneWidget);
    expect(find.text('Search Jobs'), findsOneWidget);
  });
}
