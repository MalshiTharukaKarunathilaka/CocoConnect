import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapconnect_mobile/models/provider_calendar.dart';
import 'package:kapconnect_mobile/screens/auth_gate.dart';
import 'package:kapconnect_mobile/screens/provider/provider_calendar_page.dart';
import 'package:kapconnect_mobile/services/auth_service.dart';
import 'package:kapconnect_mobile/services/provider_calendar_repository.dart';

class _Repository implements ProviderCalendarRepository {
  int calls = 0;
  bool fail = false;
  Completer<ProviderCalendarMonth>? pending;
  @override
  bool get isPreview => true;
  @override
  Future<ProviderCalendarMonth> loadMonth(DateTime month) async {
    calls++;
    if (pending != null) return pending!.future;
    if (fail) throw StateError('Offline');
    return const ProviderCalendarMonth();
  }
}

Future<void> openCalendar(
  WidgetTester tester, {
  DateTime? date,
  ProviderCalendarRepository repository =
      const PreviewProviderCalendarRepository(),
  double width = 360,
  double scale = 1,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true, fontFamily: 'Arial'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: RepaintBoundary(
        key: const Key('preview-capture'),
        child: ProviderCalendarPage(
          initialDate: date ?? DateTime(2028, 1, 15),
          repository: repository,
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> showSelectedDay(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('selected-date')),
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'service provider home routes to calendar without changing buyer/owner routing',
    () {
      const provider = AppUser(
        id: 7,
        name: 'Provider',
        phone: '0771234567',
        role: 'SERVICE_PROVIDER',
      );
      expect(homeFor(provider), isA<ProviderCalendarPage>());
      expect(
        homeFor(
          const AppUser(
            id: 8,
            name: 'Buyer',
            phone: '0771234568',
            role: 'BUYER',
          ),
        ),
        isNot(isA<ProviderCalendarPage>()),
      );
      expect(
        homeFor(
          const AppUser(
            id: 9,
            name: 'Owner',
            phone: '0771234569',
            role: 'ESTATE_OWNER',
          ),
        ),
        isNot(isA<ProviderCalendarPage>()),
      );
    },
  );

  testWidgets('month navigation handles year rollover and leap-day selection', (
    tester,
  ) async {
    await openCalendar(tester, date: DateTime(2028, 1, 31));
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('December 2027'), findsOneWidget);
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('February 2028'), findsOneWidget);
    expect(find.byKey(const Key('provider-day-2028-02-29')), findsOneWidget);
    expect(find.byKey(const Key('provider-day-2028-02-30')), findsNothing);
    await showSelectedDay(tester);
    expect(find.text('Tuesday, February 29, 2028'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected date shows its incoming and confirmed booking counts', (
    tester,
  ) async {
    await openCalendar(tester);
    await tester.tap(find.byKey(const Key('provider-day-2028-01-16')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close inquiry'));
    await tester.pumpAndSettle();
    await showSelectedDay(tester);
    expect(find.text('Sunday, January 16, 2028'), findsOneWidget);
    expect(find.text('1 confirmed · 1 incoming'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'preview drafts remain per date and cannot report a successful save',
    (tester) async {
      await openCalendar(tester);
      await showSelectedDay(tester);
      final toggle = find.byKey(const Key('availability-toggle'));
      expect(tester.widget<Switch>(toggle).value, isTrue);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(toggle).value, isFalse);
      expect(find.text('Unsaved preview changes'), findsOneWidget);
      final save = find.widgetWithText(
        FilledButton,
        'Save Availability Settings',
      );
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.ensureVisible(find.text('Reset'));
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(toggle);
      expect(tester.widget<Switch>(toggle).value, isTrue);
      expect(find.text('Unsaved preview changes'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fully booked dates and past dates cannot be toggled', (
    tester,
  ) async {
    await openCalendar(tester, date: DateTime(2028, 1, 22));
    await showSelectedDay(tester);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(find.text('2 confirmed · 0 incoming'), findsOneWidget);
    await openCalendar(tester, date: DateTime(2020, 1, 15));
    await showSelectedDay(tester);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(find.text('Past dates are read-only.'), findsOneWidget);
  });

  testWidgets('loading, error retry and empty services are handled', (
    tester,
  ) async {
    final repository = _Repository()
      ..pending = Completer<ProviderCalendarMonth>();
    await openCalendar(tester, repository: repository);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repository.pending!.completeError(StateError('Offline'));
    repository.pending = null;
    await tester.pumpAndSettle();
    expect(
      find.text('Could not load your calendar. Please try again.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    await tester.scrollUntilVisible(
      find.text('No registered machinery services.'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('No registered machinery services.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('requests tab returns to the selected calendar date', (
    tester,
  ) async {
    await openCalendar(tester);
    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    expect(find.text('Incoming Requests'), findsOneWidget);
    await tester.tap(find.text('Thursday, January 6, 2028'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close inquiry'));
    await tester.pumpAndSettle();
    await showSelectedDay(tester);
    expect(find.text('Thursday, January 6, 2028'), findsOneWidget);
    expect(find.text('0 confirmed · 2 incoming'), findsOneWidget);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsNWidgets(2));
    expect(find.text('SERVICE PROVIDER'), findsOneWidget);
    expect(find.text('Edit profile'), findsOneWidget);
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Machinery Overview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('provider tabs use the owner machinery width on a wide screen', (
    tester,
  ) async {
    await openCalendar(tester, width: 1000);
    await tester.pumpAndSettle();
    for (final tab in ['Dashboard', 'Calendar', 'Requests', 'Profile']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      final navigation = tester.getRect(find.byType(NavigationBar));
      expect(navigation.width, 390);
      expect(navigation.center.dx, 500);
      expect(tester.takeException(), isNull);
    }
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('mobile layout fits at $width px with larger text', (
      tester,
    ) async {
      await openCalendar(tester, width: width, scale: 1.3);
      expect(tester.takeException(), isNull);
      await showSelectedDay(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('calendar preview renders at 360 by 800', (tester) async {
    if (Platform.environment['PROVIDER_SCREENSHOT'] == '1') {
      await tester.runAsync(() async {
        // Widget tests use Ahem by default. Load real fonts for the optional
        // local visual artifact without adding app dependencies or font assets.
        final systemRoot = Platform.environment['SystemRoot'];
        if (systemRoot != null) {
          final arial = File('$systemRoot/Fonts/arial.ttf');
          if (arial.existsSync()) {
            final font = FontLoader('Arial')
              ..addFont(arial.readAsBytes().then(ByteData.sublistView));
            await font.load();
          }
        }
        final config = File('.dart_tool/package_config.json');
        final packages =
            (jsonDecode(await config.readAsString()) as Map)['packages']
                as List;
        final flutter = packages.cast<Map>().firstWhere(
          (p) => p['name'] == 'flutter',
        );
        final flutterRoot = Directory.fromUri(
          config.absolute.uri.resolve(flutter['rootUri'] as String),
        ).uri;
        final icons = File.fromUri(
          flutterRoot.resolve(
            '../../bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ),
        );
        if (icons.existsSync()) {
          final font = FontLoader('MaterialIcons')
            ..addFont(icons.readAsBytes().then(ByteData.sublistView));
          await font.load();
        }
      });
    }
    await openCalendar(tester);
    await tester.pumpAndSettle();
    if (Platform.environment['PROVIDER_SCREENSHOT'] == '1') {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('preview-capture')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/provider_calendar_preview.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    expect(tester.takeException(), isNull);
  });
}
