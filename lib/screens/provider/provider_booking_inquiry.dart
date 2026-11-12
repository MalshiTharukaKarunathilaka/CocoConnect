import 'package:flutter/material.dart';
import '../../models/provider_booking_request.dart';
import '../../widgets/owner_widgets.dart';
import '../buyer/buyer_format.dart';
import 'provider_request_widgets.dart';
import '../../theme/app_theme.dart';

Future<ProviderBookingRequest?> showProviderBookingInquiry(
  BuildContext context, {
  required DateTime date,
  required List<ProviderBookingRequest> requests,
  bool isPreview = true,
}) {
  if (requests.isEmpty) return Future.value();
  return showThemedBottomSheet<ProviderBookingRequest>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    constraints: const BoxConstraints(maxWidth: 430),
    builder: (_) =>
        _Inquiry(date: date, requests: requests, isPreview: isPreview),
  );
}

class _Inquiry extends StatefulWidget {
  final bool isPreview;
  final DateTime date;
  final List<ProviderBookingRequest> requests;
  const _Inquiry({
    required this.date,
    required this.requests,
    required this.isPreview,
  });
  @override
  State<_Inquiry> createState() => _InquiryState();
}

class _InquiryState extends State<_Inquiry> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    final request = widget.requests[_index];
    return DraggableScrollableSheet(
      initialChildSize: .78,
      minChildSize: .5,
      maxChildSize: .95,
      expand: false,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    label: Text(
                      request.isPending
                          ? 'ACTION REQUIRED'
                          : 'CONFIRMED BOOKING',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    backgroundColor: request.isPending
                        ? AppColors.dangerSoft
                        : kOwnerGreenSoft,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close inquiry',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            'Date Inquiry: ${requestDate(widget.date)}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: kOwnerInk,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.isPreview)
            const Text(
              'Preview request · No customer will be contacted.',
              style: TextStyle(fontSize: 12, color: kOwnerMuted),
            ),
          if (widget.requests.length > 1)
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous request',
                  onPressed: _index == 0
                      ? null
                      : () => setState(() => _index--),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    'Request ${_index + 1} of ${widget.requests.length}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Next request',
                  onPressed: _index == widget.requests.length - 1
                      ? null
                      : () => setState(() => _index++),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: providerRequestPanel,
              borderRadius: BorderRadius.circular(14),
            ),
            child: ProviderCustomerCard(request: request),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: providerRequestPanel,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.agriculture_outlined, color: kOwnerGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Requested Service',
                        style: TextStyle(fontSize: 12, color: kOwnerMuted),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${request.machinery} ${request.service}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        requestQuantity(request),
                        style: const TextStyle(color: kOwnerGreen),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kOwnerGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.status == ProviderRequestStatus.confirmed
                      ? 'AGREED RATE'
                      : 'CURRENT OFFER',
                  style: const TextStyle(
                    color: AppColors.greenSoft,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${rupees(request.agreedRate ?? request.proposedRate)} / ${request.unit}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total: ${rupees((request.agreedRate ?? request.proposedRate) * request.quantity)}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, request),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.green,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.arrow_forward, size: 18),
            iconAlignment: IconAlignment.end,
            label: Text(
              request.isPending
                  ? 'Review & Respond to Request'
                  : 'View Booking',
            ),
          ),
        ],
      ),
    );
  }
}
