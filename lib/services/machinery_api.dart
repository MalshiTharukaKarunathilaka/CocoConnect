import '../models/provider_booking_request.dart';
import '../models/provider_calendar.dart';
import 'api_client.dart';

class MachineryApi {
  const MachineryApi();
  static const base = '/api/machinery';
  Future<List<Map<String, dynamic>>> machines({bool owner = false}) async =>
      (await ApiClient.get('$base/${owner ? 'machines' : 'provider/machines'}')
              as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Future<Map<String, dynamic>> catalog() async =>
      Map<String, dynamic>.from(await ApiClient.get('$base/catalog') as Map);
  Future<void> createMachine(String name, String category) async {
    await ApiClient.post('$base/provider/machines', {
      'name': name,
      'category': category,
    });
  }

  Future<void> saveRate(
    int machineId,
    String name,
    String unit,
    double rate,
  ) async {
    await ApiClient.put('$base/provider/machines/$machineId/rates', {
      'name': name,
      'unit': unit,
      'rate': rate,
    });
  }

  Future<void> availability(
    int machineId,
    String day,
    String state, {
    String note = '',
  }) async {
    await ApiClient.put('$base/provider/machines/$machineId/availability', {
      'day': day,
      'state': state,
      'note': note,
    });
  }

  Future<ProviderCalendarMonth> calendar(int machineId, DateTime month) async {
    final key = providerDateKey(month).substring(0, 7);
    final json =
        await ApiClient.get(
              '$base/provider/machines/$machineId/calendar',
              query: {'month': key},
            )
            as Map;
    return ProviderCalendarMonth(
      days: {
        for (final row in json['days'] as List)
          '${row['day']}': ProviderCalendarDay(
            state: switch (row['state']) {
              'MAINTENANCE' => ProviderDayState.maintenance,
              'UNAVAILABLE' => ProviderDayState.unavailable,
              _ => ProviderDayState.available,
            },
          ),
      },
      rates: (json['services'] as List)
          .map(
            (r) => ProviderServiceRate(
              '${r['name']}',
              double.parse('${r['rate']}'),
              '${r['unit']}',
              id: r['id'] as int,
            ),
          )
          .toList(),
      requests: (json['bookings'] as List)
          .map(
            (r) => ProviderBookingRequest.fromJson(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList(),
    );
  }

  Future<Map<String, dynamic>> ownerCalendar(
    int machineId,
    DateTime month,
  ) async => Map<String, dynamic>.from(
    await ApiClient.get(
          '$base/machines/$machineId/calendar',
          query: {'month': providerDateKey(month).substring(0, 7)},
        )
        as Map,
  );
  Future<ProviderBookingRequest> request(String id) async =>
      ProviderBookingRequest.fromJson(
        Map<String, dynamic>.from(
          await ApiClient.get('$base/bookings/$id') as Map,
        ),
      );
  Future<List<ProviderBookingRequest>> bookings() async =>
      (await ApiClient.get('$base/bookings') as List)
          .map(
            (e) => ProviderBookingRequest.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();
  Future<ProviderBookingRequest> respond(
    ProviderBookingRequest request,
    String action, {
    String? message,
    double? rate,
  }) async => ProviderBookingRequest.fromJson(
    Map<String, dynamic>.from(
      await ApiClient.post('$base/bookings/${request.id}/$action', {
            'expected_version': request.version,
            'message': ?message,
            if (rate != null)
              'offer_total': double.parse(
                (rate * request.quantity).toStringAsFixed(2),
              ),
          })
          as Map,
    ),
  );
  Future<ProviderBookingRequest> createBooking(
    int machineId,
    Map<String, dynamic> body,
  ) async => ProviderBookingRequest.fromJson(
    Map<String, dynamic>.from(
      await ApiClient.post('$base/machines/$machineId/bookings', body) as Map,
    ),
  );
}
