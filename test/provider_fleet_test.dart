import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kapconnect_mobile/screens/provider/provider_calendar_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapconnect_mobile/models/provider_calendar.dart';
import 'package:kapconnect_mobile/services/machinery_api.dart';
import 'package:kapconnect_mobile/services/provider_calendar_repository.dart';

class _FleetApi extends MachineryApi {
  final calls = <int>[];
  bool tractorOnly = false;
  Completer<List<Map<String, dynamic>>>? pendingInventory;
  @override
  Future<List<Map<String, dynamic>>> machines({bool owner = false}) async {
    final pending = pendingInventory;
    pendingInventory = null;
    if (pending != null) return pending.future;
    return [
      {'id': 1, 'name': 'Tractor A', 'category': 'Tractor'},
      if (!tractorOnly) {'id': 2, 'name': 'Backhoe A', 'category': 'Backhoe'},
      if (!tractorOnly)
        {'id': 3, 'name': 'Tiller A', 'category': 'Hand Tractor'},
    ];
  }

  final savedRates = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> catalog() async => {
    'Tractor': {
      'Slasher': ['acre'],
      'Disc Ploughing': ['acre'],
      'Rotary': ['acre'],
      'Koku Nagula': ['acre'],
      'Trailer': ['day'],
    },
    'Backhoe': {
      'Small Backhoe': ['hour'],
      'Large Backhoe': ['hour'],
    },
    'Hand Tractor': {
      'Hand Tractor': ['day'],
    },
  };
  @override
  Future<void> saveRate(
    int machineId,
    String name,
    String unit,
    double rate,
  ) async {
    savedRates.add({'id': machineId, 'name': name, 'unit': unit, 'rate': rate});
  }

  @override
  Future<ProviderCalendarMonth> calendar(int machineId, DateTime month) async {
    calls.add(machineId);
    return ProviderCalendarMonth(
      days: {
        '2028-01-0$machineId': const ProviderCalendarDay(
          state: ProviderDayState.unavailable,
        ),
      },
    );
  }
}

void main() {
  for (final entry in [
    (1, 'Trailer', 'day'),
    (2, 'Large Backhoe', 'hour'),
    (3, 'Hand Tractor', 'day'),
  ]) {
    testWidgets('rate dialog saves ${entry.$2} per ${entry.$3}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _FleetApi();
      final repository = LiveProviderCalendarRepository(api: api)
        ..selectedMachineId = entry.$1;
      await tester.pumpWidget(
        MaterialApp(
          home: ProviderCalendarPage(
            repository: repository,
            initialDate: DateTime(2028, 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byTooltip('Add service rate'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byTooltip('Add service rate'));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      final dropdown = find.descendant(
        of: dialog,
        matching: find.byType(DropdownButtonFormField<String>),
      );
      if (entry.$1 == 3) {
        expect(dropdown, findsNothing);
      } else {
        expect(dropdown, findsOneWidget);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry.$2).last);
        await tester.pumpAndSettle();
      }
      expect(find.text('Price per ${entry.$3}'), findsOneWidget);
      await tester.enterText(
        find.descendant(of: dialog, matching: find.byType(TextFormField)),
        '2500',
      );
      await tester.tap(find.text('Save Rate'));
      await tester.pumpAndSettle();
      expect(api.savedRates.single, {
        'id': entry.$1,
        'name': entry.$2,
        'unit': entry.$3,
        'rate': 2500.0,
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('owned types appear as horizontal buttons and switch calendars', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _FleetApi()..tractorOnly = true;
    final repository = LiveProviderCalendarRepository(api: api);
    await tester.pumpWidget(
      MaterialApp(
        home: ProviderCalendarPage(
          repository: repository,
          initialDate: DateTime(2028, 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add Machinery'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsOneWidget);
    expect(find.text('Backhoe'), findsNothing);
    api.tractorOnly = false;
    await tester.tap(find.text('Add Machinery'));
    await tester.pumpAndSettle();
    // A registered type is not offered again in the add dialog.
    expect(find.text('Backhoe'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    // Refresh through a month change to fetch the expanded inventory.
    await tester.tap(find.byIcon(Icons.chevron_right).first);
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    await tester.tap(find.byKey(const ValueKey('machine-type-2')));
    await tester.pumpAndSettle();
    expect(repository.selectedMachineId, 2);
    expect(api.calls.last, 2);
    expect(
      find.text('Calendar, availability and rates for Backhoe A'),
      findsOneWidget,
    );
    expect(find.text('Add Machinery'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'one provider can switch between independent calendars for all types',
    () async {
      final api = _FleetApi();
      final repository = LiveProviderCalendarRepository(api: api);
      for (final id in [1, 2, 3, 1]) {
        repository.selectedMachineId = id;
        final month = await repository.loadMonth(DateTime(2028, 1));
        expect(month.days.keys, ['2028-01-0$id']);
        expect(repository.selectedMachineId, id);
      }
      expect(api.calls, [1, 2, 3, 1]);
    },
  );

  test(
    'an old inventory response cannot undo a newer machine selection',
    () async {
      final api = _FleetApi();
      final repository = LiveProviderCalendarRepository(api: api);
      await repository.loadMonth(DateTime(2028, 1));
      final pending = Completer<List<Map<String, dynamic>>>();
      api.pendingInventory = pending;
      final old = repository.loadMonth(DateTime(2028, 1));
      repository.selectedMachineId = 3;
      await repository.loadMonth(DateTime(2028, 1));
      pending.complete([
        {'id': 1, 'name': 'Old tractor', 'category': 'Tractor'},
      ]);
      await old;
      expect(repository.selectedMachineId, 3);
      expect(repository.machines.length, 3);
    },
  );
}
