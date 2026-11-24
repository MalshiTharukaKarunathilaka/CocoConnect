import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kapconnect_mobile/screens/estate_jobs_map_page.dart';
import 'package:kapconnect_mobile/screens/worker_dashboard.dart';
import 'package:kapconnect_mobile/services/auth_service.dart';
import 'package:kapconnect_mobile/services/worker_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('jobs preview shows job estates directly on a taller map', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = AppUser(
      id: 1,
      name: 'Worker',
      phone: '0771234567',
      role: 'WORKER',
      location: 'Kandy',
    );
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => AuthService.currentUser = null);

    final jobRows = [
      {
        'id': 1,
        'estate_owner_id': 77,
        'estate_name': 'Preview Estate One',
        'estate_owner_name': 'Owner One',
        'estate_location': 'Jaffna',
        'estate_latitude': 9.6615,
        'estate_longitude': 80.0255,
        'category': 'Nut Gatherer',
        'workers_needed': 2,
        'confirmed_workers': 0,
        'required_date': '2030-01-01',
        'location': 'Jaffna',
        'daily_rate': 2500,
        'payment_method': 'Cash',
        'status': 'OPEN',
      },
      {
        'id': 2,
        'estate_owner_id': 77,
        'estate_name': 'Preview Estate One',
        'estate_owner_name': 'Owner One',
        'estate_location': 'Jaffna',
        'estate_latitude': 9.6615,
        'estate_longitude': 80.0255,
        'category': 'Manual Worker',
        'workers_needed': 1,
        'confirmed_workers': 0,
        'required_date': '2030-01-02',
        'location': 'Jaffna',
        'daily_rate': 2500,
        'payment_method': 'Cash',
        'status': 'OPEN',
      },
      {
        'id': 3,
        'estate_owner_id': 88,
        'estate_name': 'Preview Estate Two',
        'estate_owner_name': 'Owner Two',
        'estate_location': 'Kurunegala',
        'category': 'Manual Worker',
        'workers_needed': 1,
        'confirmed_workers': 0,
        'required_date': '2030-01-03',
        'location': 'Kurunegala',
        'daily_rate': 3000,
        'payment_method': 'Cash',
        'status': 'OPEN',
      },
    ];
    final client = MockClient((request) async {
      if (request.url.path == '/api/worker/jobs') {
        return http.Response(
          jsonEncode(jobRows),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/worker/profile') {
        return http.Response(
          jsonEncode({
            'id': 1,
            'name': 'Worker',
            'phone': '0771234567',
            'location': 'Kandy',
            'work_categories': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/worker/estates') {
        return http.Response(
          jsonEncode([
            {
              'id': 88,
              'estate_name': 'Preview Estate Two',
              'estate_owner_name': 'Owner Two',
              'location': 'Kurunegala',
              'estate_latitude': 7.4863,
              'estate_longitude': 80.3647,
              'has_map_location': true,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('[]', 200);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: WorkerDashboard()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Jobs'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final preview = find.byKey(const ValueKey('worker-job-map-preview'));
      expect(tester.getSize(preview).height, 230);
      expect(
        find.descendant(of: preview, matching: find.byType(FlutterMap)),
        findsOneWidget,
      );
      final markerLayer = tester.widget<MarkerLayer>(
        find.descendant(of: preview, matching: find.byType(MarkerLayer)),
      );
      expect(markerLayer.markers, hasLength(2));
      expect(
        markerLayer.markers.map((marker) => marker.point),
        contains(const LatLng(7.4863, 80.3647)),
      );
      expect(
        find.descendant(
          of: preview,
          matching: find.text('2 estates with job postings'),
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets('map includes estates with worker-visible job postings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = AppUser(
      id: 1,
      name: 'Worker',
      phone: '0771234567',
      role: 'WORKER',
      location: 'Kandy',
      latitude: 7.29,
      longitude: 80.63,
    );
    addTearDown(() => AuthService.currentUser = null);

    final jobs = [
      WorkerJob.fromJson({
        'id': 1,
        'estate_owner_id': 77,
        'estate_name': 'Jaffna Job Estate',
        'estate_owner_name': 'Owner One',
        'estate_location': 'Jaffna',
        'estate_latitude': 9.6615,
        'estate_longitude': 80.0255,
        'category': 'Nut Gatherer',
        'workers_needed': 2,
        'confirmed_workers': 0,
        'required_date': '2030-01-01',
        'location': 'Jaffna',
        'daily_rate': 2500,
        'payment_method': 'Cash',
        'status': 'OPEN',
      }),
      WorkerJob.fromJson({
        'id': 2,
        'estate_owner_id': 88,
        'estate_name': 'Hambantota Job Estate',
        'estate_owner_name': 'Owner Two',
        'estate_location': 'Hambantota',
        'estate_latitude': 6.1241,
        'estate_longitude': 81.1185,
        'category': 'Manual Worker',
        'workers_needed': 1,
        'confirmed_workers': 0,
        'required_date': '2030-01-02',
        'location': 'Hambantota',
        'daily_rate': 3000,
        'payment_method': 'Cash',
        'status': 'OPEN',
      }),
      WorkerJob.fromJson({
        'id': 3,
        'estate_owner_id': 101,
        'estate_name': 'Kurunegala Job Estate',
        'estate_owner_name': 'Owner Four',
        'estate_location': 'Kurunegala',
        'category': 'Manual Worker',
        'workers_needed': 1,
        'confirmed_workers': 0,
        'required_date': '2030-01-03',
        'location': 'Kurunegala',
        'daily_rate': 2800,
        'payment_method': 'Cash',
        'status': 'OPEN',
      }),
    ];

    final client = MockClient((request) async {
      if (request.url.path == '/api/worker/estates') {
        return http.Response(
          jsonEncode([
            {
              'id': 99,
              'estate_name': 'Estate Without Jobs',
              'estate_owner_name': 'Owner Three',
              'location': 'Colombo',
              'estate_latitude': 6.9271,
              'estate_longitude': 79.8612,
              'has_map_location': true,
            },
            {
              'id': 101,
              'estate_name': 'Kurunegala Job Estate',
              'estate_owner_name': 'Owner Four',
              'location': 'Kurunegala',
              'estate_latitude': 7.4863,
              'estate_longitude': 80.3647,
              'has_map_location': true,
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('[]', 200);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(home: EstateJobsMapPage(jobs: jobs)));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Jaffna Job Estate\nJaffna'), findsOneWidget);
      expect(find.text('Hambantota Job Estate\nHambantota'), findsOneWidget);
      expect(find.text('Kurunegala Job Estate\nKurunegala'), findsOneWidget);
      expect(find.text('Estate Without Jobs\nColombo'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });
}
