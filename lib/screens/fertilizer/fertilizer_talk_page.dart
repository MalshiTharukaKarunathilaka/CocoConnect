import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/fertilizer_api.dart';
import '../../widgets/owner_widgets.dart';
import 'fertilizer_chrome.dart';
import 'fertilizer_data.dart';

class FertilizerTalkPage extends StatefulWidget {
  const FertilizerTalkPage({super.key, this.place, this.contactId, this.contactName})
      : assert(place != null || contactId != null);
  final FertPlace? place;
  final int? contactId;
  final String? contactName;

  @override
  State<FertilizerTalkPage> createState() => _FertilizerTalkPageState();
}

class _FertilizerTalkPageState extends State<FertilizerTalkPage> {
  final _message = TextEditingController();
  final _scroll = ScrollController();
  late int? _contactId = widget.contactId;
  late String _name = widget.contactName ?? widget.place?.company ?? '';
  List<Map<String, dynamic>>? _messages;
  String? _error;
  bool _loading = false;
  bool _sending = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_messages != null && !_sending) _load();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      if (_contactId == null) {
        final phone = AuthService.normalisePhone(widget.place!.phone);
        final directory = await FertilizerApi.suppliers(government: false);
        final supplier = directory.where((row) =>
            phone.isNotEmpty && phone == AuthService.normalisePhone(row['phone']?.toString() ?? '')).firstOrNull;
        if (supplier == null) {
          throw const ApiException('This shop has no registered chat account. Choose a registered supplier from Fertilizer Messages.');
        }
        _contactId = supplier['id'] as int;
      }
      final thread = await FertilizerApi.messages(_contactId!);
      if (!mounted) return;
      final nearEnd = !_scroll.hasClients || _scroll.position.extentAfter < 80;
      setState(() {
        _name = (thread['contact'] as Map)['name'].toString();
        _messages = (thread['messages'] as List)
            .map((row) => Map<String, dynamic>.from(row as Map)).toList();
        _error = null;
      });
      if (nearEnd || _sending) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
        });
      }
    } on ApiException catch (error) {
      if (mounted && _messages == null) setState(() => _error = error.message);
    } finally {
      _loading = false;
    }
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    final contactId = _contactId;
    if (_sending || _loading || contactId == null || text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await FertilizerApi.sendMessage(contactId, text);
      if (!mounted) return;
      _message.clear();
      await _load();
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _bubble(Map<String, dynamic> row) {
    final mine = row['sender_user_id'] == AuthService.currentUser?.id;
    final date = DateTime.tryParse(row['created_at'].toString())?.toLocal();
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFFDCF3DC) : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(row['message'].toString()),
            if (date != null)
              Text(TimeOfDay.fromDateTime(date).format(context),
                  style: const TextStyle(fontSize: 10, color: kOwnerMuted)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FertPage(
    title: 'Negotiation',
    subtitle: _name,
    child: ColoredBox(
      color: const Color(0xFFEFE9DF),
      child: Column(
        children: [
          Expanded(
            child: _error != null
                ? Center(child: TextButton(onPressed: _load, child: Text(_error!, textAlign: TextAlign.center)))
                : _messages == null
                ? const Center(child: CircularProgressIndicator())
                : _messages!.isEmpty
                ? const Center(child: Text('Start a conversation.'))
                : ListView(controller: _scroll, padding: const EdgeInsets.all(12), children: _messages!.map(_bubble).toList()),
          ),
          if (_messages != null)
            Container(
              color: kOwnerCream,
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _message,
                      enabled: !_sending,
                      maxLength: 2000,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Type a message',
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(tooltip: 'Send message', onPressed: _sending ? null : _send, icon: const Icon(Icons.send_rounded)),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class FertilizerMessagesPage extends StatefulWidget {
  const FertilizerMessagesPage({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<FertilizerMessagesPage> createState() => _FertilizerMessagesPageState();
}

class _FertilizerMessagesPageState extends State<FertilizerMessagesPage> {
  late Future<List<Map<String, dynamic>>> _threads = FertilizerApi.chats();
  bool get _isOwner => AuthService.currentUser?.role == 'ESTATE_OWNER';

  Future<void> _open(Map<String, dynamic> contact) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => FertilizerTalkPage(
      contactId: contact['id'] as int, contactName: contact['name'].toString(),
    )));
    if (mounted) setState(() => _threads = FertilizerApi.chats());
  }

  Future<void> _chooseSupplier() async {
    try {
      final suppliers = await FertilizerApi.suppliers(government: false);
      if (!mounted) return;
      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Choose a supplier'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (suppliers.isEmpty) const Text('No registered suppliers are available.'),
              for (final supplier in suppliers)
                ListTile(
                  title: Text(supplier['name'].toString()),
                  subtitle: Text(supplier['location']?.toString() ?? ''),
                  onTap: () => Navigator.pop(context, supplier),
                ),
            ],
          ),
        ),
      );
      if (selected != null && mounted) await _open(selected);
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        if (_isOwner)
          TextButton.icon(onPressed: _chooseSupplier,
            icon: const Icon(Icons.add_comment_outlined), label: const Text('Message a supplier')),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _threads,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: TextButton(
                  onPressed: () => setState(() => _threads = FertilizerApi.chats()),
                  child: Text(snapshot.error.toString(), textAlign: TextAlign.center),
                ));
              }
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              return RefreshIndicator(
                onRefresh: () async {
                  setState(() => _threads = FertilizerApi.chats());
                  try { await _threads; } on ApiException catch (_) {}
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (snapshot.data!.isEmpty) const Center(child: Text('No messages yet.')),
                    for (final thread in snapshot.data!)
                      ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.chat_bubble_outline)),
                        title: Text(thread['name'].toString()),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _open(thread),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
    return widget.embedded ? body : FertPage(title: 'Fertilizer Messages', child: body);
  }
}
