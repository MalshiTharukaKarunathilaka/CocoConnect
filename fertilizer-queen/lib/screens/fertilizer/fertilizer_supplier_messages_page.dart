import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'fertilizer_data.dart';

/// Supplier inbox: one thread per estate owner who messaged this shop.
class FertilizerSupplierMessagesPage extends StatefulWidget {
  const FertilizerSupplierMessagesPage({
    super.key,
    this.focusOwner,
    this.onUnreadChanged,
  });

  final String? focusOwner;
  /// Why: parent hub refreshes the Messages tab badge when unread drops.
  final VoidCallback? onUnreadChanged;

  @override
  State<FertilizerSupplierMessagesPage> createState() =>
      _FertilizerSupplierMessagesPageState();
}

class _FertilizerSupplierMessagesPageState
    extends State<FertilizerSupplierMessagesPage> {
  final _store = FertilizerStore.instance;
  String? _openOwner;
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.focusOwner != null && widget.focusOwner!.isNotEmpty) {
      _openOwner = widget.focusOwner;
      _store.markShopTalkRead(_store.agentShopId, owner: widget.focusOwner);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onUnreadChanged?.call();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  FertPlace get _shop => _store.myShop;

  List<FertSupplierThread> get _threads =>
      _store.supplierMessageThreads(_shop.id);

  /// Why: supplier should see who is asking (estate + owner name when known).
  String _ownerLabel(String estate) {
    for (final p in FertilizerStore.demoOwnerProfiles.values) {
      if (p.estateName == estate) {
        return '${p.fullName} · estate owner';
      }
    }
    return 'Estate owner · negotiation';
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

  void _open(FertSupplierThread t) {
    setState(() {
      _openOwner = t.owner;
      _store.markShopTalkRead(_shop.id, owner: t.owner);
    });
    widget.onUnreadChanged?.call();
    _toEnd();
  }

  void _send() {
    final owner = _openOwner;
    if (owner == null) return;
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _store.sendShopChat(
      _shop.id,
      from: _shop.company,
      text: text,
      fromOwner: false,
      ownerKey: owner,
    );
    _ctrl.clear();
    setState(() {});
    _toEnd();
  }

  @override
  Widget build(BuildContext context) {
    if (_openOwner != null) return _chat(_openOwner!);
    return _inbox();
  }

  Widget _inbox() {
    final threads = _threads;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        const Text(
          'Messages',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Negotiation chats from estate owners. Tap a thread to reply.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        if (threads.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: const Text(
              'No messages yet. When an estate owner chats from the map, it shows here.',
              style: TextStyle(color: AppColors.muted),
            ),
          )
        else
          for (final t in threads)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _open(t),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.greenSoft,
                          child: Text(
                            t.owner.isEmpty ? '?' : t.owner[0].toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.green,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.owner,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _ownerLabel(t.owner),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.muted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t.preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (t.unread > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.dangerText,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '${t.unread}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )
                        else
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.muted,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Widget _chat(String owner) {
    final msgs = _store.shopMessages(_shop.id);
    return Column(
      children: [
        Material(
          color: Colors.white,
          child: ListTile(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _openOwner = null),
            ),
            title: Text(
              owner,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(_ownerLabel(owner)),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: msgs.isEmpty
              ? const Center(
                  child: Text(
                    'No messages in this thread yet.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[i];
                    final mine = m.from == _shop.company || m.from == _shop.who;
                    final fromLabel = mine
                        ? 'You'
                        : (m.from == 'You' ? owner : m.from);
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
                              fromLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
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
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  decoration: const InputDecoration(
                    hintText: 'Reply to the estate owner…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _send,
                child: const Text('Send'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
