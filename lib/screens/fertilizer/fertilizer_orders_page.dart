import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_data.dart';

class FertilizerOrdersPage extends StatefulWidget {
  const FertilizerOrdersPage({super.key});

  @override
  State<FertilizerOrdersPage> createState() => _FertilizerOrdersPageState();
}

class _FertilizerOrdersPageState extends State<FertilizerOrdersPage> {
  final _store = FertilizerStore.instance;
  String _tab = 'pending';

  List<FertOrder> get _list {
    final mine = _store.ownerOrders('Your Estate');
    if (_tab == 'pending') {
      return mine
          .where((o) => o.status == 'Pending Ack' || o.status == 'Negotiating')
          .toList();
    }
    if (_tab == 'accepted') {
      return mine.where((o) => o.status == 'Accepted').toList();
    }
    return mine;
  }

  @override
  Widget build(BuildContext context) {
    final mine = _store.ownerOrders('Your Estate');
    final pending = mine
        .where((o) => o.status == 'Pending Ack' || o.status == 'Negotiating')
        .length;
    final accepted = mine.where((o) => o.status == 'Accepted').length;

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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const Expanded(
                          child: Text(
                            'My fertilizer orders',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.green,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: Row(
                      children: [
                        _tabChip('pending', 'Pending ($pending)'),
                        const SizedBox(width: 8),
                        _tabChip('accepted', 'Accepted ($accepted)'),
                        const SizedBox(width: 8),
                        _tabChip('all', 'All (${mine.length})'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _list.isEmpty
                        ? const Center(
                            child: Text(
                              'No orders in this list yet.',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _list.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => _card(_list[i]),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabChip(String code, String label) {
    final on = _tab == code;
    return Expanded(
      child: Material(
        color: on ? AppColors.green : Colors.white,
        shape: StadiumBorder(
          side: BorderSide(color: on ? AppColors.green : AppColors.line),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => setState(() => _tab = code),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: on ? Colors.white : AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(FertOrder o) {
    final canCancel =
        o.status == 'Pending Ack' || o.status == 'Negotiating';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
                  o.id,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              StatusPill.forStatus(o.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${o.company} · ${shortDate(o.preferredDate)} · ${o.slot}',
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
          Text(
            o.items.map((l) => '${l.qty50} × 50 kg ${l.item.name}').join('\n'),
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          Text(o.message, style: const TextStyle(fontSize: 12.5)),
          const SizedBox(height: 6),
          Text(
            rupees(o.price),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.green,
            ),
          ),
          if (canCancel) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  _store.cancelOrder(o.id);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${o.id} cancelled')),
                  );
                },
                style: TextButton.styleFrom(foregroundColor: AppColors.dangerText),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
