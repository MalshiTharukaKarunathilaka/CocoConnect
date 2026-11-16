import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/day_job_chat_service.dart';
import 'worker_chat_page.dart';

const Color _green = Color(0xFF256B45);
const Color _muted = Color(0xFF6B7280);

String _chatTime(BuildContext context, DateTime? time) {
  if (time == null) return '';
  final now = DateTime.now();
  final day = DateTime(time.year, time.month, time.day);
  final ago = DateTime(now.year, now.month, now.day).difference(day).inDays;
  if (ago == 0) {
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(time));
  }
  if (ago == 1) return 'Yesterday';
  return '${time.day}/${time.month}/${time.year}';
}

/// The signed-in worker or estate owner's day-job conversations.
class DayJobChatsList extends StatefulWidget {
  final bool showTitle;
  final ValueChanged<int>? onUnreadChanged;

  const DayJobChatsList({
    super.key,
    this.showTitle = false,
    this.onUnreadChanged,
  });

  @override
  State<DayJobChatsList> createState() => _DayJobChatsListState();
}

class _DayJobChatsListState extends State<DayJobChatsList> {
  List<DayJobChatSummary>? _chats;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _load(quiet: true),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final chats = await DayJobChatService.getChats();
      if (!mounted) return;
      setState(() {
        _chats = chats;
        _error = null;
      });
      widget.onUnreadChanged?.call(
        chats.fold(0, (total, chat) => total + chat.unreadCount),
      );
    } on ApiException catch (error) {
      if (mounted && !quiet) setState(() => _error = error.message);
    }
  }

  Future<void> _open(DayJobChatSummary chat) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WorkerChatPage(chatId: chat.id)),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final chats = _chats;
    if (chats == null) {
      if (_error != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 42, color: _muted),
                const SizedBox(height: 10),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Try again')),
              ],
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator(color: _green));
    }

    return RefreshIndicator(
      color: _green,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: widget.showTitle ? 8 : 0, bottom: 16),
        itemCount: chats.isEmpty
            ? 1
            : chats.length + (widget.showTitle ? 1 : 0),
        separatorBuilder: (_, index) => index == 0 && widget.showTitle
            ? const SizedBox.shrink()
            : const Divider(height: 1, indent: 78),
        itemBuilder: (context, index) {
          if (chats.isEmpty) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(28, 80, 28, 20),
              child: Column(
                children: [
                  Icon(Icons.chat_bubble_outline, size: 48, color: _muted),
                  SizedBox(height: 12),
                  Text(
                    'No day-job chats yet. A chat appears after a worker applies for a job.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 16),
                  ),
                ],
              ),
            );
          }
          if (widget.showTitle && index == 0) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Text(
                'Day-job chats',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            );
          }
          final chat = chats[index - (widget.showTitle ? 1 : 0)];
          return DayJobChatTile(chat: chat, onTap: () => _open(chat));
        },
      ),
    );
  }
}

class DayJobChatTile extends StatelessWidget {
  final DayJobChatSummary chat;
  final VoidCallback onTap;

  const DayJobChatTile({super.key, required this.chat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unread = chat.unreadCount > 0;
    final name = chat.counterpartName.trim().isEmpty
        ? 'User'
        : chat.counterpartName;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: const Color(0xFFDDEEE0),
        child: Text(
          name[0].toUpperCase(),
          style: const TextStyle(
            color: _green,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            _chatTime(context, chat.lastActivityAt),
            style: TextStyle(
              color: unread ? _green : _muted,
              fontSize: 11.5,
              fontWeight: unread ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            const Icon(Icons.work_outline, size: 14, color: _green),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                '${chat.category} · ${chat.lastMessage ?? 'Conversation started'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unread ? const Color(0xFF111B21) : _muted,
                  fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (unread)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${chat.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
