import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/owner_widgets.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_data.dart';
import 'fertilizer_order_sheet.dart' show FertilizerOrderSheet;

class FertilizerTalkPage extends StatefulWidget {
  const FertilizerTalkPage({super.key, required this.place});
  final FertPlace place;

  @override
  State<FertilizerTalkPage> createState() => _FertilizerTalkPageState();
}

class _FertilizerTalkPageState extends State<FertilizerTalkPage> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _store = FertilizerStore.instance;

  List<FertChat> get _msgs =>
      List<FertChat>.from(_store.shopTalks[widget.place.id] ?? const []);

  /// The owner's latest order with this supplier, if there is one.
  FertOrder? get _order {
    for (final o in _store.myOrders) {
      if (o.placeId == widget.place.id) return o;
    }
    return null;
  }

  bool _open(FertOrder o) =>
      o.status == 'Pending Ack' || o.status == 'Negotiating';

  void _say(String text) {
    final list = List<FertChat>.from(_store.shopTalks[widget.place.id] ?? []);
    list.add(FertChat('You', text, TimeOfDay.now().format(context)));
    _store.shopTalks[widget.place.id] = list;
  }

  void _send([String? preset]) {
    final text = (preset ?? _ctrl.text).trim();
    if (text.isEmpty) return;
    _say(text);
    _ctrl.clear();
    setState(() {});
    _toEnd();
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _approve(FertOrder o) {
    _store.acceptOrder(o.id);
    _say('Approved order ${o.id} at ${rupees(o.price)}.');
    setState(() {});
    _toEnd();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${o.id} approved')),
    );
  }

  void _decline(FertOrder o) {
    _store.cancelOrder(o.id, bySupplier: false, note: 'Declined in chat');
    _say('Declined order ${o.id}.');
    setState(() {});
    _toEnd();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${o.id} declined')),
    );
  }

  Future<void> _orderNow() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FertilizerOrderSheet(place: widget.place),
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The supplier's offer, shown in the chat like a message.
  Widget _offerCard() {
    final FertOrder? o = _order;
    final FertPlace p = widget.place;
    final TextStyle muted = const TextStyle(fontSize: 12.5, color: kOwnerMuted);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDCE8DF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: kOwnerGreenSoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    'OFFER',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: kOwnerGreen,
                    ),
                  ),
                ),
                const Spacer(),
                if (o != null) StatusPill.forStatus(o.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              p.company,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: kOwnerInk,
              ),
            ),
            Text('${p.brandLine} \u00b7 ${p.distanceKm.toStringAsFixed(1)} km', style: muted),
            const Divider(height: 22, color: kOwnerBorder),
            if (o != null) ...[
              Text(
                '${o.id}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kOwnerMuted,
                ),
              ),
              const SizedBox(height: 4),
              for (final l in o.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${l.qty50} \u00d7 ${l.item.name} (50 kg)',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: kOwnerInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                'Preferred ${shortDate(o.preferredDate)} \u00b7 ${o.slot}',
                style: muted,
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: kOwnerGreenSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Order total',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kOwnerInk,
                      ),
                    ),
                    Text(
                      rupees(o.price),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kOwnerGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              for (final it in p.items.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          it.name,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: kOwnerInk,
                          ),
                        ),
                      ),
                      Text(
                        '${rupees(it.price)} / ${it.unit}',
                        style: muted,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  text: 'From ${rupees(p.minPrice50)}',
                  children: const [
                    TextSpan(
                      text: ' / 50 kg',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                        color: kOwnerMuted,
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kOwnerGreen,
                ),
              ),
            ],
            if (o == null || _open(o)) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kOwnerGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: const StadiumBorder(),
                        minimumSize: const Size(0, 46),
                      ),
                      onPressed: o == null ? _orderNow : () => _approve(o),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Approve order', maxLines: 1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kOwnerRed,
                        side: const BorderSide(color: kOwnerRed),
                        shape: const StadiumBorder(),
                        minimumSize: const Size(0, 46),
                      ),
                      onPressed: o == null
                          ? () {
                              _say('No order for now, thanks.');
                              setState(() {});
                              _toEnd();
                            }
                          : () => _decline(o),
                      child: const Text('Decline'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final msgs = _msgs;
    return OwnerPage(
      child: Column(
        children: [
          OwnerHeader(
            title: 'Negotiation',
            subtitle: widget.place.company.toUpperCase(),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: msgs.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) return _offerCard();
                final m = msgs[i - 1];
                final mine = m.from == 'You';
                return Align(
                  alignment:
                      mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: mine ? kOwnerGreenSoft : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kOwnerBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.from,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: kOwnerGreen,
                          ),
                        ),
                        Text(m.text),
                        Text(
                          m.time,
                          style: const TextStyle(
                            fontSize: 10,
                            color: kOwnerMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Wrap(
              spacing: 6,
              children: [
                for (final q in [
                  'What colour are the bags?',
                  'Phone number?',
                  'Best price for 10 \u00d7 50 kg?',
                ])
                  ActionChip(
                    label: Text(q, style: const TextStyle(fontSize: 11)),
                    onPressed: () => _send(q),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                      hintText: 'Ask about colour, phone, price\u2026',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kOwnerGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _send,
                  child: const Text('Send'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
