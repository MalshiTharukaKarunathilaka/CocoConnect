import 'package:flutter/material.dart';
import '../../widgets/owner_widgets.dart';
import 'fertilizer_data.dart';
import 'fertilizer_order_sheet.dart';

class FertilizerTalkPage extends StatefulWidget {
  const FertilizerTalkPage({super.key, required this.place});
  final FertPlace place;

  @override
  State<FertilizerTalkPage> createState() => _FertilizerTalkPageState();
}

class _FertilizerTalkPageState extends State<FertilizerTalkPage> {
  final _ctrl = TextEditingController();
  final _store = FertilizerStore.instance;

  List<FertChat> get _msgs =>
      List<FertChat>.from(_store.shopTalks[widget.place.id] ?? const []);

  void _send([String? preset]) {
    final text = (preset ?? _ctrl.text).trim();
    if (text.isEmpty) return;
    final list = List<FertChat>.from(_store.shopTalks[widget.place.id] ?? []);
    list.add(FertChat('You', text, TimeOfDay.now().format(context)));
    _store.shopTalks[widget.place.id] = list;
    _ctrl.clear();
    setState(() {});
  }

  Future<void> _placeOrderFromChat() async {
    // Why: after talking price/details, the owner can send the order without leaving chat.
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FertilizerOrderSheet(place: widget.place),
    );
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
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
              padding: const EdgeInsets.all(16),
              itemCount: msgs.length,
              itemBuilder: (_, i) {
                final m = msgs[i];
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
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kOwnerGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _placeOrderFromChat,
                icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                label: const Text(
                  'Place order',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
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
                  'Best price for 10 × 50 kg?',
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
                      hintText: 'Ask about colour, phone, price…',
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
