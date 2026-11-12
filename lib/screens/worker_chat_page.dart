import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/day_job_chat_service.dart';

const Color _workerChatBackground = Color(0xFFFCF9F3);
const Color _workerChatInk = Color(0xFF17243A);
const Color _workerChatMuted = Color(0xFF61718A);
const Color _workerChatGreen = Color(0xFF43855F);

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = _chat;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          width: 390,
          constraints: const BoxConstraints(maxWidth: 430),
          color: _workerChatBackground,
          child: SafeArea(
            child: Column(
              children: [
                _header(context, chat),
                Expanded(child: _messages(chat)),
                _composer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, DayJobChat? chat) {
    return Container(
      height: 124,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE0E4E9))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 38, color: _workerChatMuted),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chat?.counterpartName ?? 'Loading...',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _workerChatInk,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  chat?.counterpartRole == 'WORKER'
                      ? 'WORKER'
                      : 'ESTATE OWNER',
                  style: const TextStyle(color: _workerChatMuted, fontSize: 17),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messages(DayJobChat? chat) {
    if (_error != null && chat == null) {
      return Center(child: Text(_error!));
    }
    if (chat == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(17, 30, 17, 0),
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 20),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFDCE5EF)),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        children: [
          _dateLabel(),
          const SizedBox(height: 18),
          _jobLabel(chat.category),
          const SizedBox(height: 30),
          if (chat.messages.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Start a conversation with the estate owner.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _workerChatMuted),
                ),
              ),
            )
          else
            for (final message in chat.messages) _messageBubble(message),
        ],
      ),
    );
  }

  Widget _dateLabel() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF1F3),
      borderRadius: BorderRadius.circular(28),
    ),
    child: const Text(
      'Day job chat',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: _workerChatMuted,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _jobLabel(String category) => Align(
    alignment: Alignment.center,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF1F3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        category,
        style: const TextStyle(
          color: _workerChatMuted,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );

  Widget _messageBubble(DayJobChatMessage message) {
    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: message.isMine ? _workerChatGreen : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          message.message,
          style: TextStyle(
            color: message.isMine ? Colors.white : _workerChatInk,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _composer() => Container(
    margin: const EdgeInsets.fromLTRB(36, 22, 36, 24),
    height: 80,
    padding: const EdgeInsets.fromLTRB(20, 10, 13, 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(40),
      border: Border.all(color: const Color(0xFFE0E8F0), width: 1.5),
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _messageController,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Type a message',
            ),
          ),
        ),
        IconButton(
          onPressed: _sending ? null : _send,
          icon: const Icon(Icons.send_outlined, color: Colors.white, size: 30),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF256B45),
            fixedSize: const Size(64, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    ),
  );
}
