import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/machinery_widgets.dart';
import '../widgets/owner_widgets.dart';
import 'buyer/buyer_format.dart';
import 'machinery_negotiation_page.dart';

String _clock(DateTime t) {
  final int h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// Where a booked machine is in the job: request, accepted, on the way,
/// working, done. A booking made through the negotiation starts at step 2.
class MachineryBookingStatusPage extends StatelessWidget {
  final MachineBooking booking;

  const MachineryBookingStatusPage({super.key, required this.booking});

  Future<void> _cancel(BuildContext context) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this booking?'),
        content: Text(
          '${booking.service} on ${fullDate(booking.date)} will be cancelled '
          'and the date becomes free again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep booking'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Cancel booking',
              style: TextStyle(color: kOwnerRed),
            ),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    machineBookings[booking.machineName]?.removeWhere(
      (x) => x.id == booking.id,
    );
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(content: Text('Booking ${booking.id} cancelled')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MachineBooking b = booking;
    return OwnerPage(
      child: Column(
        children: [
          const OwnerHeader(title: 'Booking Status'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                _head(b),
                const SizedBox(height: 14),
                _progress(b),
                const SizedBox(height: 14),
                _provider(context, b),
                const SizedBox(height: 14),
                _location(b),
                const SizedBox(height: 14),
                _specs(b),
                if (!b.isCompleted) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    child: TextButton.icon(
                      onPressed: () => _cancel(context),
                      icon: const Icon(Icons.close, size: 20),
                      label: const Text(
                        'Cancel Request',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: kOwnerRed,
                        backgroundColor: const Color(0xFFFDECEC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Cancelling frees this date for other bookings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: kOwnerMuted),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "Created today, 5:33 PM" for a new booking, the date for an older one.
  String _created(MachineBooking b) {
    final DateTime n = DateTime.now();
    final bool today =
        b.createdAt.year == n.year &&
        b.createdAt.month == n.month &&
        b.createdAt.day == n.day;
    return today
        ? 'Created today, ${_clock(b.createdAt)}'
        : 'Booked on ${fullDate(b.createdAt)}';
  }

  Widget _head(MachineBooking b) => OwnerCard(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      children: [
        const Icon(Icons.circle, size: 11, color: kOwnerGreen),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Booking ${b.id}',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: kOwnerInk,
                ),
              ),
              Text(
                _created(b),
                style: const TextStyle(fontSize: 12.5, color: kOwnerMuted),
              ),
            ],
          ),
        ),
        b.isCompleted
            ? const OwnerPill(
                'Completed',
                icon: Icons.done_all,
                tone: PillTone.neutral,
              )
            : const OwnerPill('Confirmed', icon: Icons.check_circle_outline),
      ],
    ),
  );

  Widget _progress(MachineBooking b) {
    // 0 = done, 1 = active, 2 = still to come.
    final steps = <(String, String, int, IconData)>[
      ('Request Sent', 'Sent to ${b.provider}', 0, Icons.check),
      ('Provider Accepted', 'Price agreed with ${b.provider}', 1, Icons.sync),
      (
        'On the Way',
        '${b.category} mobilization to estate',
        2,
        Icons.local_shipping_outlined,
      ),
      ('Job in Progress', b.service, 2, Icons.agriculture),
      (
        'Job Completed & Verified',
        'Work signoff & settlement',
        2,
        Icons.verified_outlined,
      ),
    ];
    return OwnerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Order Progress',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: kOwnerInk,
                  ),
                ),
              ),
              OwnerPill(
                b.isCompleted ? 'Step 5 of 5' : 'Step 2 of 5',
                tone: PillTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < steps.length; i++)
            _step(
              steps[i].$1,
              steps[i].$2,
              b.isCompleted ? 0 : steps[i].$3,
              steps[i].$4,
              last: i == steps.length - 1,
              time: i == 0 ? _clock(b.createdAt) : null,
            ),
        ],
      ),
    );
  }

  Widget _step(
    String title,
    String sub,
    int state,
    IconData icon, {
    required bool last,
    String? time,
  }) {
    final bool done = state == 0;
    final bool active = state == 1;
    final Color dot = done
        ? kOwnerGreen
        : active
        ? const Color(0xFFBFE6C8)
        : const Color(0xFFEDEDEA);
    final Color fg = done
        ? Colors.white
        : active
        ? kOwnerGreen
        : const Color(0xFF9AA0A6);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                  child: Icon(icon, size: 17, color: fg),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: done ? kOwnerGreen : const Color(0xFFE2E2DE),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 14),
              child: Container(
                padding: active
                    ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
                    : EdgeInsets.zero,
                decoration: active
                    ? BoxDecoration(
                        color: const Color(0xFFEAF3F1),
                        borderRadius: BorderRadius.circular(10),
                      )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: done || active
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: state == 2
                                  ? const Color(0xFF6B7280)
                                  : kOwnerInk,
                            ),
                          ),
                        ),
                        if (active)
                          const Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: kOwnerGreen,
                            ),
                          ),
                        if (time != null)
                          Text(
                            time,
                            style: const TextStyle(
                              fontSize: 12,
                              color: kOwnerMuted,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      sub,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: state == 2
                            ? const Color(0xFF8A9096)
                            : kOwnerMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _provider(BuildContext context, MachineBooking b) {
    final String initials = b.provider
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    final String first = b.provider.split(' ').first;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EFEA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kOwnerBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (b.info != null)
                MachinePhoto(b.info!, width: 60, height: 60, radius: 14)
              else
                CircleAvatar(
                  radius: 28,
                  backgroundColor: kOwnerGreen,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            b.provider,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: kOwnerInk,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          size: 17,
                          color: kOwnerGreen,
                        ),
                      ],
                    ),
                    Text(
                      '${b.machineName} (${b.category})',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: kOwnerMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 15,
                          color: Color(0xFFF2A900),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${b.info?.rating ?? 4.9}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: kOwnerInk,
                          ),
                        ),
                        Text(
                          '  (${b.info?.jobs ?? 114} field bookings)',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: kOwnerMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kOwnerBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.schedule, size: 20, color: kOwnerGreen),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Response Time',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: kOwnerInk,
                        ),
                      ),
                      Text(
                        'Usually replies within 15 minutes',
                        style: TextStyle(fontSize: 12.5, color: kOwnerMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MachineryChatPage(booking: b),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text(
                      'Chat',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kOwnerGreen,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: kOwnerGreen),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Calling is not available in the demo'),
                      ),
                    ),
                    icon: const Icon(Icons.call_outlined, size: 18),
                    label: Text(
                      'Call $first',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kOwnerGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _location(MachineBooking b) {
    final LatLng? m = b.machineAt;
    final LatLng? e = b.estateAt;
    return OwnerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.explore_outlined, size: 22, color: kOwnerInk),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Equipment Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kOwnerInk,
                  ),
                ),
              ),
              if (b.km > 0) OwnerPill('${b.km.toStringAsFixed(1)} km away'),
            ],
          ),
          const SizedBox(height: 12),
          if (m == null || e == null)
            const Text(
              'Location not available for this machine.',
              style: TextStyle(fontSize: 13, color: kOwnerMuted),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 170,
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCameraFit: CameraFit.bounds(
                          bounds: LatLngBounds(m, e),
                          padding: const EdgeInsets.fromLTRB(44, 44, 44, 60),
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
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [m, e],
                              color: kOwnerGreen.withValues(alpha: 0.7),
                              strokeWidth: 3,
                              pattern: const StrokePattern.dotted(),
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: m,
                              width: 36,
                              height: 36,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: kOwnerGreen,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.agriculture,
                                  size: 19,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Marker(
                              point: e,
                              width: 40,
                              height: 40,
                              alignment: Alignment.topCenter,
                              child: const Icon(
                                Icons.location_on,
                                size: 38,
                                color: kOwnerRed,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Color(0x33000000), blurRadius: 4),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 9,
                              color: kOwnerGreen,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Based at ${b.provider}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: kOwnerInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 16, color: kOwnerMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  b.isCompleted
                      ? 'This job was completed and signed off.'
                      : 'The machine is moved to your estate for the booked date.',
                  style: const TextStyle(fontSize: 12.5, color: kOwnerMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _specs(MachineBooking b) {
    Widget row(IconData icon, String label, Widget value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: kOwnerInk),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: kOwnerMuted),
            ),
          ),
          Expanded(child: value),
        ],
      ),
    );
    Widget text(String t) => Text(
      t,
      textAlign: TextAlign.right,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: kOwnerInk,
      ),
    );

    return OwnerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Job Specifications',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: kOwnerInk,
            ),
          ),
          const SizedBox(height: 6),
          row(Icons.home_work_outlined, 'Estate', text(b.estate)),
          row(Icons.calendar_today_outlined, 'Date', text(fullDate(b.date))),
          row(Icons.schedule, 'Start time', text(b.time)),
          row(
            Icons.build_outlined,
            b.items.length == 1 ? 'Service' : 'Services',
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final i in b.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: kOwnerPanel,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${i.name} · ${i.qtyLabel}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: kOwnerInk,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F0EC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Agreed Total',
                        style: TextStyle(fontSize: 13, color: kOwnerMuted),
                      ),
                      Text(
                        'Pay on job completion',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kOwnerGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      rupees(b.total),
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: kOwnerGreen,
                      ),
                    ),
                    Text(
                      b.total < b.listTotal
                          ? 'List price ${rupees(b.listTotal)}'
                          : b.scope,
                      style: const TextStyle(fontSize: 12, color: kOwnerMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The saved negotiation chat for a booking. New messages are kept with the
/// booking; the provider's replies are simulated for the demo.
class MachineryChatPage extends StatefulWidget {
  final MachineBooking booking;

  const MachineryChatPage({super.key, required this.booking});

  @override
  State<MachineryChatPage> createState() => _MachineryChatPageState();
}

class _MachineryChatPageState extends State<MachineryChatPage> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _send() {
    final String t = _text.text.trim();
    if (t.isEmpty) return;
    _text.clear();
    final MachineBooking b = widget.booking;
    setState(() => b.chat.add(ChatLine(true, t)));
    _toBottom();
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(
        () => b.chat.add(
          ChatLine(
            false,
            'Noted! See you on ${fullDate(b.date)} at ${b.time}.',
          ),
        ),
      );
      _toBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    final MachineBooking b = widget.booking;
    return OwnerPage(
      bottom: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: kOwnerBorder)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _text,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  filled: true,
                  fillColor: kOwnerPanel,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 22,
              backgroundColor: kOwnerGreen,
              child: IconButton(
                onPressed: _send,
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
      child: Column(
        children: [
          OwnerHeader(title: b.provider, subtitle: 'BOOKING ${b.id}'),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [for (final m in b.chat) chatBubble(m)],
            ),
          ),
        ],
      ),
    );
  }
}
