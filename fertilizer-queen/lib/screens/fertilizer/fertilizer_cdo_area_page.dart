import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_cdo_request_sheet.dart';
import 'fertilizer_data.dart';

/// CDO Area tab — stays inside the phone frame (no full-width web route).
class FertilizerCdoAreaPage extends StatefulWidget {
  const FertilizerCdoAreaPage({super.key});

  @override
  State<FertilizerCdoAreaPage> createState() => _FertilizerCdoAreaPageState();
}

class _FertilizerCdoAreaPageState extends State<FertilizerCdoAreaPage> {
  final _store = FertilizerStore.instance;
  FertCdoArea? _area;
  FertCdoEstate? _estate;
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    if (_estate != null && _area != null) {
      return _estateHistory(_area!, _estate!);
    }
    if (_area != null) return _estatesList(_area!);
    return _areasHome();
  }

  Widget _areasHome() {
    final areas = _store.areasForMyCdo();
    final who = _store.myShop.who;
    var estateCount = 0;
    var requestCount = 0;
    var bagsOut = 0;
    for (final a in areas) {
      estateCount += a.estates.length;
      for (final e in a.estates) {
        final s = _store.statsForEstate(e.name);
        requestCount += s.totalRequests;
        bagsOut += s.bagsDistributed;
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        _hero(
          title: 'Area',
          subtitle: '$who · estates and fertilizer progress under your desk',
          stats: [
            ('$estateCount', 'Estates'),
            ('${areas.length}', 'Areas'),
            ('$requestCount', 'Requests'),
            ('$bagsOut', 'Bags out'),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'Your areas',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tap an area to open the estates registered there.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        if (areas.isEmpty)
          _emptyBox('No areas linked to this CDO desk yet.')
        else
          for (final area in areas) ...[
            _areaCard(area),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Widget _estatesList(FertCdoArea area) {
    return Column(
      children: [
        _subHeader(
          title: area.name,
          subtitle: '${area.town} · ${area.district} · ${area.estates.length} estates',
          onBack: () => setState(() {
            _area = null;
            _estate = null;
          }),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _softBanner(
                Icons.map_outlined,
                'Estates in this area',
                'Open View for request history, pending work and bags already handed over.',
              ),
              const SizedBox(height: 14),
              for (final estate in area.estates) ...[
                _estateCard(area, estate),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _estateHistory(FertCdoArea area, FertCdoEstate estate) {
    final all = _store.requestsForEstate(estate.name);
    final stats = _store.statsForEstate(estate.name);
    final list = all.where((r) {
      switch (_filter) {
        case 'pending':
          return r.status == 'Pending Ack' ||
              r.status == 'Submitted' ||
              r.status == 'Negotiation';
        case 'accepted':
          return r.status == 'Accepted';
        case 'completed':
          return r.status == 'Distributed' || r.status == 'Receipt Confirmed';
        case 'cancelled':
          return r.status == 'Cancelled' || r.status == 'Rejected';
        default:
          return true;
      }
    }).toList();

    return Column(
      children: [
        _subHeader(
          title: estate.name,
          subtitle: '${area.town} · ${estate.acresLabel} · ${estate.ownerName}',
          onBack: () => setState(() {
            _estate = null;
            _filter = 'all';
          }),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _estateProfile(estate, stats),
              const SizedBox(height: 14),
              const Text(
                'Requests & progress',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final e in [
                      ('all', 'All (${stats.totalRequests})'),
                      ('pending', 'Pending (${stats.pending})'),
                      ('accepted', 'Accepted (${stats.accepted})'),
                      ('completed', 'Completed (${stats.completed})'),
                      ('cancelled', 'Cancelled (${stats.cancelled})'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(e.$2, style: const TextStyle(fontSize: 12)),
                          selected: _filter == e.$1,
                          onSelected: (_) => setState(() => _filter = e.$1),
                          selectedColor: AppColors.greenSoft,
                          checkmarkColor: AppColors.green,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (all.isEmpty)
                _emptyOrders()
              else if (list.isEmpty)
                _emptyBox('No requests in this filter.')
              else
                for (final r in list) ...[
                  _requestCard(r),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _areaCard(FertCdoArea area) {
    var requests = 0;
    var bags = 0;
    var pending = 0;
    for (final e in area.estates) {
      final s = _store.statsForEstate(e.name);
      requests += s.totalRequests;
      bags += s.bagsDistributed;
      pending += s.pending;
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() {
          _area = area;
          _estate = null;
        }),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.line),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFF7FBF7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.greenSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.location_on_outlined,
                        color: AppColors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            area.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                            ),
                          ),
                          Text(
                            '${area.town} · ${area.district}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _miniStat('${area.estates.length}', 'Estates'),
                    _miniStat('$requests', 'Requests'),
                    _miniStat('$pending', 'Pending'),
                    _miniStat('$bags', 'Bags out'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _estateCard(FertCdoArea area, FertCdoEstate estate) {
    final stats = _store.statsForEstate(estate.name);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.infoSoft,
                child: Text(
                  estate.name[0].toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.info,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      estate.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${estate.ownerName} · ${estate.acresLabel}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => setState(() {
                  _area = area;
                  _estate = estate;
                  _filter = 'all';
                }),
                child: const Text('View'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (stats.totalRequests == 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F1EA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'No orders are made yet.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill(
                  '${stats.totalRequests} requests',
                  AppColors.info,
                  AppColors.infoSoft,
                ),
                _pill(
                  '${stats.bagsDistributed} bags distributed',
                  AppColors.green,
                  AppColors.greenSoft,
                ),
                if (stats.pending > 0)
                  _pill(
                    '${stats.pending} pending',
                    AppColors.warning,
                    AppColors.warningSoft,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _requestCard(FertGovRequest r) {
    final progress = switch (r.status) {
      'Pending Ack' || 'Submitted' || 'Negotiation' => 0.25,
      'Accepted' => 0.55,
      'Distributed' => 0.85,
      'Receipt Confirmed' => 1.0,
      'Cancelled' || 'Rejected' => 1.0,
      _ => 0.4,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${r.id} · ${r.fertilizer}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
              StatusPill.forStatus(r.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${r.requested} bags'
            '${r.distributed > 0 ? ' · ${r.distributed} out' : ''}'
            ' · ${shortDate(r.date)}',
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppColors.line,
              color: r.status == 'Cancelled'
                  ? AppColors.danger
                  : AppColors.green,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => FertilizerCdoRequestSheet(request: r),
                );
                if (mounted) setState(() {});
              },
              child: const Text('View form'),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _hero({
  required String title,
  required String subtitle,
  required List<(String, String)> stats,
}) {
  return Container(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        colors: [Color(0xFF1B5E3A), Color(0xFF2E7D4F), Color(0xFF3D8B63)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0)
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      stats[i].$1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      stats[i].$2,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

Widget _subHeader({
  required String title,
  required String subtitle,
  required VoidCallback onBack,
}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
    child: Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.green,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _estateProfile(FertCdoEstate estate, FertEstateOrderStats stats) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        colors: [Color(0xFF244C3A), Color(0xFF3A6B52)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          estate.ownerName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        Text(
          '${estate.phone} · ${estate.acresLabel}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final e in [
              ('${stats.totalRequests}', 'Requests'),
              ('${stats.bagsDistributed}', 'Bags out'),
              ('${stats.pending}', 'Pending'),
              ('${stats.completed}', 'Done'),
            ])
              Expanded(
                child: Column(
                  children: [
                    Text(
                      e.$1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      e.$2,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

Widget _softBanner(IconData icon, String title, String body) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.infoSoft,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppColors.info),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.info,
                ),
              ),
              Text(
                body,
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _miniStat(String value, String label) {
  return Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: AppColors.green,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
        ),
      ],
    ),
  );
}

Widget _pill(String text, Color fg, Color bg) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: fg),
    ),
  );
}

Widget _emptyBox(String text) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.line),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.muted),
    ),
  );
}

Widget _emptyOrders() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.line),
    ),
    child: const Column(
      children: [
        Icon(Icons.inbox_outlined, size: 42, color: AppColors.muted),
        SizedBox(height: 10),
        Text(
          'No orders are made yet.',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        SizedBox(height: 4),
        Text(
          'When this estate submits a government fertilizer form, it will show here with progress.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.35),
        ),
      ],
    ),
  );
}
