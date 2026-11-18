import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kapconnect_mobile/services/auth_service.dart';
import 'package:kapconnect_mobile/services/owner_service.dart';
import 'package:kapconnect_mobile/services/activity_service.dart';
import 'package:kapconnect_mobile/widgets/buyer_filter_sheet.dart';
import 'package:kapconnect_mobile/widgets/order_rating_dialog.dart';
import 'package:kapconnect_mobile/widgets/land_owner_rating_dialog.dart';
import 'package:kapconnect_mobile/screens/account_dialogs.dart';
import 'package:kapconnect_mobile/screens/live_machinery_booking.dart';
import 'package:kapconnect_mobile/screens/provider/revise_request_dialog.dart';
import 'package:kapconnect_mobile/theme/app_theme.dart';
import 'package:kapconnect_mobile/screens/fertilizer/fertilizer_data.dart';
import 'package:kapconnect_mobile/screens/fertilizer/fertilizer_order_sheet.dart';
import 'package:kapconnect_mobile/screens/fertilizer/fertilizer_order_edit_sheet.dart';
import 'package:kapconnect_mobile/screens/fertilizer/fertilizer_complaint_sheet.dart';
import 'package:kapconnect_mobile/screens/fertilizer/fertilizer_gov_order_form.dart';
import 'mobile_layout_audit_test.dart' as fixtures;

void main() {
  final user = AppUser(
    id: 1,
    name: 'Land owner with a long registered name',
    phone: '0771234567',
    role: 'ESTATE_OWNER',
    location: 'Ibbagamuwa, Kurunegala District',
  );
  final land = Estate(
    id: 1,
    estateName: 'Green Valley Coconut Land',
    ownerName: user.name,
    location: user.location,
    totalLandArea: '50 acres',
    primaryCrop: 'Coconut',
  );
  final cases = <(String, void Function(BuildContext))>[
    (
      'edit profile',
      (context) {
        showDialog<void>(
          context: context,
          builder: (_) => EditProfileDialog(user: user),
        );
      },
    ),
    (
      'edit land',
      (context) {
        showDialog<void>(
          context: context,
          builder: (_) => EditEstateDialog(estate: land),
        );
      },
    ),
    (
      'request machinery',
      (context) {
        requestLiveMachinery(
          context,
          machineId: 1,
          date: DateTime(2030, 1, 1),
          items: const [],
        );
      },
    ),
    (
      'revise machinery',
      (context) {
        showReviseRequestDialog(context, fixtures.booking);
      },
    ),
    (
      'send machinery booking request',
      (context) {
        showReviseRequestDialog(context, fixtures.booking, initialRequest: true);
      },
    ),
    (
      'rate land owner',
      (context) {
        showLandOwnerRatingDialog(context);
      },
    ),
    (
      'rate buyer',
      (context) {
        showOrderRating(
          context,
          OrderItem.fromJson({...fixtures.order, 'status': 'COMPLETED'}),
        );
      },
    ),
    (
      'filter buyers',
      (context) {
        showBuyerFilterSheet(context, (
          sort: 'price',
          radiusKm: 20,
          matchHarvest: false,
        ));
      },
    ),
    (
      'fertilizer order',
      (context) {
        showThemedBottomSheet<void>(
          context: context,
          builder: (_) => FertilizerOrderSheet(
            place: FertilizerStore.instance.places.first,
          ),
        );
      },
    ),
    (
      'edit fertilizer order',
      (context) {
        showThemedBottomSheet<void>(
          context: context,
          builder: (_) => FertilizerOrderEditSheet(
            order: FertilizerStore.instance.orders.first,
          ),
        );
      },
    ),
    (
      'fertilizer complaint',
      (context) {
        showThemedBottomSheet<void>(
          context: context,
          builder: (_) => const FertilizerComplaintSheet(),
        );
      },
    ),
    (
      'government application',
      (context) {
        showThemedBottomSheet<void>(
          context: context,
          builder: (_) => FertilizerGovOrderForm(
            place: FertilizerStore.instance.places.firstWhere((p) => p.isGov),
            draft: GovOrderDraft(
              lines: [],
              date: DateTime(2030, 1, 1),
              slot: 'Morning',
            ),
          ),
        );
      },
    ),
  ];
  for (final viewport in const [
    (320.0, 640.0, 260.0),
    (360.0, 740.0, 0.0),
    (412.0, 892.0, 300.0),
  ]) {
    for (final item in cases) {
      testWidgets('${item.$1} at ${viewport.$1}, keyboard ${viewport.$3}', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        AuthService.currentUser = user;
        tester.view.physicalSize = Size(viewport.$1, viewport.$2);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = FakeViewPadding(bottom: viewport.$3);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final errors = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          final message = details.toString();
          if (RegExp(
            r'overflowed|RenderFlex|RenderBox was not laid|BoxConstraints|infinite size|hasSize|Vertical viewport|Incorrect use of ParentDataWidget|intrinsic dimensions',
          ).hasMatch(message)) {
            errors.add(message);
          }
        };
        try {
          await http.runWithClient(() async {
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => item.$2(context),
                      child: const Text('Open popup'),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('Open popup'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
            final scrolls = find.byType(Scrollable).hitTestable();
            if (scrolls.evaluate().isNotEmpty) {
              await tester.drag(scrolls.last, const Offset(0, -250));
              await tester.pump(const Duration(milliseconds: 400));
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
          }, () => fixtures.client);
        } finally {
          FlutterError.onError = previous;
          AuthService.currentUser = null;
        }
        expect(errors, isEmpty, reason: errors.join('\n'));
      });
    }
  }
}
