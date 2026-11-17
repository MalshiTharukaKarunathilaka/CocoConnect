import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../account_dialogs.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_data.dart';

/// Full **web** console for Regional Manager / Chairman (not phone width).
/// Matches the HTML demo: sidebar + KPI cards + board map + tables.
class FertilizerOversightPage extends StatefulWidget {
  const FertilizerOversightPage({super.key});

  @override
  State<FertilizerOversightPage> createState() =>
      _FertilizerOversightPageState();
}

class _FertilizerOversightPageState extends State<FertilizerOversightPage> {
  final _store = FertilizerStore.instance;
  int _nav = 0;
  String? _selectedDistrict;

  bool get _isChairman => AuthService.currentUser?.role == 'CHAIRMAN';

  List<({IconData icon, String label})> get _tabs => _isChairman
      ? [
          (icon: Icons.dashboard_outlined, label: 'Board overview'),
          (icon: Icons.map_outlined, label: 'Island map'),
          (icon: Icons.list_alt_outlined, label: 'All requests'),
          (icon: Icons.flag_outlined, label: 'Quality complaints'),
          (icon: Icons.assessment_outlined, label: 'Reports & audit'),
        ]
      : [
          (icon: Icons.dashboard_outlined, label: 'Regional overview'),
          (icon: Icons.list_alt_outlined, label: 'Request monitoring'),
          (icon: Icons.local_shipping_outlined, label: 'Distribution monitoring'),
          (icon: Icons.flag_outlined, label: 'Quality complaints'),
        ];

  List<FertGovRequest> get _gov {
    final all = _store.govRequests;
    if (_isChairman) return all;
    return all
        .where((r) => FertilizerStore.managerDistricts.contains(r.district))
        .toList();
  }

  List<FertComplaint> get _complaints {
    final all = _store.complaints;
    if (_isChairman) return all;
    return all
        .where((c) => FertilizerStore.managerDistricts.contains(c.district))
        .toList();
  }

  List<FertOrder> get _privateOrders => _store.orders;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: AppColors.page,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide) _sidebar() else const SizedBox.shrink(),
          Expanded(
            child: Column(
              children: [
                _topBar(showMenu: !wide),
                Expanded(
                  child: ColoredBox(
                    color: AppColors.page,
                    child: _body(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: wide
          ? null
          : Drawer(
              child: SafeArea(child: _sidebar(drawer: true)),
            ),
    );
  }

  Widget _sidebar({bool drawer = false}) {
    final user = AuthService.currentUser;
    return Container(
      width: drawer ? null : 248,
      decoration: BoxDecoration(
        color: Colors.white,
        border: drawer
            ? null
            : const Border(right: BorderSide(color: AppColors.line)),
        boxShadow: drawer ? null : AppShadows.card,
      ),
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text('🌴', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KapConnect',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Estate services',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            _isChairman ? 'BOARD ADMIN' : 'REGIONAL MANAGER',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            user?.name ?? '',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < _tabs.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Material(
                color: _nav == i ? AppColors.greenSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    setState(() => _nav = i);
                    if (drawer) Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _tabs[i].icon,
                          size: 18,
                          color: _nav == i ? AppColors.green : AppColors.muted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _tabs[i].label,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color:
                                  _nav == i ? AppColors.green : AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Text(
              _isChairman
                  ? 'Board view watches island-wide fertilizer activity. Sample data.'
                  : 'Scoped to Northern Region: Jaffna, Mannar, Mullaitivu.',
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar({required bool showMenu}) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          if (showMenu)
            Builder(
              builder: (ctx) => IconButton(
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                icon: const Icon(Icons.menu),
              ),
            ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'KapConnect',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.green,
                    fontSize: 15,
                  ),
                ),
                Text(
                  _tabs[_nav.clamp(0, _tabs.length - 1)].label,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Text(
              '● Demo environment',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.green,
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Log out / switch role',
            onPressed: () => confirmLogOut(context),
            icon: const Icon(Icons.logout, color: AppColors.green),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_isChairman) {
      switch (_nav) {
        case 0:
          return _chairmanDashboard();
        case 1:
          return _mapPage(scopeNorth: false);
        case 2:
          return _requestsPage();
        case 3:
          return _complaintsPage();
        case 4:
          return _reportsPage();
      }
    } else {
      switch (_nav) {
        case 0:
          return _managerDashboard();
        case 1:
          return _requestsPage();
        case 2:
          return _distributionPage();
        case 3:
          return _complaintsPage();
      }
    }
    return const SizedBox.shrink();
  }

  Widget _scroll(List<Widget> children) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
      children: children,
    );
  }

  Widget _pageHead(String kicker, String title, String sub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kicker.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: AppColors.green,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.muted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiRow(List<({String label, String value, String foot, IconData icon})>
      items) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth > 1100 ? 4 : (c.maxWidth > 700 ? 2 : 1);
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 2.4,
          children: [
            for (final i in items)
              Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                  border: Border.all(color: AppColors.line),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            i.label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                        Container(
                          width: 33,
                          height: 33,
                          decoration: BoxDecoration(
                            color: AppColors.greenSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(i.icon, size: 18, color: AppColors.green),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      i.value,
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    Text(
                      i.foot,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _panel(String title, String desc, Widget body) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          body,
        ],
      ),
    );
  }

  Widget _managerDashboard() {
    final mr = _gov;
    final mc = _complaints;
    final pending = mr
        .where(
          (r) =>
              r.status == 'Submitted' ||
              r.status == 'Under Review' ||
              r.status == 'Negotiation' ||
              r.status == 'Pending Ack',
        )
        .length;
    final bags = mr.fold<int>(0, (a, r) => a + r.distributed);
    final openC = mc.where((c) => c.status != 'Resolved').length;

    return _scroll([
      _pageHead(
        'Regional oversight',
        'Northern Region overview',
        'Monitor only the Northern Region and its Jaffna, Mannar and Mullaitivu areas in this demo.',
      ),
      _kpiRow([
        (
          label: 'Regional requests',
          value: '${mr.length}',
          foot: 'Northern Region only',
          icon: Icons.schedule
        ),
        (
          label: 'Pending decisions',
          value: '$pending',
          foot: 'Northern CDO queues',
          icon: Icons.priority_high
        ),
        (
          label: 'Bags distributed',
          value: '$bags',
          foot: 'Demo recorded quantity',
          icon: Icons.check_circle_outline
        ),
        (
          label: 'Open complaints',
          value: '$openC',
          foot: 'Northern Region only',
          icon: Icons.flag_outlined
        ),
      ]),
      const SizedBox(height: 8),
      _boardMap(scopeNorth: true),
      LayoutBuilder(
        builder: (context, c) {
          final sideBySide = c.maxWidth > 900;
          final left = _panel(
            'District snapshot',
            'Northern Region only',
            _districtSummary(mr),
          );
          final right = _panel(
            'Requests requiring follow-up',
            'Northern Region pending and negotiation cases',
            _requestTable(
              mr
                  .where(
                    (r) =>
                        r.status == 'Submitted' ||
                        r.status == 'Under Review' ||
                        r.status == 'Negotiation' ||
                        r.status == 'Pending Ack',
                  )
                  .toList(),
            ),
          );
          if (!sideBySide) {
            return Column(children: [left, right]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 14, child: left),
              const SizedBox(width: 16),
              Expanded(flex: 10, child: right),
            ],
          );
        },
      ),
      _panel(
        'Live private shop orders (shared store)',
        'Also syncs with Estate Owner / Supplier Agent logins',
        _privateOrdersTable(_privateOrders.take(8).toList()),
      ),
    ]);
  }

  Widget _chairmanDashboard() {
    final mr = _gov;
    final mc = _complaints;
    final bags = mr.fold<int>(0, (a, r) => a + r.distributed);
    final awaiting = mr.where((r) => r.status == 'Distributed').length;
    final openC = mc.where((c) => c.status != 'Resolved').length;

    return _scroll([
      _pageHead(
        'Board-level overview',
        'Fertilizer distribution dashboard',
        'High-level visibility of stock, requests, distribution and quality issues across demo districts.',
      ),
      _kpiRow([
        (
          label: 'Requests received',
          value: '${mr.length}',
          foot: 'All demo districts',
          icon: Icons.schedule
        ),
        (
          label: 'Bags distributed',
          value: '$bags',
          foot: 'Recorded in sample data',
          icon: Icons.check_circle_outline
        ),
        (
          label: 'Awaiting receipt',
          value: '$awaiting',
          foot: 'Owner confirmation pending',
          icon: Icons.priority_high
        ),
        (
          label: 'Open complaints',
          value: '$openC',
          foot: 'Quality cases',
          icon: Icons.flag_outlined
        ),
      ]),
      const SizedBox(height: 8),
      _boardMap(scopeNorth: false),
      _panel(
        'Latest exceptions',
        'Pending requests and quality issues',
        Column(
          children: [
            for (final r in mr
                .where(
                  (r) =>
                      r.status == 'Negotiation' ||
                      r.status == 'Under Review' ||
                      r.status == 'Submitted' ||
                      r.status == 'Pending Ack',
                )
                .take(4))
              _miniRow(
                '${r.id} · ${r.owner}',
                '${r.district} · ${r.requested} bags requested',
                r.status,
              ),
            for (final c in mc.where((c) => c.status != 'Resolved'))
              _miniRow(
                '${c.id} · Quality complaint',
                '${c.district} · ${c.owner}',
                c.status,
              ),
          ],
        ),
      ),
      _panel(
        'Live private shop orders (shared store)',
        'Same orders Estate Owner and Supplier see',
        _privateOrdersTable(_privateOrders.take(8).toList()),
      ),
    ]);
  }

  Widget _mapPage({required bool scopeNorth}) {
    return _scroll([
      _pageHead(
        'Board map',
        'Where fertilizer is moving',
        'Bigger circles mean more activity. Tap a district to see what was asked for and what was provided.',
      ),
      _boardMap(scopeNorth: scopeNorth),
      if (_selectedDistrict != null)
        _panel(
          _selectedDistrict!,
          'District detail from sample data',
          _districtDetail(_selectedDistrict!),
        ),
    ]);
  }

  Widget _requestsPage() {
    return _scroll([
      _pageHead(
        _isChairman ? 'Board oversight' : 'Oversight',
        _isChairman ? 'All fertilizer requests' : 'Request monitoring',
        _isChairman
            ? 'Review requests grouped by district. Sample data.'
            : 'View requests from your assigned areas only.',
      ),
      _panel(
        _isChairman ? 'Requests by district' : 'Requests by area',
        _isChairman
            ? 'Island-wide demo requests'
            : 'Only Jaffna, Mannar and Mullaitivu',
        _groupedByDistrict(_gov, kind: 'requests'),
      ),
    ]);
  }

  Widget _distributionPage() {
    return _scroll([
      _pageHead(
        'Oversight',
        'Distribution monitoring',
        'View distribution records in the assigned areas only.',
      ),
      _panel(
        'Distribution by area',
        'Select Jaffna, Mannar or Mullaitivu',
        _groupedByDistrict(_gov, kind: 'distribution'),
      ),
    ]);
  }

  Widget _complaintsPage() {
    return _scroll([
      _pageHead(
        _isChairman ? 'Quality management' : 'Oversight',
        'Quality complaints',
        _isChairman
            ? 'Track complaints across demo districts.'
            : 'Review complaints from assigned areas only.',
      ),
      _panel(
        'Complaints by area',
        'Sample data',
        _groupedComplaints(_complaints),
      ),
    ]);
  }

  Widget _reportsPage() {
    final mr = _gov;
    return _scroll([
      _pageHead(
        'Governance',
        'Reports & audit',
        'Distribution reconciliation totals by district. Sample data only.',
      ),
      LayoutBuilder(
        builder: (context, c) {
          final side = c.maxWidth > 900;
          final left = _panel(
            'Distribution reconciliation',
            'Island-wide counts from the shared demo store',
            Column(
              children: [
                _reconRow('Total requested', mr.length, 'requests'),
                _reconRow(
                  'Total approved',
                  mr.where((r) => r.approved > 0).length,
                  'approved',
                ),
                _reconRow(
                  'Total distributed',
                  mr.where((r) => r.distributed > 0).length,
                  'distributed',
                ),
                _reconRow(
                  'Receipt confirmed',
                  mr.where((r) => r.status == 'Receipt Confirmed').length,
                  'confirmed',
                ),
              ],
            ),
          );
          final right = _panel(
            'Audit events to record',
            'Recommended production design',
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• Who created or changed each request and when'),
                Text('• Original requested quantity and each negotiated quantity'),
                Text('• Approver identity, reason and decision timestamp'),
                Text('• Stock received, allocated, distributed and remaining'),
                Text('• Owner receipt confirmation or dispute'),
                Text('• Complaint evidence, assigned officer and resolution'),
              ],
            ),
          );
          if (!side) return Column(children: [left, right]);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 16),
              Expanded(child: right),
            ],
          );
        },
      ),
    ]);
  }

  Widget _reconRow(String label, int n, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '$n $unit',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _boardMap({required bool scopeNorth}) {
    final districts = scopeNorth
        ? FertilizerStore.managerDistricts
        : [
            'Jaffna',
            'Mannar',
            'Mullaitivu',
            'Kurunegala',
            'Puttalam',
            'Gampaha',
          ];
    // Approximate Sri Lanka board positions (percent).
    final spots = <String, Offset>{
      'Jaffna': const Offset(0.37, 0.10),
      'Mannar': const Offset(0.22, 0.28),
      'Mullaitivu': const Offset(0.48, 0.20),
      'Kurunegala': const Offset(0.34, 0.52),
      'Puttalam': const Offset(0.22, 0.44),
      'Gampaha': const Offset(0.28, 0.64),
    };

    return _panel(
      scopeNorth ? 'Northern board map' : 'Island board map',
      'Tap a district bubble · tone shows pressure (demo)',
      AspectRatio(
        aspectRatio: 1.55,
        child: LayoutBuilder(
          builder: (context, c) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE7F2FB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD5E4EF)),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE7F2FB), Color(0xFFD8EADC)],
                ),
              ),
              child: Stack(
                children: [
                  for (final d in districts)
                    if (spots[d] != null)
                      Positioned(
                        left: spots[d]!.dx * c.maxWidth - 36,
                        top: spots[d]!.dy * c.maxHeight - 24,
                        child: _districtBubble(d),
                      ),
                  const Positioned(
                    left: 12,
                    bottom: 12,
                    child: Text(
                      'Sample data · not official CCB boundaries',
                      style: TextStyle(fontSize: 10, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Color _toneFor(String district) {
    final rows = _gov.where((r) => r.district == district);
    final comps = _complaints.where((c) => c.district == district);
    if (comps.any((c) => c.status != 'Resolved') ||
        rows.any((r) => r.status == 'Rejected' || r.status == 'Disputed')) {
      return const Color(0xFFC04439);
    }
    if (rows.any(
      (r) =>
          r.status == 'Under Review' ||
          r.status == 'Submitted' ||
          r.status == 'Pending Ack',
    )) {
      return const Color(0xFFB45309);
    }
    if (rows.any((r) => r.status == 'Negotiation')) {
      return const Color(0xFFD49A14);
    }
    return AppColors.green;
  }

  Widget _districtBubble(String district) {
    final count = _gov.where((r) => r.district == district).length;
    final size = 42.0 + (count * 6).clamp(0, 28);
    final on = _selectedDistrict == district;
    final color = _toneFor(district);
    return GestureDetector(
      onTap: () => setState(() => _selectedDistrict = district),
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: on ? Colors.white70 : const Color(0x44000000),
                  blurRadius: on ? 12 : 8,
                  spreadRadius: on ? 4 : 0,
                ),
              ],
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(99),
              boxShadow: const [
                BoxShadow(color: Color(0x22000000), blurRadius: 6),
              ],
            ),
            child: Text(
              district,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _districtDetail(String district) {
    final rows = _gov.where((r) => r.district == district).toList();
    if (rows.isEmpty) {
      return const Text(
        'No government requests in this district for the sample set.',
        style: TextStyle(color: AppColors.muted),
      );
    }
    return _requestTable(rows);
  }

  Widget _districtSummary(List<FertGovRequest> source) {
    final ds = source.map((r) => r.district).toSet().toList();
    if (ds.isEmpty) {
      return const Text('No district data.', style: TextStyle(color: AppColors.muted));
    }
    return Column(
      children: [
        for (final d in ds)
          Builder(
            builder: (_) {
              final arr = source.where((r) => r.district == d).toList();
              final distributed =
                  arr.fold<int>(0, (a, r) => a + r.distributed);
              final requested = arr.fold<int>(0, (a, r) => a + r.requested);
              final pending = arr
                  .where(
                    (r) =>
                        r.status == 'Submitted' ||
                        r.status == 'Under Review' ||
                        r.status == 'Negotiation' ||
                        r.status == 'Pending Ack',
                  )
                  .length;
              final pct = requested == 0
                  ? 0.0
                  : (distributed / requested).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${arr.length} requests · $distributed bags distributed',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$pending pending',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 8,
                        backgroundColor: AppColors.greenSoft,
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _requestTable(List<FertGovRequest> rows) {
    if (rows.isEmpty) {
      return const Text(
        'No requests in this list.',
        style: TextStyle(color: AppColors.muted),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFFBFDFB)),
        columns: const [
          DataColumn(label: Text('Request / Estate')),
          DataColumn(label: Text('Fertilizer')),
          DataColumn(label: Text('Requested')),
          DataColumn(label: Text('Approved')),
          DataColumn(label: Text('Status')),
        ],
        rows: [
          for (final r in rows)
            DataRow(
              cells: [
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(r.id, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        r.owner,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(Text(r.fertilizer)),
                DataCell(Text('${r.requested} bags')),
                DataCell(Text('${r.approved} bags')),
                DataCell(StatusPill.forStatus(r.status)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _privateOrdersTable(List<FertOrder> rows) {
    if (rows.isEmpty) {
      return const Text('No private orders yet.', style: TextStyle(color: AppColors.muted));
    }
    return Column(
      children: [
        for (final o in rows)
          _miniRow(
            '${o.id} · ${o.owner}',
            '${o.company} · ${rupees(o.price)}',
            o.status,
          ),
      ],
    );
  }

  Widget _groupedByDistrict(
    List<FertGovRequest> source, {
    required String kind,
  }) {
    final districts = _isChairman
        ? source.map((r) => r.district).toSet().toList()
        : FertilizerStore.managerDistricts;
    return Column(
      children: [
        for (final d in districts)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              '$d Area',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${source.where((r) => r.district == d).length} records',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            children: [
              kind == 'distribution'
                  ? _distributionTable(
                      source.where((r) => r.district == d).toList(),
                    )
                  : _requestTable(
                      source.where((r) => r.district == d).toList(),
                    ),
            ],
          ),
      ],
    );
  }

  Widget _distributionTable(List<FertGovRequest> rows) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('No distribution records.', style: TextStyle(color: AppColors.muted)),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Request / Estate')),
          DataColumn(label: Text('Approved')),
          DataColumn(label: Text('Distributed')),
          DataColumn(label: Text('Receipt')),
          DataColumn(label: Text('Status')),
        ],
        rows: [
          for (final r in rows)
            DataRow(
              cells: [
                DataCell(Text('${r.id}\n${r.owner}')),
                DataCell(Text('${r.approved}')),
                DataCell(Text('${r.distributed}')),
                DataCell(
                  Text(
                    r.status == 'Receipt Confirmed'
                        ? 'Confirmed'
                        : r.status == 'Distributed'
                            ? 'Awaiting'
                            : '—',
                  ),
                ),
                DataCell(StatusPill.forStatus(r.status)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _groupedComplaints(List<FertComplaint> source) {
    final districts = _isChairman
        ? source.map((c) => c.district).toSet().toList()
        : FertilizerStore.managerDistricts;
    return Column(
      children: [
        for (final d in districts)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              '$d Area',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${source.where((c) => c.district == d).length} complaints',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            children: [
              for (final c in source.where((c) => c.district == d))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${c.id} · ${c.category}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('${c.owner} · ${c.product} · ${shortDate(c.date)}'),
                  trailing: StatusPill.forStatus(c.status),
                ),
              if (source.where((c) => c.district == d).isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'No complaints in this area.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _miniRow(String title, String sub, String status) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEDF2EE))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  sub,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          StatusPill.forStatus(status),
        ],
      ),
    );
  }
}
