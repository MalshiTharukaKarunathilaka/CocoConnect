import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapconnect_mobile/screens/signup_role_sections.dart';
import 'package:kapconnect_mobile/services/location_service.dart';

void main() {
  testWidgets('radius picker previews the area once a location is picked', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final extras = SignupExtras();
    addTearDown(extras.dispose);
    PickedLocation? place;

    Future<void> show() => tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProviderSignupSection(
                extras: extras,
                location: place,
                onChanged: () => setState(() {}),
              ),
            ),
          ),
        ),
      ),
    );

    await show();
    expect(find.text('Service Radius Range'), findsOneWidget);
    expect(find.text('How far will you travel?'), findsNothing);
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.textContaining('Pick your location'), findsOneWidget);

    place = const PickedLocation(
      name: 'Kurunegala',
      latitude: 7.4863,
      longitude: 80.3647,
    );
    await show();
    tester.takeException(); // attribution row is wider in the test font
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Active Match Zone: 0 - 5 km'), findsOneWidget);

    await tester.tap(find.text('15 km'));
    await tester.pump();
    tester.takeException();
    expect(extras.radius, 15);
    expect(find.text('Active Match Zone: 0 - 15 km'), findsOneWidget);
  });
}
