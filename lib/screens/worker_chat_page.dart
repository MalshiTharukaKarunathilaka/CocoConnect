import '../widgets/role_navigation_page.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/day_job_chat_service.dart';

const Color _workerChatBackground = Color(0xFFEFE9DF);
const Color _workerChatBar = Color(0xFFF7F4EE);
const Color _workerChatInk = Color(0xFF1F2A24);
const Color _workerChatMuted = Color(0xFF6B7280);
const Color _workerChatGreen = Color(0xFF256B45);
const Color _workerChatMyBubble = Color(0xFFDCF3DC);

class WorkerChatPage extends StatefulWidget {
  final int chatId;

  const WorkerChatPage({super.key, required this.chatId});

  @override
  State<WorkerChatPage> createState() => _WorkerChatPageState();
}

class _WorkerChatPageState extends State<WorkerChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _poll;
  DayJobChat? _chat;
  String? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _load(quiet: true),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final chat = await DayJobChatService.getChat(widget.chatId);
      if (!mounted) return;
      final changed = _chat?.messages.length != chat.messages.length;
      setState(() {
        _chat = chat;
        _error = null;
      });
      if (changed) _scrollToEnd();
    } on ApiException catch (error) {
      if (!mounted || quiet) return;
      setState(() => _error = error.message);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await DayJobChatService.send(widget.chatId, text);
      _messageController.clear();
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = _chat;
    return RoleNavigationPage(
      current: AppTab.chats,
      chatScope: ChatScope.dayJobs,
      child: Scaffold(
        backgroundColor: _workerChatBackground,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              _header(context, chat),
              Expanded(child: _messages(chat)),
              _composer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, DayJobChat? chat) {
    final name = chat?.counterpartName ?? '';
    return Container(
      decoration: const BoxDecoration(
        color: _workerChatBar,
        border: Border(bottom: BorderSide(color: Color(0xFFEDE7DA))),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: _workerChatInk),
              ),
              CircleAvatar(
                radius: 19,
                backgroundColor: _workerChatGreen,
                child: Text(
                  name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Loading...' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _workerChatGreen,
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (chat != null)
                      Text(
                        chat.counterpartRole == 'WORKER'
                            ? 'WORKER'
                            : 'LAND OWNER',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _workerChatMuted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messages(DayJobChat? chat) {
    if (_error != null && chat == null) {
      return Center(child: Text(_error!));
    }
    if (chat == null) {
      return const Center(
        child: CircularProgressIndicator(color: _workerChatGreen),
      );
    }
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      children: [
        _dateLabel(),
        _jobLabel(chat.category),
        const SizedBox(height: 10),
        if (chat.messages.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Start a conversation with the land owner.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _workerChatMuted),
              ),
            ),
          )
        else
          for (final message in chat.messages) _messageBubble(context, message),
      ],
    );
  }

  Widget _dateLabel() => Center(
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6D6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'Day job chat',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12.5, color: Color(0xFF5A4A1A)),
      ),
    ),
  );

  Widget _jobLabel(String category) => Align(
    alignment: Alignment.center,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFDDEEE0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        category,
        style: const TextStyle(
          color: _workerChatGreen,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );

  Widget _messageBubble(BuildContext context, DayJobChatMessage message) {
    final maxBubbleWidth = (MediaQuery.sizeOf(context).width * 0.78)
        .clamp(220.0, 360.0)
        .toDouble();
    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        decoration: BoxDecoration(
          color: message.isMine ? _workerChatMyBubble : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(message.isMine ? 14 : 3),
            bottomRight: Radius.circular(message.isMine ? 3 : 14),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(14),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          message.message,
          style: const TextStyle(
            color: _workerChatInk,
            fontSize: 14,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _composer() => Container(
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
    color: _workerChatBar,
    child: SafeArea(
      top: false,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Type a message',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            tooltip: 'Send message',
            onPressed: _sending ? null : _send,
            style: IconButton.styleFrom(backgroundColor: _workerChatGreen),
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send, color: Colors.white),
          ),
        ],
      ),
    ),
  );
}
