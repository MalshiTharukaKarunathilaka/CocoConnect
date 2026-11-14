import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../theme/app_theme.dart';
import '../../widgets/owner_widgets.dart';
import '../account_dialogs.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_data.dart';

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

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, List<FertOrder>> get _byDate {
    final map = <String, List<FertOrder>>{};
    for (final o in _pending) {
      final k = _key(o.preferredDate);
      map.putIfAbsent(k, () => []).add(o);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pending;
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
                tooltip: 'Availability',
                icon: const Icon(Icons.inventory_2_outlined, color: AppColors.green),
                onPressed: () => _openAvail(
                  DateTime.now().add(const Duration(days: 1)),
                ),
              ),
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
                IconButton(
                  tooltip: 'Availability',
                  icon: const Icon(Icons.inventory_2_outlined, color: AppColors.green),
                  onPressed: () => _openAvail(
                    DateTime.now().add(const Duration(days: 1)),
                  ),
                ),
              ],
            ),
          ),
          if (pending.isNotEmpty)
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
                        '${pending.length} pending acknowledgements',
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
                          final pend = _byDate[key] ?? const <FertOrder>[];
                          return InkWell(
                            onTap: () => _openDay(date, pend),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: pend.isNotEmpty
                                    ? const Color(0xFFFDECEC)
                                    : const Color(0xFFF0F6F1),
                                borderRadius: BorderRadius.circular(14),
                                border: pend.isNotEmpty
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
                                  if (pend.isNotEmpty)
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
                                          '${pend.length}',
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
                const Text(
                  'Needs acknowledgement',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                for (final o in pending) ...[
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
              child: const Text('Open on map'),
            ),
          ),
        ],
      ),
    );
  }

  void _openDay(DateTime date, List<FertOrder> pend) {
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
            const SizedBox(height: 10),
            if (pend.isEmpty)
              const Text(
                'No pending requests on this day.',
                style: TextStyle(color: kOwnerMuted),
              )
            else
              for (final o in pend)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(o.id, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${o.owner} · ${o.product}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openJob(o);
                  },
                ),
            const Divider(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openAvail(date);
                },
                child: const Text('Set availability for this day'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAvail(DateTime date) {
    final key = _key(date);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kOwnerCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final cur = Map<String, FertDayAvail>.from(
          _store.availability[key] ?? {},
        );
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Availability · ${shortDate(date)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: kOwnerGreen,
                    ),
                  ),
                  Text(
                    'Only ${_shop.company} products',
                    style: const TextStyle(fontSize: 12.5, color: kOwnerMuted),
                  ),
                  const SizedBox(height: 10),
                  for (final item in _shop.items) ...[
                    Builder(
                      builder: (_) {
                        final ik = '${_shop.id}::${item.name}';
                        final row = cur[ik] ??
                            FertDayAvail(mode: 'units', qty: item.stock50);
                        cur[ik] = row;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kOwnerBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.name} · 50 kg',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${_shop.company} · sold as ${item.unit} · ${rupees(item.perKg)}/kg',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: kOwnerMuted,
                                ),
                              ),
                              Row(
                                children: [
                                  Radio<String>(
                                    value: 'unlimited',
                                    groupValue: row.mode,
                                    activeColor: kOwnerGreen,
                                    onChanged: (v) => setLocal(() {
                                      row.mode = v!;
                                      row.qty = null;
                                    }),
                                  ),
                                  const Text('Unlimited'),
                                  Radio<String>(
                                    value: 'units',
                                    groupValue: row.mode,
                                    activeColor: kOwnerGreen,
                                    onChanged: (v) => setLocal(() {
                                      row.mode = v!;
                                      row.qty ??= item.stock50;
                                    }),
                                  ),
                                  const Text('Units (50 kg)'),
                                ],
                              ),
                              if (row.mode == 'units')
                                TextFormField(
                                  initialValue: '${row.qty ?? item.stock50}',
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    labelText: 'Number of 50 kg units',
                                  ),
                                  onChanged: (v) =>
                                      row.qty = int.tryParse(v) ?? 0,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kOwnerGreen,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        _store.availability[key] = cur;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Availability saved for $key'),
                          ),
                        );
                        setState(() {});
                      },
                      child: const Text('Save availability'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openJob(FertOrder o) {
    final loc = FertilizerStore.estateGeo[o.owner] ??
        FertilizerStore.estateGeo['Your Estate']!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: const BoxDecoration(
          color: kOwnerCream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
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
              height: 200,
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
                            const Icon(Icons.location_on, color: kOwnerRed, size: 28),
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
                  OwnerPill(o.status, tone: PillTone.neutral),
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
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  Text(o.message, style: const TextStyle(color: kOwnerMuted)),
                  const SizedBox(height: 12),
                  const Text(
                    'Negotiation',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (o.negotiation.isEmpty)
                    const Text(
                      'No negotiation on this order yet.',
                      style: TextStyle(color: kOwnerMuted),
                    )
                  else
                    for (final m in o.negotiation)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          m.from,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        subtitle: Text(m.text),
                        trailing: Text(
                          m.time,
                          style: const TextStyle(fontSize: 11, color: kOwnerMuted),
                        ),
                      ),
                  const SizedBox(height: 12),
                  if (o.status == 'Pending Ack' || o.status == 'Negotiating')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kOwnerGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          _store.acceptOrder(o.id);
                          Navigator.pop(ctx);
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${o.id} accepted')),
                          );
                        },
                        child: const Text('Accept / Ack'),
                      ),
                    ),
                  if (o.status == 'Accepted' || o.status == 'Stock Confirmed')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          _store.markDelivered(o.id);
                          Navigator.pop(ctx);
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${o.id} marked delivered')),
                          );
                        },
                        child: const Text('Mark delivered'),
                      ),
                    ),
                ],
              ),
            ),
          ],
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
