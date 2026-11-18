import 'package:flutter/material.dart';
import '../../widgets/owner_widgets.dart';
import 'fertilizer_data.dart';

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

  List<FertChat> get _msgs => _store.shopMessages(widget.place.id);

  void _send([String? preset]) {
    final text = (preset ?? _ctrl.text).trim();
    if (text.isEmpty) return;
    _store.sendShopChat(
      widget.place.id,
      from: 'You',
      text: text,
      fromOwner: true,
    );
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

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
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
            child: msgs.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No messages yet. Ask about bag colour, phone, price, or delivery.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: kOwnerMuted),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) {
                      final m = msgs[i];
                      final mine = m.from == 'You' ||
                          m.from == _store.boundOwnerKey ||
                          m.from == _store.ownerProfile.fullName;
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
                            color: mine ? kOwnerGreenSoft : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kOwnerBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mine ? 'You' : m.from,
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
