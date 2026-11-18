import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/owner_widgets.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_data.dart';

/// Supplier ↔ land chat for one order. Approve from inside this chat.
class FertilizerSupplierChatPage extends StatefulWidget {
  const FertilizerSupplierChatPage({super.key, required this.order});

  final FertOrder order;

  @override
  State<FertilizerSupplierChatPage> createState() =>
      _FertilizerSupplierChatPageState();
}

class _FertilizerSupplierChatPageState
    extends State<FertilizerSupplierChatPage> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _store = FertilizerStore.instance;

  FertOrder get o => widget.order;

  bool get _canAct => o.status == 'Pending Ack' || o.status == 'Negotiating';

  @override
  void initState() {
    super.initState();
    // Open negotiation so the land card updates.
    if (o.status == 'Pending Ack') {
      _store.startNegotiation(
        o.id,
        note: 'Supplier opened chat to negotiate ${o.id}.',
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
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

  void _send([String? preset]) {
    final text = (preset ?? _ctrl.text).trim();
    if (text.isEmpty) return;
    o.negotiation.add(FertChat(o.agent, text, TimeOfDay.now().format(context)));
    if (o.status == 'Pending Ack') {
      o.status = 'Negotiating';
    }
    o.message = text;
    _store.notifyOwner(
      title: '${o.company} sent a message',
      body: '${o.id} · $text',
      kind: 'negotiating',
      orderId: o.id,
    );
    _ctrl.clear();
    setState(() {});
    _toEnd();
  }

  void _approve() {
    _store.acceptOrder(o.id);
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${o.id} approved')));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final msgs = o.negotiation;
    return OwnerPage(
      child: Column(
        children: [
          OwnerHeader(
            title: 'Order chat',
            subtitle: '${o.id} · ${o.owner}'.toUpperCase(),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.product,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  '${o.qty50} bags · ${rupees(o.price)} · ${shortDate(o.preferredDate)} · ${o.slot}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 6),
                StatusPill.forStatus(
                  o.status == 'Pending Ack' ? 'Pending' : o.status,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(14),
              itemCount: msgs.isEmpty ? 1 : msgs.length,
              itemBuilder: (_, i) {
                if (msgs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Text(
                      'Send a message to negotiate bags, date or price. You can Approve when ready.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                  );
                }
                final m = msgs[i];
                final mine = m.from == o.agent;
                return Align(
                  alignment: mine
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: mine ? AppColors.greenSoft : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.from,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.green,
                          ),
                        ),
                        Text(m.text),
                        Text(
                          m.time,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_canAct)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _approve,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Approve order'),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Wrap(
              spacing: 6,
              children: [
                for (final q in [
                  'Can do morning only',
                  'Stock for 8 bags',
                  'Need one more day',
                ])
                  ActionChip(
                    label: Text(q, style: const TextStyle(fontSize: 11)),
                    onPressed: _canAct ? () => _send(q) : null,
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
                    enabled: _canAct,
                    decoration: const InputDecoration(
                      hintText: 'Message the land…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _canAct ? _send : null,
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
