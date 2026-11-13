import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapconnect_mobile/services/holiday_service.dart';
import 'package:kapconnect_mobile/widgets/holiday_widgets.dart';

void main() {
  setUp(HolidayService.reset);

  test('parse keeps public holiday over observance and skips bad rows', () {
    final m = HolidayService.parse({
      'holidays': [
        {'date': '2026-12-24', 'name': 'Christmas Eve', 'type': 'observance'},
        {'date': '2026-12-24', 'name': 'Poya', 'type': 'public'},
        {'date': 'bad', 'name': 'x', 'type': 'public'},
      ],
    });
    expect(m.length, 1);
    expect(m['2026-12-24']!.isPublic, true);
    expect(m['2026-12-24']!.name, 'Poya');
  });

  testWidgets('note and flag show only on holidays', (tester) async {
    HolidayService.seed(2026, {
      '2026-12-25': const Holiday('Christmas Day', isPublic: true),
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            HolidayNote(DateTime(2026, 12, 25)),
            HolidayNote(DateTime(2026, 12, 26)),
          ],
        ),
      ),
    );
    expect(find.textContaining('Christmas Day'), findsOneWidget);
    expect(find.byIcon(Icons.celebration_rounded), findsOneWidget);
  });
}
