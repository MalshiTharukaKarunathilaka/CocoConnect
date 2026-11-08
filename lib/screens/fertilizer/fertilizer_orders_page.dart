import 'package:flutter/material.dart';
import '../../widgets/owner_widgets.dart';
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

    return OwnerPage(
      child: Column(
        children: [
          const OwnerHeader(
            title: 'My fertilizer orders',
            subtitle: 'PENDING ACK · ACCEPTED · CANCEL',
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
                      style: TextStyle(color: kOwnerMuted),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _card(_list[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tabChip(String code, String label) {
    final on = _tab == code;
    return Expanded(
      child: Material(
        color: on ? kOwnerGreen : Colors.white,
        shape: StadiumBorder(
          side: BorderSide(color: on ? kOwnerGreen : kOwnerBorder),
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
                fontWeight: FontWeight.bold,
                color: on ? Colors.white : kOwnerInk,
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
        border: Border.all(color: kOwnerBorder),
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
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              OwnerPill(
                o.status,
                tone: o.status == 'Accepted' ? PillTone.green : PillTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${o.company} · ${shortDate(o.preferredDate)} · ${o.slot}',
            style: const TextStyle(fontSize: 12.5, color: kOwnerMuted),
          ),
          Text(
            o.items.map((l) => '${l.qty50} × 50 kg ${l.item.name}').join('\n'),
            style: const TextStyle(fontSize: 12.5, color: kOwnerMuted),
          ),
          const SizedBox(height: 6),
          Text(o.message, style: const TextStyle(fontSize: 12.5)),
          const SizedBox(height: 6),
          Text(
            rupees(o.price),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: kOwnerGreen,
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
                style: TextButton.styleFrom(foregroundColor: kOwnerRed),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
