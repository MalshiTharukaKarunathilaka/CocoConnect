import 'package:kapconnect_mobile/screens/onboarding_page.dart' as extra0;
import 'package:kapconnect_mobile/screens/machinery_map_page.dart' as extra1;
import 'package:kapconnect_mobile/screens/estate_jobs_map_page.dart' as extra2;
import 'package:kapconnect_mobile/screens/chat/chat_page.dart' as extra3;
import 'package:kapconnect_mobile/screens/sell_request_page.dart' as extra4;
import 'package:kapconnect_mobile/screens/machinery_negotiation_page.dart'
    as extra5;
import 'package:kapconnect_mobile/screens/machinery_booking_status_page.dart'
    as extra6;
import 'package:kapconnect_mobile/screens/subcategory_page.dart' as extra7;
import 'package:kapconnect_mobile/screens/fertilizer/fertilizer_talk_page.dart'
    as extra8;
import 'package:kapconnect_mobile/screens/fertilizer/supplier_calendar_page.dart'
    as extra9;
import 'package:kapconnect_mobile/screens/fertilizer/fertilizer_map_page.dart'
    as extra10;
import 'package:kapconnect_mobile/screens/fertilizer/live_fertilizer_orders_page.dart'
    as extra11;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kapconnect_mobile/services/auth_service.dart';
import 'package:kapconnect_mobile/services/owner_service.dart';
import 'package:kapconnect_mobile/services/worker_service.dart';
import 'package:kapconnect_mobile/services/buyer_service.dart';
import 'package:kapconnect_mobile/services/provider_calendar_repository.dart';
import 'package:kapconnect_mobile/services/location_service.dart';
import 'package:kapconnect_mobile/services/fertilizer_demo_auth.dart';
import 'package:kapconnect_mobile/models/provider_booking_request.dart';
import 'package:kapconnect_mobile/screens/buyer/coconut_type.dart';
import 'package:kapconnect_mobile/screens/fertilizer/fertilizer_data.dart';
import 'package:kapconnect_mobile/screens/login_page.dart' as p0;
import 'package:kapconnect_mobile/screens/signup_page.dart' as p1;
import 'package:kapconnect_mobile/screens/onboarding_page.dart' as p2;
import 'package:kapconnect_mobile/screens/service_provider_registration_page.dart'
    as p3;
import 'package:kapconnect_mobile/screens/estate_owner_dashboard.dart' as p4;
import 'package:kapconnect_mobile/screens/coconuts_page.dart' as p5;
import 'package:kapconnect_mobile/screens/raw_coconuts_page.dart' as p6;
import 'package:kapconnect_mobile/screens/dehusked_coconuts_page.dart' as p7;
import 'package:kapconnect_mobile/screens/coconut_husks_page.dart' as p8;
import 'package:kapconnect_mobile/screens/estate_owner_profile_page.dart' as p9;
import 'package:kapconnect_mobile/screens/estate_owner_calendar_page.dart'
    as p10;
import 'package:kapconnect_mobile/screens/post_day_job_page.dart' as p11;
import 'package:kapconnect_mobile/screens/scheduled_jobs_page.dart' as p12;
import 'package:kapconnect_mobile/screens/job_detail_page.dart' as p13;
import 'package:kapconnect_mobile/screens/accepted_workers_page.dart' as p14;
import 'package:kapconnect_mobile/screens/worker_profile_page.dart' as p15;
import 'package:kapconnect_mobile/screens/worker_dashboard.dart' as p16;
import 'package:kapconnect_mobile/screens/estate_owner_worker_profile_page.dart'
    as p17;
import 'package:kapconnect_mobile/screens/worker_chat_page.dart' as p18;
import 'package:kapconnect_mobile/screens/day_job_chats_list.dart' as p19;
import 'package:kapconnect_mobile/screens/orders/orders_page.dart' as p22;
import 'package:kapconnect_mobile/screens/order_status_page.dart' as p23;
import 'package:kapconnect_mobile/screens/complete_deal_page.dart' as p24;
import 'package:kapconnect_mobile/screens/chat/chats_page.dart' as p25;
import 'package:kapconnect_mobile/screens/chat/notifications_page.dart' as p26;
import 'package:kapconnect_mobile/screens/buyer/buyer_categories_page.dart'
    as p27;
import 'package:kapconnect_mobile/screens/buyer/coconut_types_page.dart' as p28;
import 'package:kapconnect_mobile/screens/buyer/marketplace_page.dart' as p29;
import 'package:kapconnect_mobile/screens/buyer/buyer_profile_page.dart' as p30;
import 'package:kapconnect_mobile/screens/buyer/estate_owner_request_page.dart'
    as p31;
import 'package:kapconnect_mobile/screens/account_profile_page.dart' as p32;
import 'package:kapconnect_mobile/screens/service_schedule_page.dart' as p33;
import 'package:kapconnect_mobile/screens/my_bookings_page.dart' as p34;
import 'package:kapconnect_mobile/screens/provider/provider_calendar_page.dart'
    as p35;
import 'package:kapconnect_mobile/screens/provider/provider_request_page.dart'
    as p36;
import 'package:kapconnect_mobile/screens/location_picker_page.dart' as p37;
import 'package:kapconnect_mobile/screens/fertilizer/fertilizer_hub.dart'
    as p38;
import 'package:kapconnect_mobile/screens/fertilizer/fertilizer_requests_page.dart'
    as p39;
import 'package:kapconnect_mobile/screens/fertilizer/fertilizer_orders_page.dart'
    as p40;
import 'package:kapconnect_mobile/screens/fertilizer/fertilizer_complaints_page.dart'
    as p41;
import 'package:kapconnect_mobile/screens/fertilizer/provider_hub.dart' as p43;
import 'package:kapconnect_mobile/screens/fertilizer/fertilizer_oversight_page.dart'
    as p45;
import 'package:kapconnect_mobile/screens/fertilizer/fertilizer_role_gate.dart'
    as p46;
import 'package:kapconnect_mobile/screens/fertilizer/fertilizer_login_page.dart'
    as p47;
import 'package:kapconnect_mobile/screens/fertilizer/fertilizer_signup_page.dart'
    as p48;
import 'package:kapconnect_mobile/screens/fertilizer/fertilizer_order_sheet.dart'
    as p49;
import 'package:kapconnect_mobile/screens/fertilizer/fertilizer_order_edit_sheet.dart'
    as p50;
import 'package:kapconnect_mobile/screens/fertilizer/fertilizer_complaint_sheet.dart'
    as p51;
import 'package:kapconnect_mobile/screens/fertilizer/fertilizer_gov_order_form.dart'
    as p52;

final machineBooking = extra5.MachineBooking(
  id: '1',
  machineName: 'Tractor',
  provider: 'Provider with a long registered name',
  category: 'Tractor',
  items: [const extra5.BookingItem('Disc Ploughing', 'acre', 8, 6800)],
  agreedTotal: 54400,
  date: DateTime(2030, 1, 1),
  time: '8:00 AM',
  estate: 'Green Valley Coconut Land',
  createdAt: DateTime(2026, 11, 1),
  chat: const [],
);
final job = DayJob(
  id: 1,
  category: 'Coconut harvesting',
  workersNeeded: 3,
  requiredDate: DateTime(2030, 1, 1),
  location: 'Ibbagamuwa, Kurunegala District',
  dailyRate: 3500,
  paymentMethod: 'Cash after completion',
  status: 'OPEN',
  confirmedWorkers: 1,
  acceptedWorkers: [
    const AcceptedWorker(
      id: 1,
      name: 'Worker with a long registered name',
      rating: 4,
    ),
  ],
);
final workerJob = WorkerJob.fromJson({
  'id': 1,
  'category': 'Coconut harvesting',
  'workers_needed': 3,
  'required_date': '2030-01-01',
  'location': 'Ibbagamuwa, Kurunegala District',
  'daily_rate': 3500,
  'estate_name': 'Green Valley Coconut Land',
  'estate_owner_name': 'Land owner with a long registered name',
});
final listing = Listing.fromJson({
  'id': 1,
  'product_type': 'RAW_COCONUT',
  'quantity': 10000,
  'available_date': '2030-01-01',
  'offer_price_per_unit': 130,
  'estate_name': 'Green Valley Coconut Land',
  'owner_name': 'Land owner with a long registered name',
  'location': 'Ibbagamuwa, Kurunegala District',
  'trust_score': 4.5,
});
final booking = ProviderBookingRequest(
  id: '1',
  machineId: '1',
  ownerName: 'Land owner with a long registered name',
  estateName: 'Green Valley Coconut Land',
  address: 'Ibbagamuwa, Kurunegala District',
  machinery: 'Tractor',
  service: 'Disc Ploughing',
  quantity: 8,
  unit: 'acre',
  startsAt: DateTime(2030, 1, 1, 8),
  endsAt: DateTime(2030, 1, 1, 17),
  proposedRate: 6800,
);
final order = {
  'id': 1,
  'my_role': 'ESTATE_OWNER',
  'counterpart_name': 'Buyer with a long registered company name',
  'product_type': 'RAW_COCONUT',
  'quantity': 10000,
  'final_price_per_unit': 130,
  'total_value': 1300000,
  'due_date': '2030-01-01',
  'created_at': '2026-11-01',
  'negotiation_id': 1,
};
final client = MockClient((request) async {
  final path = request.url.path;
  Object result = [];
  if (path == '/api/activity') {
    result = {
      'pending': [
        {
          'id': 1,
          'kind': 'CHAT_OFFER',
          'counterpart_name': 'Buyer with a long registered company name',
          'quantity': 10000,
          'price': 130,
        },
      ],
      'negotiations': [],
      'deals': [
        {...order, 'status': 'ACCEPTED'},
      ],
      'transactions': [
        {
          ...order,
          'status': 'COMPLETED',
          'delivered_quantity': 10000,
          'delivered_price_per_unit': 130,
          'my_rating': 4,
          'counterpart_rating': 5,
        },
      ],
    };
  }
  if (path == '/api/owner/estate') {
    result = {
      'id': 1,
      'name': 'Land owner with a long registered name',
      'estate_name': 'Green Valley Coconut Land',
      'location': 'Ibbagamuwa, Kurunegala District',
      'total_land_area': '50 acres',
      'primary_crop': 'Coconut',
    };
  }
  if (path == '/api/owner/summary') {
    result = {
      'estate': {
        'id': 1,
        'name': 'Owner',
        'estate_name': 'Green Valley Coconut Land',
      },
      'active_listings': 12,
      'open_chats': 8,
      'offers_waiting': 2,
      'orders_active': 8,
      'orders_completed': 3,
      'rating_count': 10,
      'average_rating': 4.5,
      'rating_sources': [
        {
          'label': 'Machinery bookings',
          'rating_count': 3,
          'average_rating': 4.3,
        },
      ],
    };
  }
  if (path == '/api/buyer/summary') {
    result = {
      'requests_pending': 3,
      'orders_active': 8,
      'orders_completed': 12,
      'total_spent': 100000,
    };
  }
  if (path == '/api/owner/buyer-requests') {
    result = [
      {
        'id': 1,
        'buyer_name': 'Buyer with a long registered company name',
        'location': 'Ibbagamuwa, Kurunegala District',
        'product_type': request.url.queryParameters['type'],
        'requested_quantity': 10000,
        'required_date': '2030-01-01',
        'bidding_price_per_unit': 130,
        'trust_score': 4.3,
        'distance_km': 11,
      },
    ];
  }
  if (path == '/api/buyer/listings') {
    result = [
      {
        'id': 1,
        'estate_name': 'Green Valley Coconut Land',
        'owner_name': 'Land owner with a long registered name',
        'product_type': 'RAW_COCONUT',
        'quantity': 10000,
        'available_date': '2030-01-01',
        'offer_price_per_unit': 130,
        'trust_score': 4.3,
        'distance_km': 11,
      },
    ];
  }
  if (path == '/api/worker/profile' ||
      path.contains('/workers/') ||
      path.endsWith('/estate-owner')) {
    result = {
      'id': 1,
      'name': 'Worker with a long registered name',
      'owner_name': 'Land owner with a long registered name',
      'estate_name': 'Green Valley Coconut Land',
      'location': 'Ibbagamuwa, Kurunegala District',
      'phone': '0771234567',
      'average_rating': 4.5,
    };
  }
  if (path == '/api/day-job-chats/1') {
    result = {
      'id': 1,
      'job_id': 1,
      'category': 'Coconut harvesting',
      'counterpart_name': 'Land owner with a long registered name',
      'counterpart_role': 'ESTATE_OWNER',
      'messages': [],
    };
  }
  if (path == '/api/chats/1') {
    result = {
      'id': 1,
      'status': 'OPEN',
      'my_role': 'BUYER',
      'counterpart_name': 'Land owner with a long registered name',
      'listing': {
        'product_type': 'RAW_COCONUT',
        'quantity': 10000,
        'offer_price_per_unit': 130,
        'estate_name': 'Green Valley Coconut Land',
      },
      'messages': [],
    };
  }
  if (path == '/api/owner/market-stats' || path == '/api/holidays') result = {};
  if (path == '/api/health') {
    result = {
      'storage': {'mode': 'postgres', 'persistent': true},
      'provider_registration_ready': true,
      'machinery_workflow_ready': true,
    };
  }
  return http.Response(jsonEncode(result), 200);
});
void main() {
  final cases = <(String, String, Widget Function())>[
    ('00 LoginPage BUYER', 'BUYER', () => p0.LoginPage()),
    ('01 SignupPage ESTATE_OWNER', 'ESTATE_OWNER', () => p1.SignupPage()),
    ('02 WelcomePage BUYER', 'BUYER', () => p2.WelcomePage()),
    (
      '03 ServiceProviderRegistrationPage SERVICE_PROVIDER',
      'SERVICE_PROVIDER',
      () => p3.ServiceProviderRegistrationPage(),
    ),
    (
      '04 EstateOwnerDashboard ESTATE_OWNER',
      'ESTATE_OWNER',
      () => p4.EstateOwnerDashboard(),
    ),
    ('05 CoconutsPage ESTATE_OWNER', 'ESTATE_OWNER', () => p5.CoconutsPage()),
    (
      '06 RawCoconutsPage ESTATE_OWNER',
      'ESTATE_OWNER',
      () => p6.RawCoconutsPage(),
    ),
    (
      '07 DehuskedCoconutsPage ESTATE_OWNER',
      'ESTATE_OWNER',
      () => p7.DehuskedCoconutsPage(),
    ),
    (
      '08 CoconutHusksPage ESTATE_OWNER',
      'ESTATE_OWNER',
      () => p8.CoconutHusksPage(),
    ),
    (
      '09 EstateOwnerProfilePage ESTATE_OWNER',
      'ESTATE_OWNER',
      () => p9.EstateOwnerProfilePage(),
    ),
    (
      '10 EstateOwnerCalendarPage ESTATE_OWNER',
      'ESTATE_OWNER',
      () => p10.EstateOwnerCalendarPage(),
    ),
    (
      '11 PostDayJobPage ESTATE_OWNER',
      'ESTATE_OWNER',
      () => p11.PostDayJobPage(requiredDate: DateTime(2030, 1, 1)),
    ),
    (
      '12 ScheduledJobsPage ESTATE_OWNER',
      'ESTATE_OWNER',
      () => p12.ScheduledJobsPage(date: DateTime(2030, 1, 1)),
    ),
    (
      '13 JobDetailPage ESTATE_OWNER',
      'ESTATE_OWNER',
      () => p13.JobDetailPage(job: job),
    ),
    (
      '14 AcceptedWorkersPage ESTATE_OWNER',
      'ESTATE_OWNER',
      () => p14.AcceptedWorkersPage(job: job),
    ),
    (
      '15 WorkerProfilePage ESTATE_OWNER',
      'ESTATE_OWNER',
      () => p15.WorkerProfilePage(
        workerId: 1,
        fallbackName: 'Worker with a long registered name',
        canRate: true,
      ),
    ),
    ('16 WorkerDashboard WORKER', 'WORKER', () => p16.WorkerDashboard()),
    (
      '17 EstateOwnerWorkerProfilePage WORKER',
      'WORKER',
      () => p17.EstateOwnerWorkerProfilePage(job: workerJob),
    ),
    ('18 WorkerChatPage WORKER', 'WORKER', () => p18.WorkerChatPage(chatId: 1)),
    (
      '19 DayJobChatsList WORKER',
      'WORKER',
      () => p19.DayJobChatsList(showTitle: true),
    ),
    (
      '20 OrdersPage ESTATE_OWNER',
      'ESTATE_OWNER',
      () => p22.OrdersPage(initialTab: 0),
    ),
    ('21 OrdersPage BUYER', 'BUYER', () => p22.OrdersPage(initialTab: 1)),
    (
      '22 OrdersPage ESTATE_OWNER',
      'ESTATE_OWNER',
      () => p22.OrdersPage(initialTab: 2),
    ),
    (
      '23 OrderStatusPage ESTATE_OWNER',
      'ESTATE_OWNER',
      () => p23.OrderStatusPage(),
    ),
    (
      '24 CompleteDealPage ESTATE_OWNER',
      'ESTATE_OWNER',
      () => p24.CompleteDealPage(orderId: 1),
    ),
    ('25 ChatsPage BUYER', 'BUYER', () => p25.ChatsPage()),
    ('26 NotificationsPage BUYER', 'BUYER', () => p26.NotificationsPage()),
    ('27 BuyerCategoriesPage BUYER', 'BUYER', () => p27.BuyerCategoriesPage()),
    ('28 CoconutTypesPage BUYER', 'BUYER', () => p28.CoconutTypesPage()),
    ('29 MarketplacePage BUYER', 'BUYER', () => p29.MarketplacePage()),
    ('30 BuyerProfilePage BUYER', 'BUYER', () => p30.BuyerProfilePage()),
    (
      '31 EstateOwnerRequestPage BUYER',
      'BUYER',
      () => p31.EstateOwnerRequestPage(type: CoconutType.raw, listing: listing),
    ),
    (
      '32 AccountProfilePage SERVICE_PROVIDER',
      'SERVICE_PROVIDER',
      () => p32.AccountProfilePage(),
    ),
    (
      '33 ServiceSchedulePage ESTATE_OWNER',
      'ESTATE_OWNER',
      () => p33.ServiceSchedulePage(),
    ),
    (
      '34 MyBookingsPage ESTATE_OWNER',
      'ESTATE_OWNER',
      () => p34.MyBookingsPage(),
    ),
    (
      '35 ProviderCalendarPage SERVICE_PROVIDER',
      'SERVICE_PROVIDER',
      () => p35.ProviderCalendarPage(
        repository: PreviewProviderCalendarRepository(),
      ),
    ),
    (
      '36 ProviderRequestPage SERVICE_PROVIDER',
      'SERVICE_PROVIDER',
      () => p36.ProviderRequestPage(request: booking, showMap: false),
    ),
    (
      '37 LocationPickerPage ESTATE_OWNER',
      'ESTATE_OWNER',
      () => p37.LocationPickerPage(
        initial: const PickedLocation(
          name: 'Kurunegala',
          latitude: 7.4863,
          longitude: 80.3647,
        ),
      ),
    ),
    (
      '38 FertilizerHub ESTATE_OWNER',
      'ESTATE_OWNER',
      () => p38.FertilizerHub(),
    ),
    (
      '39 FertilizerRequestsPage ESTATE_OWNER',
      'ESTATE_OWNER',
      () => p39.FertilizerRequestsPage(),
    ),
    (
      '40 FertilizerOrdersPage ESTATE_OWNER',
      'ESTATE_OWNER',
      () => p40.FertilizerOrdersPage(),
    ),
    (
      '41 FertilizerComplaintsPage ESTATE_OWNER',
      'ESTATE_OWNER',
      () => p41.FertilizerComplaintsPage(),
    ),
    (
      '42 ProviderHub FERTILIZER_SUPPLIER',
      'FERTILIZER_SUPPLIER',
      () => p43.ProviderHub(mode: FertHomeMode.supplier),
    ),
    (
      '43 ProviderHub CDO',
      'CDO',
      () => p43.ProviderHub(mode: FertHomeMode.cdo),
    ),
    (
      '44 FertilizerOversightPage CHAIRMAN',
      'CHAIRMAN',
      () => p45.FertilizerOversightPage(),
    ),
    (
      '45 FertilizerOversightPage REGIONAL_MANAGER',
      'REGIONAL_MANAGER',
      () => p45.FertilizerOversightPage(),
    ),
    ('46 FertilizerRoleGate BUYER', 'BUYER', () => p46.FertilizerRoleGate()),
    (
      '47 FertilizerLoginPage FERTILIZER_SUPPLIER',
      'FERTILIZER_SUPPLIER',
      () => p47.FertilizerLoginPage(account: FertilizerDemoAuth.accounts[1]),
    ),
    (
      '48 FertilizerSignupPage FERTILIZER_SUPPLIER',
      'FERTILIZER_SUPPLIER',
      () =>
          p48.FertilizerSignupPage(lockedRole: FertilizerDemoAuth.accounts[1]),
    ),
    (
      '49 FertilizerOrderSheet ESTATE_OWNER',
      'ESTATE_OWNER',
      () => p49.FertilizerOrderSheet(
        place: FertilizerStore.instance.places.first,
      ),
    ),
    (
      '50 FertilizerOrderEditSheet ESTATE_OWNER',
      'ESTATE_OWNER',
      () => p50.FertilizerOrderEditSheet(
        order: FertilizerStore.instance.orders.first,
      ),
    ),
    (
      '51 FertilizerComplaintSheet ESTATE_OWNER',
      'ESTATE_OWNER',
      () => p51.FertilizerComplaintSheet(),
    ),
    (
      '52 FertilizerGovOrderForm ESTATE_OWNER',
      'ESTATE_OWNER',
      () => p52.FertilizerGovOrderForm(
        place: FertilizerStore.instance.places.firstWhere((p) => p.isGov),
        draft: GovOrderDraft(
          lines: [],
          date: DateTime(2030, 1, 1),
          slot: 'Morning',
        ),
      ),
    ),
    ('53 Onboarding', 'BUYER', () => const extra0.OnboardingPage()),
    ('54 Machinery map', 'ESTATE_OWNER', () => const extra1.MachineryMapPage()),
    (
      '55 Worker land map',
      'WORKER',
      () => const extra2.EstateJobsMapPage(jobs: []),
    ),
    ('56 Coconut chat', 'BUYER', () => const extra3.ChatPage(chatId: 1)),
    (
      '57 Sell request',
      'ESTATE_OWNER',
      () => extra4.SellRequestPage(
        buyerId: 1,
        buyerName: 'Buyer with a long registered company name',
        location: 'Ibbagamuwa, Kurunegala District',
        requestedQuantity: 10000,
        requiredDate: '2030-01-01',
        productType: 'RAW_COCONUT',
        buyerBiddingPrice: 130,
        sellerOfferPricePerUnit: 125,
      ),
    ),
    (
      '58 Machinery negotiation',
      'ESTATE_OWNER',
      () => extra5.MachineryNegotiationPage(
        machineName: 'Tractor',
        provider: 'Provider with a long registered name',
        category: 'Tractor',
        items: machineBooking.items,
        date: DateTime(2030, 1, 1),
        startTime: '8:00 AM',
        estate: 'Green Valley Coconut Land',
      ),
    ),
    (
      '59 Booking confirmed',
      'ESTATE_OWNER',
      () => extra5.BookingConfirmedPage(booking: machineBooking),
    ),
    (
      '60 Booking status',
      'ESTATE_OWNER',
      () => extra6.MachineryBookingStatusPage(booking: machineBooking),
    ),
    (
      '61 Machinery chat',
      'ESTATE_OWNER',
      () => extra6.MachineryChatPage(booking: machineBooking),
    ),
    (
      '62 Subcategories',
      'BUYER',
      () => const extra7.SubcategoryPage(category: 'Spices', icon: Icons.eco),
    ),
    (
      '63 Fertilizer talk',
      'ESTATE_OWNER',
      () => extra8.FertilizerTalkPage(
        place: FertilizerStore.instance.places.first,
      ),
    ),
    (
      '64 Supplier calendar',
      'FERTILIZER_SUPPLIER',
      () => const extra9.SupplierCalendarPage(),
    ),
    (
      '65 Fertilizer map',
      'ESTATE_OWNER',
      () => const extra10.FertilizerMapPage(),
    ),
    (
      '66 Fertilizer delivered orders',
      'FERTILIZER_SUPPLIER',
      () => const extra11.LiveFertilizerOrdersPage(),
    ),
  ];
  for (final width in const [320.0, 360.0, 412.0]) {
    for (final item in cases) {
      for (final keyboard in const [0.0, 260.0]) {
        if (keyboard > 0 &&
            ![
              '00',
              '01',
              '11',
              '18',
              '36',
              '56',
              '57',
              '58',
              '61',
              '63',
            ].contains(item.$1.split(' ').first)) {
          continue;
        }
        testWidgets('${item.$1} at $width, keyboard $keyboard', (tester) async {
          SharedPreferences.setMockInitialValues({});
          AuthService.currentUser = AppUser(
            id: 1,
            name: 'Person with a long registered name',
            phone: '0771234567',
            role: item.$2,
            location: 'Ibbagamuwa, Kurunegala District',
            latitude: 7.4863,
            longitude: 80.3647,
          );
          tester.view.physicalSize = Size(width, 640);
          tester.view.devicePixelRatio = 1;
          tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
          addTearDown(tester.view.resetViewInsets);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final errors = <String>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (details) {
            final message = details.toString();
            if (RegExp(
              r'overflowed|RenderFlex|RenderBox was not laid|BoxConstraints|infinite size|hasSize|Vertical viewport|Incorrect use of ParentDataWidget',
            ).hasMatch(message)) {
              errors.add(message);
            }
          };
          try {
            await http.runWithClient(() async {
              await tester.pumpWidget(
                MaterialApp(
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: Size(width, 640),
                      padding: const EdgeInsets.only(top: 24, bottom: 24),
                      viewInsets: EdgeInsets.only(bottom: keyboard),
                      textScaler: const TextScaler.linear(1.3),
                    ),
                    child: item.$3(),
                  ),
                ),
              );
              await tester.pump(const Duration(milliseconds: 300));
              await tester.pump(const Duration(milliseconds: 300));
              // Exercise lower cards as well as the first viewport.
              final scrollables = find.byType(Scrollable).hitTestable();
              if (scrollables.evaluate().isNotEmpty) {
                await tester.drag(scrollables.first, const Offset(0, -450));
                await tester.pump(const Duration(milliseconds: 400));
              }
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump(const Duration(milliseconds: 100));
            }, () => client);
          } finally {
            FlutterError.onError = previous;
            AuthService.currentUser = null;
          }
          expect(errors, isEmpty, reason: errors.join('\n'));
        });
      }
    }
  }
}
