import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/provider_booking_request.dart';
import '../../widgets/owner_widgets.dart';
import '../account_dialogs.dart';
import '../buyer/buyer_format.dart';
import '../../theme/app_theme.dart';

const providerRequestPanel = AppColors.page;

String requestDate(DateTime date) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return '${weekdays[date.weekday - 1]}, ${shortDate(date)}';
}

String requestQuantity(ProviderBookingRequest request) =>
    '${withCommas(request.quantity)} ${switch (request.unit) {
      'acre' => 'acres',
      'hour' => 'hours',
      'booking' => request.quantity == 1 ? 'booking' : 'bookings',
      _ => 'days',
    }}';
String requestStatusLabel(ProviderBookingRequest request) =>
    switch (request.status) {
      ProviderRequestStatus.pending => 'Incoming Booking Request',
      ProviderRequestStatus.confirmed => 'Confirmed Booking',
      ProviderRequestStatus.declined => 'Declined Request',
      ProviderRequestStatus.cancelled => 'Cancelled Booking',
    };

Future<void> showCustomerContact(
  BuildContext context,
  ProviderBookingRequest request, {
  bool ownerView = false,
}) => showThemedDialog<void>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: Text(
      ownerView ? (request.providerName ?? 'Provider') : request.ownerName,
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Dial this number in your phone app.'),
        const SizedBox(height: 12),
        SelectableText(
          (ownerView ? request.providerPhone : request.phone) ??
              'No contact number provided',
        ),
        const SizedBox(height: 8),
        const Text(
          'No call is placed automatically.',
          style: TextStyle(fontSize: 12, color: kOwnerMuted),
        ),
      ],
    ),
    actions: [
      if ((ownerView ? request.providerPhone : request.phone) != null)
        TextButton(
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(
                text: (ownerView ? request.providerPhone : request.phone)!,
              ),
            );
            if (ctx.mounted) {
              Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Number copied')));
              }
            }
          },
          child: const Text('Copy number'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Close'),
      ),
    ],
  ),
);

class ProviderCustomerCard extends StatelessWidget {
  final ProviderBookingRequest request;
  final bool ownerView;
  const ProviderCustomerCard({
    super.key,
    required this.request,
    this.ownerView = false,
  });
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CircleAvatar(
        radius: 27,
        backgroundColor: kOwnerGreenSoft,
        child: request.photoUrl == null
            ? Text(
                initialsOf(
                  (ownerView
                      ? (request.providerName ?? 'Provider')
                      : request.ownerName),
                ),
                style: const TextStyle(color: kOwnerGreen),
              )
            : ClipOval(
                child: Image.network(
                  request.photoUrl!,
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stack) => Text(
                    initialsOf(
                      (ownerView
                          ? (request.providerName ?? 'Provider')
                          : request.ownerName),
                    ),
                  ),
                ),
              ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (ownerView
                  ? (request.providerName ?? 'Provider')
                  : request.ownerName),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kOwnerInk,
              ),
            ),
            if (request.rating != null)
              Text(
                '★ ${request.rating}',
                style: const TextStyle(color: kOwnerGreen),
              ),
            const SizedBox(height: 3),
            Text(request.estateName, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 3),
            Text(
              request.address,
              style: const TextStyle(fontSize: 12, color: kOwnerMuted),
            ),
            if (request.distanceKm != null)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  '${request.distanceKm!.toStringAsFixed(1)} km · straight-line distance',
                  style: const TextStyle(fontSize: 12, color: kOwnerGreen),
                ),
              ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Customer contact',
        onPressed: (ownerView ? request.providerPhone : request.phone) == null
            ? null
            : () => showCustomerContact(context, request, ownerView: ownerView),
        icon: const Icon(Icons.phone_outlined, color: kOwnerGreen),
      ),
    ],
  );
}
