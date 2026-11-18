import '../../widgets/land_owner_rating_dialog.dart';
import '../../widgets/deal_cancellation_dialog.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../models/provider_booking_request.dart';
import '../../services/api_client.dart';
import '../../services/machinery_api.dart';
import '../../widgets/owner_widgets.dart';
import '../../widgets/app_bottom_nav.dart';
import '../buyer/buyer_format.dart';
import 'provider_request_widgets.dart';
import 'revise_request_dialog.dart';
import '../../theme/app_theme.dart';

class ProviderRequestPage extends StatefulWidget {
  final ProviderBookingRequest request;
  final List<ProviderBookingRequest> bookings;
  final bool showMap;
  final MachineryApi? api;
  final bool isOwner;
  final ValueChanged<AppTab>? onProviderTab;
  final Future<ProviderBookingRequest> Function(Map<String, dynamic>)?
  submitDraft;
  const ProviderRequestPage({
    super.key,
    required this.request,
    this.bookings = const [],
    this.showMap = true,
    this.api,
    this.isOwner = false,
    this.onProviderTab,
    this.submitDraft,
  });
  @override
  State<ProviderRequestPage> createState() => _ProviderRequestPageState();
}

class _ProviderRequestPageState extends State<ProviderRequestPage> {
  late ProviderBookingRequest _request = widget.request;
  final _message = TextEditingController();
  final _chatScroll = ScrollController();
  String? _messageError;
  bool _busy = false;
  Timer? _poll;
  bool get _preview => widget.api == null;
  bool get _draft => widget.submitDraft != null && _request.id.isEmpty;

  /// Only the provider answers a request, and only with accept or decline.
  bool get _canAccept => !widget.isOwner && _request.canAccept;
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
    _message.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  void _notify(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> _refresh({bool quiet = false}) async {
    if (_preview || _draft || _busy) return;
    try {
      final latest = await widget.api!.request(_request.id);
      if (mounted) setState(() => _request = latest);
    } on ApiException catch (error) {
      if (mounted && !quiet) _notify(error.message);
    }
  }

  Future<void> _rateCounterparty() async {
    final rating = await showLandOwnerRatingDialog(
      context,
      party: widget.isOwner ? 'machinery provider' : 'land owner',
    );
    if (rating == null || !mounted) return;
    await _perform(
      widget.isOwner ? 'rate-provider' : 'complete-and-rate',
      body: {'rating': rating},
    );
  }

  Future<bool> _perform(
    String action, {
    String? message,
    double? rate,
    Map<String, dynamic>? body,
  }) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      if (_draft) {
        final latest = await widget.submitDraft!({
          ...?body,
          if (message != null) 'message': message,
        });
        if (mounted) setState(() => _request = latest);
      } else if (_preview) {
        if (action == 'revise') {
          _notify('Changing a request is not available in the preview.');
          return false;
        }
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
        final latest = action == 'revise'
            ? await widget.api!.revise(_request, body ?? const {})
            : await widget.api!.respond(
                _request,
                action,
                message: message,
                rate: rate,
                details: body,
              );
        if (mounted) setState(() => _request = latest);
      }
      return true;
    } on ApiException catch (error) {
      if (mounted) _notify(error.message);
      if (error.statusCode == 409 && !_preview && !_draft) {
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

  /// The land owner offers a different price or changes the request.
  Future<void> _changeRequest() async {
    final body = await showReviseRequestDialog(
      context,
      _request,
      initialRequest: _draft,
    );
    if (body == null || !mounted) return;
    await _perform('revise', body: body);
  }

  Future<void> _finish(bool accept) async {
    final yes = await showThemedDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
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

  Future<void> _cancelBooking() async {
    final details = await showDealCancellationDialog(
      context,
      type: DealCancellationType.machinery,
    );
    if (details == null || !mounted) return;
    final saved = await _perform('cancel', body: details);
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
    final utc = DateTime.now().toUtc().add(const Duration(minutes: 330));
    final sriLankaNow = DateTime(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
      utc.second,
    );
    final offerIsMine = widget.isOwner
        ? request.proposedBy == RequestSpeaker.owner
        : request.proposedBy == RequestSpeaker.provider;
    return OwnerPage(
      currentTab: AppTab.chats,
      bottom: widget.onProviderTab == null
          ? null
          : AppBottomNav(
              current: AppTab.chats,
              onProviderTab: (tab) {
                Navigator.pop(context);
                widget.onProviderTab!(tab);
              },
            ),
      child: ColoredBox(
        color: const Color(0xFFEFE9DF),
        child: Column(
          children: [
            _chatHeader(request),
            if (_busy) const LinearProgressIndicator(),
            Expanded(
              child: AbsorbPointer(
                absorbing: _busy,
                child: ListView(
                  controller: _chatScroll,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
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
                        !_draft &&
                        !request.workConfirmed &&
                        ((widget.isOwner && request.isPending) ||
                            request.status == ProviderRequestStatus.confirmed))
                      OutlinedButton(
                        onPressed: _cancelBooking,
                        child: const Text('Cancel booking'),
                      ),
                    if (request.workConfirmed)
                      const Text('Completed')
                    else if (request.workFinished &&
                        request.status == ProviderRequestStatus.confirmed)
                      const Text('Awaiting land owner confirmation'),
                    if (!_preview &&
                        !widget.isOwner &&
                        request.status == ProviderRequestStatus.confirmed &&
                        !request.workFinished &&
                        !request.startsAt.isAfter(sriLankaNow))
                      FilledButton(
                        onPressed: () => _perform('finish-work'),
                        child: const Text('Mark work finished'),
                      ),
                    if (!_preview &&
                        widget.isOwner &&
                        request.status == ProviderRequestStatus.confirmed &&
                        request.workFinished &&
                        !request.workConfirmed)
                      FilledButton(
                        onPressed: () => _perform('confirm-work'),
                        child: const Text('Confirm completion'),
                      ),
                    if (!_preview &&
                        request.workConfirmed &&
                        (widget.isOwner
                                ? request.providerRating
                                : request.landOwnerRating) ==
                            null)
                      FilledButton.icon(
                        onPressed: _rateCounterparty,
                        icon: const Icon(Icons.star_outline),
                        label: Text(
                          widget.isOwner ? 'Rate provider' : 'Rate land owner',
                        ),
                      ),
                    _section(
                      _draft
                          ? 'Draft Booking Request'
                          : widget.isOwner && request.isPending
                          ? 'Booking Request Sent'
                          : requestStatusLabel(request),
                      Icons.circle,
                      [
                        _detail(
                          request.agreedRate != null
                              ? 'Agreed Rate'
                              : offerIsMine
                              ? 'Your Offer'
                              : 'Received Offer',
                          '${rupees(request.agreedRate ?? request.proposedRate)} / ${request.unit}\n${requestQuantity(request)} - Total ${rupees((request.agreedRate ?? request.proposedRate) * request.quantity)}\nService date: ${requestDate(request.startsAt)}, ${clockTime(request.startsAt)} - ${clockTime(request.endsAt)}',
                          Icons.payments_outlined,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          request.agreedRate != null
                              ? 'Booking confirmed.'
                              : _draft
                              ? 'Send a message or an offer to start the negotiation.'
                              : widget.isOwner
                              ? 'Waiting for the provider to accept or decline. You can change the price or the request below.'
                              : 'Accept or decline this request. Only the land owner can change the price or the request.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: kOwnerGreen,
                          ),
                        ),
                      ],
                    ),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: ExpansionTile(
                        title: const Text('Booking details'),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          12,
                          0,
                          12,
                          12,
                        ),
                        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
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
                          const SizedBox(height: 8),
                          _location(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (request.isPending) ...[
                      if (widget.isOwner)
                        OutlinedButton.icon(
                          key: const Key('change-request'),
                          onPressed: _changeRequest,
                          icon: const Icon(
                            Icons.edit_calendar_outlined,
                            size: 18,
                          ),
                          label: const Text('Change price or request'),
                        )
                      else
                        FilledButton(
                          onPressed: _canAccept ? () => _finish(true) : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.green,
                            minimumSize: const Size.fromHeight(50),
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('Accept & Lock Booking'),
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
                    const SizedBox(height: 12),
                    if (request.messages.isEmpty)
                      const Center(
                        child: Text(
                          'No messages yet.',
                          style: TextStyle(color: kOwnerMuted),
                        ),
                      ),
                    for (final message in request.messages) _bubble(message),
                  ],
                ),
              ),
            ),
            if (widget.isOwner && request.isPending) _composer(),
          ],
        ),
      ),
    );
  }

  Widget _chatHeader(ProviderBookingRequest request) {
    final name = widget.isOwner
        ? request.providerName ?? 'Provider'
        : request.ownerName;
    return Container(
      color: kOwnerCream,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          const BackButton(color: kOwnerInk),
          CircleAvatar(
            radius: 19,
            backgroundColor: kOwnerGreen,
            foregroundColor: Colors.white,
            child: Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kOwnerGreen,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Machinery Request',
                  style: TextStyle(color: kOwnerMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (!_preview && !_draft)
            IconButton(
              tooltip: 'Refresh request',
              onPressed: _busy ? null : _refresh,
              icon: const Icon(Icons.refresh, color: kOwnerGreen),
            ),
        ],
      ),
    );
  }

  Widget _bubble(ProviderRequestMessage message) {
    final mine = (message.sender == RequestSpeaker.owner) == widget.isOwner;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
        constraints: const BoxConstraints(maxWidth: 285),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFFDCF3DC) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 3),
            bottomRight: Radius.circular(mine ? 3 : 14),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: const TextStyle(
                color: kOwnerInk,
                fontSize: 14,
                height: 1.35,
              ),
            ),
            if (message.rate != null)
              Text(
                '${rupees(message.rate!)} / ${_request.unit}',
                style: const TextStyle(
                  color: kOwnerGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (message.serviceDate != null)
              Text(
                message.serviceDate!,
                style: const TextStyle(fontSize: 12, color: kOwnerMuted),
              ),
            const SizedBox(height: 3),
            Align(
              widthFactor: 1,
              alignment: Alignment.centerRight,
              child: Text(
                clockTime(message.sentAt),
                style: const TextStyle(fontSize: 10, color: kOwnerMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_busy) return;
    final message = _message.text.trim();
    if (message.isEmpty) {
      setState(() => _messageError = 'Enter a message.');
      return;
    }
    final saved = await _perform('messages', message: message);
    if (!saved || !mounted) return;
    setState(() {
      _message.clear();
      _messageError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.jumpTo(_chatScroll.position.maxScrollExtent);
      }
    });
  }

  Widget _composer() => Container(
    color: kOwnerCream,
    padding: const EdgeInsets.all(8),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            key: const Key('provider-message'),
            controller: _message,
            enabled: !_busy,
            minLines: 1,
            maxLines: 3,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _sendMessage(),
            decoration: InputDecoration(
              hintText: 'Type a message',
              errorText: _messageError,
              counterText: '',
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: 'Send message',
          onPressed: _busy ? null : _sendMessage,
          style: IconButton.styleFrom(
            backgroundColor: kOwnerGreen,
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.send_rounded, size: 20),
        ),
      ],
    ),
  );

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
                  const SizedBox.shrink(),
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
