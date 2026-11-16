import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapconnect_mobile/screens/service_provider_registration_page.dart';
import 'package:kapconnect_mobile/widgets/owner_widgets.dart';
import 'package:kapconnect_mobile/services/auth_service.dart';
import 'package:kapconnect_mobile/utils/sri_lanka_nic.dart';

Future<RegistrationStorage> _persistentStorage() async =>
    const RegistrationStorage(persistent: true, ready: true);
Future<RegistrationStorage> _temporaryStorage() async =>
    const RegistrationStorage(persistent: false, ready: true);

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'registration fits $width px and defers machinery setup to the calendar',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: const ServiceProviderRegistrationPage(
              storageLoader: _persistentStorage,
            ),
          ),
        );
        expect(find.byType(OwnerPage), findsOneWidget);
        expect(find.text('Provider Registration'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(find.text('Machinery Category *'), findsNothing);
        expect(find.text('Tractor'), findsNothing);
        expect(
          find.textContaining('After registration, add your machinery'),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.text('Complete & Register Account'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'submitting at the bottom validates off-screen fields and reveals the first error',
    (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const ServiceProviderRegistrationPage(
            storageLoader: _persistentStorage,
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Complete & Register Account'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      // Previously the lazy list disposed the account fields at this position.
      expect(find.byType(TextFormField), findsNWidgets(7));
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.ensureVisible(find.text('Complete & Register Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Complete & Register Account'));
      await tester.pumpAndSettle();
      expect(
        tester
            .state<FormFieldState<String>>(find.byType(TextFormField).first)
            .hasError,
        isTrue,
      );
      final district = find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.initialValue == null,
      );
      expect(tester.state<FormFieldState<String>>(district).hasError, isTrue);
      expect(
        tester.getRect(find.byType(TextFormField).first).top,
        greaterThanOrEqualTo(0),
      );
      expect(
        tester.getRect(find.byType(TextFormField).first).bottom,
        lessThan(800),
      );
      expect(
        find.text('Select your operating base using GPS or the map.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the NIC and email checks match backend validation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ServiceProviderRegistrationPage(
          storageLoader: _persistentStorage,
        ),
      ),
    );
    final fields = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .toList();
    expect(fields[2].validator!('A' * 41), nicFormatMessage);
    expect(
      fields[3].validator!('a' * 255 + '@example.com'),
      'Use at most 254 characters',
    );
  });
  testWidgets(
    'temporary backend is clearly identified before account creation',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ServiceProviderRegistrationPage(
            storageLoader: _temporaryStorage,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Accounts are NOT saved to Supabase'),
        findsOneWidget,
      );
      expect(find.text('Create Temporary Account'), findsOneWidget);
      expect(
        find.text('Connected to shared database. Your account will be saved.'),
        findsNothing,
      );
    },
  );
  testWidgets('persistent backend reports that the account will be saved', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ServiceProviderRegistrationPage(
          storageLoader: _persistentStorage,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Connected to shared database. Your account will be saved.'),
      findsOneWidget,
    );
    expect(find.text('Create Temporary Account'), findsNothing);
  });
}
