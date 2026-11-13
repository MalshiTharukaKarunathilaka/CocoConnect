import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../account_dialogs.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_data.dart';
import 'supplier_calendar_page.dart';

/// Supplier Agent / CDO shell with demo-style bottom tabs.
class ProviderHub extends StatefulWidget {
  const ProviderHub({super.key, required this.mode});

  final FertHomeMode mode;

  @override
  State<ProviderHub> createState() => _ProviderHubState();
}

class _ProviderHubState extends State<ProviderHub> {
  final _store = FertilizerStore.instance;
  int _tab = 0;

  bool get _isCdo => widget.mode == FertHomeMode.cdo;

  FertPlace get _shop => _store.myShop;

  List<FertOrder> get _myOrders => _store.myShopOrders;

  List<FertOrder> get _pending => _store.pendingAck;

  @override
  Widget build(BuildContext context) {
    final tabs = _isCdo
        ? const [
            (Icons.calendar_month, 'Calendar'),
            (Icons.inbox_outlined, 'Pending requests'),
            (Icons.inventory_2_outlined, 'Stock'),
            (Icons.local_shipping_outlined, 'Distribution'),
            (Icons.mail_outline, 'Messages'),
          ]
        : const [
            (Icons.calendar_month, 'Calendar'),
            (Icons.inbox_outlined, 'Pending & jobs'),
            (Icons.inventory_2_outlined, 'Availability'),
            (Icons.radar_outlined, 'Coverage'),
          ];

    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Material(
            color: AppColors.cream,
            child: SafeArea(
              child: Column(
                children: [
                  _topBar(),
                  Expanded(child: _body()),
                  _bottom(tabs),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KapConnect',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.green,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${_isCdo ? 'CDO' : 'Supplier'} · ${_shop.company}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: () => confirmLogOut(context),
            icon: const Icon(Icons.logout, color: AppColors.green),
          ),
        ],
      ),
    );
  }

  Widget _bottom(List<(IconData, String)> tabs) {
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _tab = i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            _tab == i ? AppColors.greenSoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        tabs[i].$1,
                        size: 20,
                        color: _tab == i ? AppColors.green : AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tabs[i].$2,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: _tab == i ? AppColors.green : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_tab == 0) {
      return SupplierCalendarPage(mode: widget.mode, embedded: true);
    }
    if (_isCdo) {
      switch (_tab) {
        case 1:
          return _pendingJobs(cdo: true);
        case 2:
          return _stockPage();
        case 3:
          return _distributionPage();
        case 4:
          return _messagesPage();
      }
    } else {
      switch (_tab) {
        case 1:
          return _pendingJobs(cdo: false);
        case 2:
          return _availabilityHint();
        case 3:
          return _coveragePage();
      }
    }
    return const SizedBox.shrink();
  }

  Widget _pendingJobs({required bool cdo}) {
    final list = _myOrders;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          cdo ? 'Pending requests' : 'Pending & jobs',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          cdo
              ? 'Open a request, then acknowledge. No price negotiation for government.'
              : 'Pending Ack means the estate is waiting for your acceptance.',
          style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        if (_pending.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_pending.length} waiting for your acknowledgement',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.dangerText,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (list.isEmpty)
          const Text('No orders yet.', style: TextStyle(color: AppColors.muted))
        else
          for (final o in list) _orderCard(o),
      ],
    );
  }

  Widget _orderCard(FertOrder o) {
    final canAck =
        o.status == 'Pending Ack' || o.status == 'Negotiating' || o.status == 'Submitted';
    final canDeliver =
        o.status == 'Accepted' || o.status == 'Stock Confirmed';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${o.id} · ${o.product}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              StatusPill.forStatus(o.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${o.owner} · ${o.qty50} × 50 kg · ${rupees(o.price)} · ${shortDate(o.preferredDate)} · ${o.slot}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canAck)
                ElevatedButton(
                  onPressed: () {
                    _store.acceptOrder(o.id);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${o.id} accepted')),
                    );
                  },
                  child: const Text('Accept / Ack'),
                ),
              if (canDeliver)
                ElevatedButton(
                  onPressed: () {
                    _store.markDelivered(o.id);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${o.id} marked delivered')),
                    );
                  },
                  child: const Text('Mark delivered'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _availabilityHint() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Availability',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Upload how many 50 kg units you can supply for a day, or mark unlimited.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Use the calendar',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Open the Calendar tab, tap a day, and set units or unlimited for each product.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => setState(() => _tab = 0),
                child: const Text('Open calendar'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _coveragePage() {
    final p = _shop;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Delivery coverage',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Estates outside your km ring still see you when you are willing to deliver far.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.company,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              Text(
                '${p.who} · ${p.phone}',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              Text(
                '${p.distanceKm} km from demo estate · '
                '${p.physical ? 'Physical shop' : 'No shop · delivers'} · '
                'Brands: ${p.brandLine}',
              ),
              if (p.willingFar) ...[
                const SizedBox(height: 8),
                const StatusPill(
                  'Willing to deliver far',
                  fg: AppColors.info,
                  bg: AppColors.infoSoft,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _stockPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Availability / stock',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Area stock summary for the government programme (sample data).',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        for (final s in _store.areaStock)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s['area']}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${s['district']} · ${s['product']}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 6),
                Text(
                  '${s['bags']} bags listed · ${s['allocated']} allocated · '
                  '${(s['bags'] as int) - (s['allocated'] as int)} balance',
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          'Estates eligible for fertilizer',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final e in FertilizerStore.eligibleEstates)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(e.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${e.$2} · ${e.$3}'),
            trailing: StatusPill(
              e.$4 ? 'Eligible' : 'Outside area',
              fg: e.$4 ? AppColors.green : AppColors.dangerText,
              bg: e.$4 ? AppColors.greenSoft : AppColors.dangerSoft,
            ),
          ),
      ],
    );
  }

  Widget _distributionPage() {
    final done = _myOrders
        .where(
          (o) =>
              o.status == 'Accepted' ||
              o.status == 'Distributed' ||
              o.status == 'Receipt Confirmed',
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Distribution records',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Record the quantity handed over after acceptance.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        if (done.isEmpty)
          const Text('No distribution records yet.', style: TextStyle(color: AppColors.muted))
        else
          for (final o in done) _orderCard(o),
      ],
    );
  }

  Widget _messagesPage() {
    final gov = _store.govRequests;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Messages',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Request conversations for audit (demo list).',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        for (final r in gov)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r.id} · ${r.owner}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${r.requested} bags · ${r.status}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusPill.forStatus(r.status),
              ],
            ),
          ),
      ],
    );
  }
}
