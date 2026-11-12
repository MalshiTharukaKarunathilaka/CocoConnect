import 'package:flutter_test/flutter_test.dart';
import 'package:kapconnect_mobile/screens/machinery_negotiation_page.dart';
import 'package:kapconnect_mobile/services/machinery_service.dart';
import 'package:kapconnect_mobile/widgets/machinery_widgets.dart';

// What the backend sends for a machine and for a booking (see
// backend/controllers/machineryController.js).
const Map<String, dynamic> _machine = {
  'id': 7,
  'name': 'JCB 3CX',
  'provider': 'Kithsiri Earthmovers',
  'type': 'BACKHOE',
  'services': 'Ditch & drainage · Pit digging',
  'rate': 4200,
  'unit': 'hour',
  'latitude': 7.492,
  'longitude': 80.321,
  'rating': 4.8,
  'jobs': 88,
  'photo': 0,
  'distance_km': 3.2,
  'radius_km': 25,
  'service_list': [
    {'id': 31, 'name': 'Ditch & Drainage', 'unit': 'hour', 'rate': 4200},
    {'id': 32, 'name': 'Pit Digging', 'unit': 'hour', 'rate': 4200},
  ],
};

void main() {
  test('a machine from the backend becomes a MachineInfo', () {
    final MachineInfo m = MachineInfo.fromJson(_machine);
    expect(m.id, 7);
    expect(m.name, 'JCB 3CX');
    expect(m.type, 'BACKHOE');
    expect(m.rate, 4200);
    expect(m.unit, 'hour');
    expect(m.lat, 7.492);
    expect(m.lng, 80.321);
    expect(m.ratingText, '4.8');
    expect(m.jobs, 88);
    expect(m.radiusKm, 25);
    expect(m.serviceList.map((x) => x.id), [31, 32]);
    expect(m.serviceList.first.name, 'Ditch & Drainage');
    expect(m.serviceList.first.rate, 4200);
  });

  test('a machine nobody has rated yet says "New"', () {
    final MachineInfo m = MachineInfo.fromJson({..._machine, 'rating': null});
    expect(m.rating, isNull);
    expect(m.ratingText, 'New');
  });

  test('a booking from the backend becomes a MachineBooking', () {
    final MachineBooking b = MachineryService.bookingFromJson({
      'id': 12,
      'code': '#MC-1012',
      'machine_id': 7,
      'items': [
        {'service_id': 32, 'name': 'Pit Digging', 'unit': 'hour', 'qty': 5, 'rate': 4200},
      ],
      'list_total': 21000,
      'agreed_total': 20000,
      'date': '2026-11-20',
      'time': '06:00 AM',
      'estate': 'Green Valley',
      'km': 3.2,
      'status': 'CONFIRMED',
      'chat': [
        {'mine': true, 'text': 'Hi', 'at': '2026-11-10T08:00:00.000Z'},
        {'mine': false, 'text': 'Sure', 'at': '2026-11-10T08:01:00.000Z'},
      ],
      'created_at': '2026-11-10T08:02:00.000Z',
      'machine': _machine,
    });
    expect(b.serverId, 12);
    expect(b.id, '#MC-1012');
    expect(b.machineName, 'JCB 3CX');
    expect(b.provider, 'Kithsiri Earthmovers');
    expect(b.category, 'Backhoe');
    expect(b.date, DateTime(2026, 11, 20));
    expect(b.time, '06:00 AM');
    expect(b.total, 20000);
    expect(b.listTotal, 21000);
    expect(b.items.single.name, 'Pit Digging');
    expect(b.items.single.qty, 5.0);
    expect(b.items.single.serviceId, 32);
    expect(b.chat.length, 2);
    expect(b.chat.first.mine, isTrue);
    expect(b.km, 3.2);
    expect(b.machineAt, isNotNull);
    expect(b.info?.id, 7);
  });

  test('dates are sent to the backend as YYYY-MM-DD', () {
    expect(isoDate(DateTime(2026, 3, 5)), '2026-03-05');
    expect(isoDate(DateTime(2026, 11, 20)), '2026-11-20');
  });
}
