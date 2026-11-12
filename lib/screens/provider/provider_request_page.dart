import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../models/provider_booking_request.dart';
import '../../services/api_client.dart';
import '../../services/machinery_api.dart';
import '../../widgets/owner_widgets.dart';
import '../buyer/buyer_format.dart';
import 'provider_request_widgets.dart';
import '../../theme/app_theme.dart';

class ProviderRequestPage extends StatefulWidget {
  final ProviderBookingRequest request;
  final List<ProviderBookingRequest> bookings;
  final bool showMap;
  final MachineryApi? api;
  final bool isOwner;
  const ProviderRequestPage({
    super.key,
    required this.request,
    this.bookings = const [],
    this.showMap = true,
    this.api,
    this.isOwner = false,
  });
  @override
  State<ProviderRequestPage> createState() => _ProviderRequestPageState();
}

class _ProviderRequestPageState extends State<ProviderRequestPage> {
  late ProviderBookingRequest _request = widget.request;
  late final _rate = TextEditingController(
    text: '${widget.request.proposedRate}',
  );
  final _message = TextEditingController();
  final _rateForm = GlobalKey<FormState>();
  String? _messageError;
  bool _busy = false;
  Timer? _poll;
  bool get _preview => widget.api == null;
  bool get _canAccept =>
      _request.isPending &&
      (widget.isOwner
          ? _request.proposedBy == RequestSpeaker.provider &&
                !_request.customerAccepted
          : _request.canAccept);
  @override
  void initState() {
    super.initState();
    if (!_preview) {
      _poll = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _refresh(quiet: true),
      );
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _rate.dispose();
    _message.dispose();
    super.dispose();
  }

  void _notify(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> _refresh({bool quiet = false}) async {
    if (_preview || _busy) return;
    try {
      final latest = await widget.api!.request(_request.id);
      if (mounted) setState(() => _request = latest);
    } on ApiException catch (error) {
      if (mounted && !quiet) _notify(error.message);
    }
  }

  Future<bool> _perform(String action, {String? message, double? rate}) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      if (_preview) {
        if (action == 'messages') {
          if (rate != null) {
            _request.counter(rate);
          } else {
            _request.sendMessage(message!);
          }
        }
        if (action == 'accept') _request.accept(widget.bookings);
        if (action == 'decline') _request.decline();
      } else {
        final latest = await widget.api!.respond(
          _request,
          action,
          message: message,
          rate: rate,
        );
        if (mounted) setState(() => _request = latest);
      }
      return true;
    } on ApiException catch (error) {
      if (mounted) _notify(error.message);
      if (error.statusCode == 409 && !_preview) {
        try {
          final latest = await widget.api!.request(_request.id);
          if (mounted) setState(() => _request = latest);
        } on ApiException catch (_) {}
      }
      return false;
    } on StateError catch (error) {
      if (mounted) _notify(error.message);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish(bool accept) async {
    if (accept && widget.isOwner) {
      await _perform('agree');
      return;
    }
    final yes = await showThemedDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          accept
              ? (_preview
                    ? 'Lock this preview booking?'
                    : 'Confirm and lock this booking?')
              : (_preview
                    ? 'Decline this preview request?'
                    : 'Decline this request?'),
        ),
        content: Text(
          accept
              ? 'Reserve ${clockTime(_request.startsAt)} - ${clockTime(_request.endsAt)} for ${rupees(_request.proposedTotal)} total.${_preview ? ' This changes the preview only; no customer is notified.' : ''}'
              : _preview
              ? 'This changes the preview only. The date remains free for other requests.'
              : 'The request will be declined without reserving the date.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              accept
                  ? (_preview ? 'Lock preview booking' : 'Confirm booking')
                  : (_preview ? 'Decline preview request' : 'Decline request'),
            ),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final saved = await _perform(accept ? 'accept' : 'decline');
    if (saved && mounted) Navigator.pop(context, true);
  }

  Future<void> _cancelOwner() async {
    final yes = await showThemedDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel booking request?'),
        content: const Text(
          'The request will be cancelled and its reserved time slot released.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Booking'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final saved = await _perform('cancel');
    if (saved && mounted) Navigator.pop(context, true);
  }

  Widget _section(String title, IconData icon, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: OwnerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: kOwnerGreen, size: 20),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kOwnerInk,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      );
  @override
  Widget build(BuildContext context) =>
      AppThemeScope(child: Builder(builder: _page));

  Widget _page(BuildContext context) {
    final request = _request;
    final offerIsMine = widget.isOwner
        ? request.proposedBy == RequestSpeaker.owner
        : request.proposedBy == RequestSpeaker.provider;
    return OwnerPage(
      child: Column(
        children: [
          OwnerHeader(
            title: widget.isOwner
                ? 'Machinery Request & Negotiation'
                : 'Service Request & Negotiation',
            actions: [
              if (!_preview)
                IconButton(
                  tooltip: 'Refresh request',
                  onPressed: _busy ? null : () => _refresh(),
                  icon: const Icon(Icons.refresh, color: kOwnerGreen),
                ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: AbsorbPointer(
              absorbing: _busy,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (_preview)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Preview workflow - Changes stay on this device for this calendar visit.',
                        style: TextStyle(fontSize: 12, color: kOwnerBrown),
                      ),
                    ),
                  if (!_preview &&
                      widget.isOwner &&
                      (request.isPending ||
                          request.status == ProviderRequestStatus.confirmed))
                    OutlinedButton(
                      onPressed: _cancelOwner,
                      child: const Text('Cancel Booking Request'),
                    ),
                  _location(),
                  const SizedBox(height: 16),
                  _section(
                    widget.isOwner && request.isPending
                        ? 'Booking Request Sent'
                        : requestStatusLabel(request),
                    Icons.circle,
                    [
                      _detail(
                        request.agreedRate != null
                            ? 'Agreed Rate'
                            : offerIsMine
                            ? 'Your Proposed Counteroffer'
                            : 'Received Offer',
                        '${rupees(request.agreedRate ?? request.proposedRate)} / ${request.unit}\n${requestQuantity(request)} - Total ${rupees((request.agreedRate ?? request.proposedRate) * request.quantity)}',
                        Icons.payments_outlined,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        request.agreedRate != null
                            ? 'Booking confirmed.'
                            : request.customerAccepted
                            ? 'The current price is agreed. The provider can now lock the booking.'
                            : offerIsMine
                            ? 'Awaiting the other participant’s agreement. This is a proposal.'
                            : 'Accept the received offer or propose a counteroffer.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: kOwnerGreen,
                        ),
                      ),
                    ],
                  ),
                  OwnerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ProviderCustomerCard(
                          request: request,
                          ownerView: widget.isOwner,
                        ),
                        const SizedBox(height: 18),
                        _detail(
                          'Machinery & Job',
                          '${request.machineName ?? request.machinery} - ${request.service}\n${request.items.isEmpty ? requestQuantity(request) : request.items.map((i) => '${i['name']}: ${i['quantity']} ${i['unit']}').join('\n')}',
                          Icons.agriculture_outlined,
                        ),
                        const SizedBox(height: 8),
                        _detail(
                          'Schedule & Time',
                          '${requestDate(request.startsAt)}\n${clockTime(request.startsAt)} - ${clockTime(request.endsAt)}',
                          Icons.calendar_today_outlined,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _section('Negotiation Log', Icons.forum_outlined, [
                    if (request.messages.isEmpty)
                      const Text(
                        'No messages yet.',
                        style: TextStyle(color: kOwnerMuted),
                      ),
                    for (final message in request.messages)
                      Align(
                        alignment:
                            (message.sender == RequestSpeaker.owner) ==
                                widget.isOwner
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(maxWidth: 285),
                          decoration: BoxDecoration(
                            color:
                                (message.sender == RequestSpeaker.owner) ==
                                    widget.isOwner
                                ? kOwnerGreenSoft
                                : providerRequestPanel,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${(message.sender == RequestSpeaker.owner) == widget.isOwner
                                    ? 'You'
                                    : widget.isOwner
                                    ? (request.providerName ?? 'Provider')
                                    : request.ownerName} - ${clockTime(message.sentAt)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: kOwnerMuted,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                message.text,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                              if (message.rate != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '${rupees(message.rate!)} / ${request.unit}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: kOwnerGreen,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (request.isPending) ...[
                      const SizedBox(height: 5),
                      TextField(
                        key: const Key('provider-message'),
                        controller: _message,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 2000,
                        decoration: InputDecoration(
                          hintText: 'Write a message',
                          errorText: _messageError,
                          filled: true,
                          fillColor: providerRequestPanel,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () async {
                            if (_message.text.trim().isEmpty) {
                              setState(
                                () => _messageError = 'Enter a message.',
                              );
                              return;
                            }
                            final saved = await _perform(
                              'messages',
                              message: _message.text.trim(),
                            );
                            if (saved && mounted) {
                              setState(() {
                                _message.clear();
                                _messageError = null;
                              });
                            }
                          },
                          icon: const Icon(Icons.send_outlined, size: 17),
                          label: const Text('Send message'),
                        ),
                      ),
                    ],
                  ]),
                  if (request.isPending) ...[
                    _section(
                      'Propose a Counter Rate',
                      Icons.price_change_outlined,
                      [
                        Form(
                          key: _rateForm,
                          child: TextFormField(
                            key: const Key('counter-rate'),
                            controller: _rate,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              prefixText: 'Rs. ',
                              suffixText: '/ ${request.unit}',
                              filled: true,
                              fillColor: providerRequestPanel,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(9),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (value) {
                              final rate = double.tryParse(value?.trim() ?? '');
                              return rate == null ||
                                      !rate.isFinite ||
                                      rate <= 0 ||
                                      rate > 100000000
                                  ? 'Enter a positive rate up to Rs. 100,000,000.'
                                  : null;
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () async {
                            if (!_rateForm.currentState!.validate()) return;
                            await _perform(
                              'messages',
                              rate: double.parse(_rate.text.trim()),
                            );
                          },
                          icon: const Icon(Icons.sync, size: 18),
                          label: const Text('Update Rate'),
                        ),
                        if (_preview &&
                            request.proposedBy == RequestSpeaker.provider &&
                            !request.customerAccepted)
                          TextButton(
                            onPressed: () =>
                                setState(request.previewCustomerAccepts),
                            child: const Text(
                              'Preview: customer accepts offer',
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                    FilledButton(
                      onPressed: _canAccept ? () => _finish(true) : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.green,
                        minimumSize: const Size.fromHeight(50),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        widget.isOwner
                            ? 'Agree to Counteroffer'
                            : 'Accept & Lock Booking',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed:
                              (widget.isOwner
                                      ? request.providerPhone
                                      : request.phone) ==
                                  null
                              ? null
                              : () => showCustomerContact(
                                  context,
                                  request,
                                  ownerView: widget.isOwner,
                                ),
                          icon: const Icon(Icons.phone_outlined, size: 16),
                          label: Text(
                            widget.isOwner
                                ? 'Contact Provider'
                                : 'Call Customer',
                          ),
                        ),
                        if (!widget.isOwner)
                          TextButton.icon(
                            onPressed: () => _finish(false),
                            style: TextButton.styleFrom(
                              foregroundColor: kOwnerRed,
                            ),
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Decline'),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: providerRequestPanel,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: kOwnerGreen),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, color: kOwnerMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
  Widget _location() {
    final request = _request;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          if (request.estateAt != null &&
              request.providerAt != null &&
              widget.showMap)
            SizedBox(
              height: 140,
              child: FlutterMap(
                options: MapOptions(
                  initialCameraFit: CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints([
                      request.estateAt!,
                      request.providerAt!,
                    ]),
                    padding: const EdgeInsets.all(32),
                  ),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.kapconnect_mobile',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: request.providerAt!,
                        child: const Icon(
                          Icons.agriculture,
                          color: kOwnerGreen,
                          size: 26,
                        ),
                      ),
                      Marker(
                        point: request.estateAt!,
                        child: const Icon(
                          Icons.location_on,
                          color: kOwnerRed,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                  const SimpleAttributionWidget(
                    source: Text('OpenStreetMap contributors'),
                  ),
                ],
              ),
            )
          else
            Container(
              height: 90,
              color: kOwnerGreenSoft,
              alignment: Alignment.center,
              child: const Icon(
                Icons.map_outlined,
                size: 38,
                color: kOwnerGreen,
              ),
            ),
          Container(
            width: double.infinity,
            color: kOwnerGreenSoft,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.distanceKm == null
                      ? 'Location distance unavailable'
                      : '${request.distanceKm!.toStringAsFixed(1)} km - straight-line distance',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: kOwnerGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Provider yard to ${request.estateName}',
                  style: const TextStyle(fontSize: 12),
                ),
                if (_preview)
                  const Text(
                    'Sample locations - Travel time unavailable',
                    style: TextStyle(fontSize: 11, color: kOwnerMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
