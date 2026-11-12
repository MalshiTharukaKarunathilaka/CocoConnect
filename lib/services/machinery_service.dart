import 'package:latlong2/latlong.dart';

import '../screens/machinery_negotiation_page.dart';
import '../widgets/machinery_widgets.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// Where the logged-in owner's estate is (Kurunegala when no location is saved).
LatLng ownerLocation() {
  final AppUser? me = AuthService.currentUser;
  return LatLng(me?.latitude ?? 7.4863, me?.longitude ?? 80.3647);
}

/// "2026-11-20", the way the backend wants dates.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _parseDate(dynamic value) {
  final DateTime? d = DateTime.tryParse('$value');
  return d == null ? DateTime.now() : DateTime(d.year, d.month, d.day);
}

/// A day on a machine's calendar that somebody has already booked.
/// A day the provider has blocked (maintenance or unavailable).
class BlockedDay {
  final DateTime date;
  final String state;

  const BlockedDay({required this.date, required this.state});
}

/// What is already on a machine's calendar.
class MachineCalendar {
  final List<MachineSlot> slots;
  final List<BlockedDay> blocked;

  const MachineCalendar({required this.slots, required this.blocked});
}

class MachineSlot {
  final DateTime date;
  final String time;
  final List<BookingItem> items;

  /// True for the logged-in owner's own booking. The calendar already shows
  /// those from [machineBookings], so only other people's are drawn from here.
  final bool mine;

  const MachineSlot({
    required this.date,
    required this.time,
    required this.items,
    required this.mine,
  });
}

BookingItem _itemFromJson(Map<String, dynamic> json) => BookingItem(
  json['name'] as String? ?? '',
  json['unit'] as String? ?? 'acre',
  (json['qty'] as num?)?.toDouble() ?? 1,
  (json['rate'] as num?)?.toInt() ?? 0,
  serviceId: (json['service_id'] as num?)?.toInt(),
);

/// Machines and machinery bookings, from `/api/machinery`.
class MachineryService {
  MachineryService._();

  /// Active machines, nearest to the owner first.
  static Future<List<MachineInfo>> machines() async {
    final LatLng at = ownerLocation();
    final dynamic data = await ApiClient.get(
      '/api/machinery/machines',
      query: {'lat': '${at.latitude}', 'lng': '${at.longitude}'},
    );
    return [
      for (final m in (data as List? ?? const []))
        MachineInfo.fromJson(m as Map<String, dynamic>),
    ];
  }

  /// One booking from the backend's JSON.
  static MachineBooking bookingFromJson(Map<String, dynamic> json) {
    final MachineInfo? info = json['machine'] is Map<String, dynamic>
        ? MachineInfo.fromJson(json['machine'] as Map<String, dynamic>)
        : null;
    return MachineBooking(
      serverId: (json['id'] as num).toInt(),
      id: json['code'] as String? ?? '#MC-${json['id']}',
      machineName: info?.name ?? '',
      provider: info?.provider ?? '',
      category: machineLabel(info?.type ?? 'TRACTOR'),
      items: [
        for (final i in (json['items'] as List? ?? const []))
          _itemFromJson(i as Map<String, dynamic>),
      ],
      agreedTotal: (json['agreed_total'] as num?)?.toInt() ?? 0,
      date: _parseDate(json['date']),
      time: json['time'] as String? ?? '',
      estate: json['estate'] as String? ?? '',
      createdAt:
          DateTime.tryParse('${json['created_at']}')?.toLocal() ??
          DateTime.now(),
      chat: [
        for (final c in (json['chat'] as List? ?? const []))
          ChatLine(
            (c as Map<String, dynamic>)['mine'] == true,
            c['text'] as String? ?? '',
            at: DateTime.tryParse('${c['at']}')?.toLocal(),
          ),
      ],
      machineAt: info == null ? null : LatLng(info.lat, info.lng),
      estateAt: ownerLocation(),
      km: (json['km'] as num?)?.toDouble() ?? 0,
      info: info,
    );
  }

  /// Reloads the owner's bookings into [machineBookings], which the calendar,
  /// My Bookings and the status page read.
  static Future<void> refreshBookings() async {
    final dynamic data = await ApiClient.get('/api/machinery/bookings');
    final Map<String, List<MachineBooking>> next = {};
    for (final j in (data as List? ?? const [])) {
      final MachineBooking b = bookingFromJson(j as Map<String, dynamic>);
      next.putIfAbsent(b.machineName, () => []).add(b);
    }
    machineBookings
      ..clear()
      ..addAll(next);
  }

  /// Saves a booking once the price is agreed. Throws [ApiException] with a
  /// readable message when the day was taken or something is wrong.
  static Future<MachineBooking> createBooking({
    required MachineInfo machine,
    required List<BookingItem> items,
    required int agreedTotal,
    required DateTime date,
    required String time,
    required String estate,
    required List<ChatLine> chat,
  }) async {
    if (items.any((i) => i.serviceId == null)) {
      throw const ApiException('Pick the services again');
    }
    final dynamic data = await ApiClient.post('/api/machinery/bookings', {
      'machineId': machine.id,
      // Only the service and the amount of work go up; the backend prices it.
      'items': [
        for (final i in items) {'serviceId': i.serviceId, 'qty': i.qty},
      ],
      'agreedTotal': agreedTotal,
      'date': isoDate(date),
      'time': time,
      'estate': estate,
      'latitude': ownerLocation().latitude,
      'longitude': ownerLocation().longitude,
      'chat': [
        for (final c in chat)
          {'mine': c.mine, 'text': c.text, 'at': c.at.toUtc().toIso8601String()},
      ],
    });
    final MachineBooking booking = bookingFromJson(data as Map<String, dynamic>);
    machineBookings.putIfAbsent(booking.machineName, () => []).add(booking);
    return booking;
  }

  static Future<void> cancelBooking(MachineBooking booking) async {
    final int? id = booking.serverId;
    if (id == null) {
      throw const ApiException('This booking cannot be cancelled here');
    }
    await ApiClient.patch('/api/machinery/bookings/$id/cancel');
    machineBookings[booking.machineName]?.removeWhere(
      (b) => b.serverId == id,
    );
  }

  /// The bookings already on a machine's calendar, and the days blocked.
  static Future<MachineCalendar> schedule(int machineId) async {
    final dynamic data = await ApiClient.get(
      '/api/machinery/machines/$machineId/schedule',
    );
    final Map<String, dynamic> map = data as Map<String, dynamic>;
    return MachineCalendar(
      slots: [
        for (final j in (map['bookings'] as List? ?? const []))
          MachineSlot(
            date: _parseDate((j as Map<String, dynamic>)['date']),
            time: j['time'] as String? ?? '',
            items: [
              for (final i in (j['items'] as List? ?? const []))
                _itemFromJson(i as Map<String, dynamic>),
            ],
            mine: j['mine'] == true,
          ),
      ],
      blocked: [
        for (final d in (map['blocked'] as List? ?? const []))
          BlockedDay(
            date: _parseDate((d as Map<String, dynamic>)['date']),
            state: d['state'] as String? ?? 'UNAVAILABLE',
          ),
      ],
    );
  }
}
