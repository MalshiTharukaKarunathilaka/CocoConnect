import 'machinery_api.dart';
import 'package:latlong2/latlong.dart';
import '../models/provider_booking_request.dart';
import '../models/provider_calendar.dart';

/// Injectable read boundary for the first calendar feature. The backend adapter
/// will replace the preview repository when machinery APIs are implemented.
abstract class ProviderCalendarRepository {
  bool get isPreview;
  Future<ProviderCalendarMonth> loadMonth(DateTime month);
}

/// Production calendar adapter: never supplies demo bookings or prices.
class LiveProviderCalendarRepository implements ProviderCalendarRepository {
  final MachineryApi api;
  List<Map<String, dynamic>> machines = [];
  int? selectedMachineId;
  LiveProviderCalendarRepository({this.api = const MachineryApi()});
  @override
  bool get isPreview => false;
  @override
  Future<ProviderCalendarMonth> loadMonth(DateTime month) async {
    machines = await api.machines();
    if (machines.isEmpty) {
      selectedMachineId = null;
      return const ProviderCalendarMonth();
    }
    if (!machines.any((m) => m['id'] == selectedMachineId)) {
      selectedMachineId = machines.first['id'] as int;
    }
    return api.calendar(selectedMachineId!, month);
  }
}

/// Isolated UI fixtures. Never reads or writes the shared Supabase database.
class PreviewProviderCalendarRepository implements ProviderCalendarRepository {
  const PreviewProviderCalendarRepository();

  @override
  bool get isPreview => true;

  @override
  Future<ProviderCalendarMonth> loadMonth(DateTime month) async {
    String key(int day) =>
        providerDateKey(DateTime(month.year, month.month, day));
    return ProviderCalendarMonth(
      days: {
        key(6): const ProviderCalendarDay(incoming: 2),
        key(12): const ProviderCalendarDay(confirmed: 1),
        key(16): const ProviderCalendarDay(incoming: 1, confirmed: 1),
        key(22): const ProviderCalendarDay(
          state: ProviderDayState.fullyBooked,
          confirmed: 2,
        ),
        key(24): const ProviderCalendarDay(state: ProviderDayState.maintenance),
      },
      requests: [
        for (final entry in [
          (6, 'Gamini Perera', 'Disc Ploughing', 8.0, 6800.0),
          (6, 'Nimal Silva', 'Slasher', 4.0, 5000.0),
          (16, 'Kamala Fernando', 'Disc Ploughing', 6.0, 6500.0),
        ])
          ProviderBookingRequest(
            id: '${key(entry.$1)}-${entry.$2}',
            machineId: 'preview-tractor-1',
            ownerName: entry.$2,
            estateName: entry.$2 == 'Gamini Perera'
                ? 'Green Valley Estate'
                : 'Coconut Grove Estate',
            address: 'Narammala Road, Kurunegala',
            phone: '0771234567',
            machinery: 'Tractor',
            service: entry.$3,
            quantity: entry.$4,
            unit: 'acre',
            startsAt: DateTime(month.year, month.month, entry.$1, 7, 30),
            endsAt: DateTime(month.year, month.month, entry.$1, 12),
            estateAt: const LatLng(7.4863, 80.3647),
            providerAt: const LatLng(7.461, 80.342),
            proposedRate: entry.$5,
            messages: [
              ProviderRequestMessage(
                text:
                    'Can you provide ${entry.$3.toLowerCase()} for ${entry.$4} acres? The land is flat and easily accessible.',
                sender: RequestSpeaker.owner,
                sentAt: DateTime(month.year, month.month, entry.$1, 6, 45),
                rate: entry.$5,
              ),
            ],
          ),
      ],
      rates: const [
        ProviderServiceRate('Slasher', 5000, 'acre'),
        ProviderServiceRate('Disc Ploughing', 7000, 'acre'),
        ProviderServiceRate('Trailer', 9000, 'day'),
      ],
    );
  }
}
