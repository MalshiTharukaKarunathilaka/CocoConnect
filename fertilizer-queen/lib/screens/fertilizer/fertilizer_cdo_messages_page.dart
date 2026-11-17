import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_cancel_reasons.dart';
import 'fertilizer_data.dart';

/// CDO ↔ estate chat threads (mobile width). Delivery date/time shown in chat.
class FertilizerCdoMessagesPage extends StatefulWidget {
  const FertilizerCdoMessagesPage({super.key});

  @override
  State<FertilizerCdoMessagesPage> createState() =>
      _FertilizerCdoMessagesPageState();
}

class _FertilizerCdoMessagesPageState extends State<FertilizerCdoMessagesPage> {
  final _store = FertilizerStore.instance;
  FertGovRequest? _open;
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<FertGovRequest> get _threads {
    final list = _store.myCdoRequests.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
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

  void _send() {
    final r = _open;
    if (r == null) return;
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _store.sendGovChat(r.id, from: r.cdo, text: text);
    _ctrl.clear();
    setState(() {});
    _toEnd();
  }

  String _deliveryLabel(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final am = d.hour >= 12 ? 'PM' : 'AM';
    return '${shortDate(d)} · $h:$m $am';
  }

  @override
  Widget build(BuildContext context) {
    if (_open != null) return _chat(_open!);
    return _inbox();
  }

  Widget _inbox() {
    final threads = _threads;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        const Text(
          'Messages',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Chat with estates about applications and delivery date / time.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        if (threads.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: const Text(
              'No chats yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          )
        else
          for (final r in threads) ...[
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() => _open = r);
                  _toEnd();
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.greenSoft,
                        child: Text(
                          () {
                            final n = r.estateName.isNotEmpty
                                ? r.estateName
                                : r.owner;
                            return n.isEmpty ? '?' : n[0].toUpperCase();
                          }(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.green,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.estateName.isNotEmpty ? r.estateName : r.owner,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              r.chat.isEmpty
                                  ? '${r.id} · ${r.fertilizer}'
                                  : r.chat.last.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.muted,
                              ),
                            ),
                            if (r.deliveryAt != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Delivery ${_deliveryLabel(r.deliveryAt!)}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.info,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      StatusPill.forStatus(r.status),
                    ],
                  ),
                ),
              ),
            ),
            if (r.status == 'Accepted' || r.status == 'Receipt Confirmed') ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.dangerText,
                    backgroundColor: AppColors.dangerSoft,
                  ),
                  onPressed: () async {
                    final note = await showFertCdoDisputeReasons(
                      context,
                      title: 'Dispute ${r.id}',
                    );
                    if (note == null) return;
                    _store.disputeGovRequest(r.id, reason: note);
                    setState(() {});
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${r.id} disputed')),
                    );
                  },
                  child: const Text('Dispute'),
                ),
              ),
            ],
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _chat(FertGovRequest r) {
    final estate = r.estateName.isNotEmpty ? r.estateName : r.owner;
    final cdoName = r.cdo;
    final canDispute =
        r.status == 'Accepted' || r.status == 'Receipt Confirmed';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _open = null),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      estate,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.green,
                      ),
                    ),
                    Text(
                      '${r.id} · ${r.fertilizer}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (canDispute)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.dangerText,
                  ),
                  onPressed: () async {
                    final note = await showFertCdoDisputeReasons(
                      context,
                      title: 'Dispute ${r.id}',
                    );
                    if (note == null) return;
                    _store.disputeGovRequest(r.id, reason: note);
                    setState(() => _open = null);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${r.id} disputed')),
                    );
                  },
                  child: const Text('Dispute'),
                ),
            ],
          ),
        ),
        if (r.deliveryAt != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.infoSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_available, size: 18, color: AppColors.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Delivery date & time · ${_deliveryLabel(r.deliveryAt!)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.info,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            children: [
              if (r.chat.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No messages yet. Say hello to the estate.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              else
                for (final m in r.chat) ...[
                  _bubble(
                    m,
                    mine: m.from == cdoName || m.from.contains('CDO'),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(
            12,
            8,
            12,
            8 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Message the estate…',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _send,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bubble(FertChat m, {required bool mine}) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            color: mine ? AppColors.greenSoft : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
            border: Border.all(
              color: mine ? AppColors.green.withValues(alpha: 0.25) : AppColors.line,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m.from,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: mine ? AppColors.green : AppColors.muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(m.text, style: const TextStyle(fontSize: 13.5, height: 1.3)),
              const SizedBox(height: 4),
              Text(
                m.time,
                style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
