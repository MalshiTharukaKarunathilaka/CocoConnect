import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../theme/app_theme.dart';
import '../../widgets/owner_widgets.dart';
import '../account_dialogs.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_cancel_reasons.dart';
import 'fertilizer_cdo_request_sheet.dart';
import 'fertilizer_data.dart';
import 'fertilizer_dispute_sheet.dart';
import 'fertilizer_supplier_chat_page.dart';
import 'fertilizer_processing_banner.dart';

/// Supplier or CDO calendar — one login = one shop / one CDO desk.
class SupplierCalendarPage extends StatefulWidget {
  const SupplierCalendarPage({
    super.key,
    this.mode = FertHomeMode.supplier,
    this.embedded = false,
  });

  final FertHomeMode mode;
  final bool embedded;

  @override
  State<SupplierCalendarPage> createState() => _SupplierCalendarPageState();
}

class _SupplierCalendarPageState extends State<SupplierCalendarPage> {
  final _store = FertilizerStore.instance;
  DateTime _cursor = DateTime(2026, 11, 1);

  bool get _isCdo => widget.mode == FertHomeMode.cdo;

  FertPlace get _shop => _store.myShop;

  List<FertOrder> get _pending => _store.pendingAck;

  List<FertGovRequest> get _cdoPending => _store.pendingCdoAck;

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// All shop orders by preferred date — so tapping a day can open any order.
  Map<String, List<FertOrder>> get _byDate {
    final map = <String, List<FertOrder>>{};
    for (final o in _store.myShopOrders) {
      final k = _key(o.preferredDate);
      map.putIfAbsent(k, () => []).add(o);
    }
    return map;
  }

  Map<String, List<FertGovRequest>> get _cdoByDate {
    final map = <String, List<FertGovRequest>>{};
    for (final r in _store.myCdoRequests) {
      final k = _key(r.date);
      map.putIfAbsent(k, () => []).add(r);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _isCdo ? _cdoPending.length : _pending.length;
    final daysInMonth = DateTime(_cursor.year, _cursor.month + 1, 0).day;
    final firstWeekday = DateTime(_cursor.year, _cursor.month, 1).weekday % 7;

    final body = Column(
      children: [
        if (!widget.embedded)
          OwnerHeader(
            title: _isCdo ? 'CDO calendar' : 'Supplier calendar',
            subtitle: _shop.company.toUpperCase(),
            showBack: false,
            actions: [
              IconButton(
                tooltip: 'Log out',
                icon: const Icon(Icons.logout, color: AppColors.green),
                onPressed: () => confirmLogOut(context),
              ),
            ],
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isCdo ? 'CDO calendar' : 'Supplier calendar',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (pendingCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF3C1BC)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: kOwnerRed,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '$pendingCount pending acknowledgements',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kOwnerBorder),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => setState(() {
                              _cursor = DateTime(
                                _cursor.year,
                                _cursor.month - 1,
                              );
                            }),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Expanded(
                            child: Text(
                              '${_monthName(_cursor.month)} ${_cursor.year}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() {
                              _cursor = DateTime(
                                _cursor.year,
                                _cursor.month + 1,
                              );
                            }),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          for (final d in ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'])
                            Expanded(
                              child: Text(
                                d,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: kOwnerMuted,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: firstWeekday + daysInMonth,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 5,
                          crossAxisSpacing: 5,
                          childAspectRatio: 1,
                        ),
                        itemBuilder: (_, i) {
                          if (i < firstWeekday) {
                            return const SizedBox.shrink();
                          }
                          final day = i - firstWeekday + 1;
                          final date = DateTime(_cursor.year, _cursor.month, day);
                          final key = _key(date);
                          final count = _isCdo
                              ? (_cdoByDate[key]?.length ?? 0)
                              : (_byDate[key]?.length ?? 0);
                          return InkWell(
                            onTap: () {
                              if (_isCdo) {
                                _openCdoDay(
                                  date,
                                  _cdoByDate[key] ?? const <FertGovRequest>[],
                                );
                              } else {
                                _openDay(
                                  date,
                                  _byDate[key] ?? const <FertOrder>[],
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: count > 0
                                    ? const Color(0xFFFDECEC)
                                    : const Color(0xFFF0F6F1),
                                borderRadius: BorderRadius.circular(14),
                                border: count > 0
                                    ? Border.all(color: kOwnerRed, width: 1.2)
                                    : null,
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: 2,
                                    top: 1,
                                    child: Text(
                                      '$day',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: kOwnerInk,
                                      ),
                                    ),
                                  ),
                                  if (count > 0)
                                    Positioned(
                                      left: 2,
                                      bottom: 0,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        alignment: Alignment.center,
                                        decoration: const BoxDecoration(
                                          color: kOwnerRed,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '$count',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _isCdo
                      ? 'Applications needing acknowledgement'
                      : 'Orders needing acknowledgement',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                if (_isCdo) ...[
                  if (_cdoPending.isEmpty)
                    const Text(
                      'No pending applications. Tap a day to view submitted forms.',
                      style: TextStyle(color: kOwnerMuted, fontSize: 13),
                    )
                  else
                    for (final r in _cdoPending) ...[
                      _cdoPendingCard(r),
                      const SizedBox(height: 8),
                    ],
                ] else if (_pending.isEmpty)
                  const Text(
                    'No pending orders. Tap a calendar day to view scheduled orders.',
                    style: TextStyle(color: kOwnerMuted, fontSize: 13),
                  )
                else
                  for (final o in _pending) ...[
                    _pendingCard(o),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
          ),
        ],
    );

    if (widget.embedded) {
      return ColoredBox(color: AppColors.cream, child: body);
    }
    return OwnerPage(child: body);
  }

  Widget _pendingCard(FertOrder o) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kOwnerBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${o.id} · ${o.product}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              OwnerPill(o.status, tone: PillTone.neutral),
            ],
          ),
          Text(
            '${o.owner} · ${o.qty50} × 50 kg · ${shortDate(o.preferredDate)} · ${o.slot}',
            style: const TextStyle(fontSize: 12.5, color: kOwnerMuted),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kOwnerGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _openJob(o),
              child: const Text('View'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cdoPendingCard(FertGovRequest r) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kOwnerBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${r.id} · ${r.fertilizer}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              OwnerPill(r.status, tone: PillTone.neutral),
            ],
          ),
          Text(
            '${r.owner} · ${r.requested} bags · ${shortDate(r.date)}',
            style: const TextStyle(fontSize: 12.5, color: kOwnerMuted),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kOwnerGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _openCdoForm(r),
              child: const Text('View'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCdoForm(FertGovRequest r) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FertilizerCdoRequestSheet(request: r),
    );
    if (ok == true && mounted) setState(() {});
  }

  void _openCdoDay(DateTime date, List<FertGovRequest> dayRequests) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kOwnerCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              shortDate(date),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: kOwnerGreen,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap to open the estate form. Accept or cancel only.',
              style: TextStyle(fontSize: 12.5, color: kOwnerMuted),
            ),
            const SizedBox(height: 10),
            if (dayRequests.isEmpty)
              const Text(
                'No applications on this day.',
                style: TextStyle(color: kOwnerMuted),
              )
            else
              for (final r in dayRequests)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    r.id,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${r.owner} · ${r.fertilizer} · ${r.status}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openCdoForm(r);
                  },
                ),
          ],
        ),
      ),
    );
  }

  void _openDay(DateTime date, List<FertOrder> dayOrders) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kOwnerCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              shortDate(date),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: kOwnerGreen,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap an order to open full details.',
              style: TextStyle(fontSize: 12.5, color: kOwnerMuted),
            ),
            const SizedBox(height: 10),
            if (dayOrders.isEmpty)
              const Text(
                'No orders on this day.',
                style: TextStyle(color: kOwnerMuted),
              )
            else
              for (final o in dayOrders)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    o.id,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${o.owner} · ${o.product} · ${o.status}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openJob(o);
                  },
                ),
          ],
        ),
      ),
    );
  }

  void _openJob(FertOrder o) {
    final loc = FertilizerStore.estateGeo[o.owner] ??
        FertilizerStore.estateGeo['Your Estate']!;
    final mapH = (MediaQuery.sizeOf(context).height * 0.22).clamp(120.0, 180.0);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 430,
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.9,
          ),
          child: Material(
            color: kOwnerCream,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(22)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          o.id,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: kOwnerGreen,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: mapH,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: loc,
                      initialZoom: 13.5,
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
                            point: loc,
                            width: 120,
                            height: 60,
                            alignment: Alignment.topCenter,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: kOwnerBorder),
                                  ),
                                  child: Text(
                                    o.owner,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.location_on,
                                  color: kOwnerRed,
                                  size: 28,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        '${o.owner} → ${o.company}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${shortDate(o.preferredDate)} · ${o.slot}',
                        style: const TextStyle(color: kOwnerMuted),
                      ),
                      const SizedBox(height: 6),
                      FertOrderStatusDot(status: o.status),
                      const SizedBox(height: 10),
                      for (final line in o.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${line.item.name} · 50 kg\n${line.qty50} units · ${rupees(line.item.price50)} / 50 kg',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Text(
                                rupees(line.lineTotal),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Text(
                        o.message,
                        style: const TextStyle(color: kOwnerMuted),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Negotiation happens in chat — open it to message and Approve.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: kOwnerMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (o.status == 'Pending Ack' ||
                          o.status == 'Negotiating') ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kOwnerGreen,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () {
                                  _store.acceptOrder(o.id);
                                  Navigator.pop(ctx);
                                  setState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${o.id} accepted'),
                                    ),
                                  );
                                },
                                child: const Text('Accept'),
                              ),
                            ),
                            // Why: private suppliers negotiate price; CDO government forms do not.
                            if (!_isCdo) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: kOwnerGreen,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            FertilizerSupplierChatPage(
                                          order: o,
                                        ),
                                      ),
                                    );
                                    if (mounted) setState(() {});
                                  },
                                  child: const Text('Negotiate'),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.dangerText,
                              backgroundColor: AppColors.dangerSoft,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () async {
                              final note = await showFertCancelReasons(
                                context,
                                title: 'Cancel ${o.id}',
                              );
                              if (note == null) return;
                              _store.cancelOrder(
                                o.id,
                                bySupplier: true,
                                note: note,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              setState(() {});
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${o.id} cancelled · estate will see this',
                                  ),
                                ),
                              );
                            },
                            child: const Text('Cancel'),
                          ),
                        ),
                      ],
                      if (o.status == 'Accepted' ||
                          o.status == 'Stock Confirmed') ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.green,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              _store.markDelivered(o.id);
                              Navigator.pop(ctx);
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${o.id} marked delivered'),
                                ),
                              );
                            },
                            child: const Text('Mark delivered'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.dangerText,
                              backgroundColor: AppColors.dangerSoft,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              final ok = await showModalBottomSheet<bool>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => FertilizerDisputeSheet(
                                  order: o,
                                  bySupplier: true,
                                ),
                              );
                              if (ok == true && mounted) setState(() {});
                            },
                            child: const Text('Dispute'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _monthName(int m) => const [
        '',
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ][m];
}
