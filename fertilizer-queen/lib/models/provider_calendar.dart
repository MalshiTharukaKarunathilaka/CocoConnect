import 'provider_booking_request.dart';

/// Provider calendar presentation data. Booking persistence is added separately.
enum ProviderDayState { available, unavailable, maintenance, fullyBooked }

String providerDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime providerToday() {
  final local = DateTime.now().toUtc().add(const Duration(minutes: 330));
  return DateTime(local.year, local.month, local.day);
}

class ProviderCalendarDay {
  final ProviderDayState state;
  final int confirmed;
  final int incoming;

  const ProviderCalendarDay({
    this.state = ProviderDayState.available,
    this.confirmed = 0,
    this.incoming = 0,
  });
}

class ProviderServiceRate {
  final int? id;
  final String name;
  final double rate;
  final String unit;

  const ProviderServiceRate(this.name, this.rate, this.unit, {this.id});
}

class ProviderCalendarMonth {
  final Map<String, ProviderCalendarDay> days;
  final List<ProviderServiceRate> rates;
  final List<ProviderBookingRequest> requests;

  const ProviderCalendarMonth({
    this.days = const {},
    this.rates = const [],
    this.requests = const [],
  });

  Iterable<String> get dateKeys => {
    ...days.keys,
    for (final request in requests)
      for (
        var date = DateTime(
          request.startsAt.year,
          request.startsAt.month,
          request.startsAt.day,
        );
        date.isBefore(request.endsAt);
        date = date.add(const Duration(days: 1))
      )
        providerDateKey(date),
  };

  ProviderCalendarDay day(DateTime date) {
    final base = days[providerDateKey(date)] ?? const ProviderCalendarDay();
    final onDate = requests
        .where(
          (request) =>
              request.startsAt.isBefore(
                DateTime(date.year, date.month, date.day + 1),
              ) &&
              request.endsAt.isAfter(DateTime(date.year, date.month, date.day)),
        )
        .toList();
    if (onDate.isEmpty) return base;
    final confirmed =
        onDate
            .where((r) => r.status == ProviderRequestStatus.confirmed)
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    var covered = DateTime(date.year, date.month, date.day);
    for (final request in confirmed) {
      if (request.startsAt.isAfter(covered)) break;
      if (request.endsAt.isAfter(covered)) covered = request.endsAt;
    }
    final full =
        covered.isAfter(DateTime(date.year, date.month, date.day + 1)) ||
        covered == DateTime(date.year, date.month, date.day + 1);
    return ProviderCalendarDay(
      state: base.state == ProviderDayState.available && full
          ? ProviderDayState.fullyBooked
          : base.state,
      confirmed:
          base.confirmed +
          onDate
              .where((r) => r.status == ProviderRequestStatus.confirmed)
              .length,
      incoming: onDate.where((r) => r.isPending).length,
    );
  }
}
