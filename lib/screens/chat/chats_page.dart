import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/chat_service.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/owner_widgets.dart';
import '../buyer/buyer_format.dart';
import '../buyer/coconut_type.dart';
import 'chat_page.dart';

const Color _green = Color(0xFF256B45);
const Color _muted = Color(0xFF6B7280);

const List<Color> _avatarColors = [
  Color(0xFF2E7D32),
  Color(0xFF8B4A1C),
  Color(0xFF1565C0),
  Color(0xFF6A1B9A),
  Color(0xFF00838F),
];

/// "2:05 PM" today, "Yesterday", otherwise "12 Oct 2026".
String chatTime(DateTime? time) {
  if (time == null) return '';
  final DateTime now = DateTime.now();
  final DateTime day = DateTime(time.year, time.month, time.day);
  final int ago = DateTime(now.year, now.month, now.day).difference(day).inDays;
  if (ago == 0) return clockTime(time);
  if (ago == 1) return 'Yesterday';
  return shortDate(time);
}

/// All my negotiations, WhatsApp style: newest first, unread counts, and a
/// marker when an offer is waiting for my answer.
class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  List<ChatSummary>? _chats;
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
      final List<ChatSummary> chats = await ChatService.getChats();
      if (mounted) {
        setState(() {
          _chats = chats;
          _error = null;
        });
      }
    } on ApiException catch (error) {
      if (mounted && !quiet) setState(() => _error = error.message);
    }
  }

  Future<void> _open(ChatSummary chat) async {
    await openChat(context, chat.id);
    _load();
    Unread.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return OwnerPage(
      bottom: const AppBottomNav(current: AppTab.chats),
      child: Column(
        children: [
          const OwnerHeader(title: 'Chats', subtitle: 'NEGOTIATIONS'),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    final List<ChatSummary>? chats = _chats;
    if (chats == null) {
      if (_error == null) {
        return const Center(child: CircularProgressIndicator(color: _green));
      }
      return OwnerMessage(
        icon: Icons.cloud_off_outlined,
        text: _error!,
        onRetry: _load,
      );
    }

    return RefreshIndicator(
      color: _green,
      onRefresh: _load,
      child: chats.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                OwnerMessage(
                  icon: Icons.chat_bubble_outline,
                  text:
                      'No chats yet. A chat starts when a buyer taps Negotiate '
                      'on a listing.',
                ),
              ],
            )
          : ListView.separated(
              // The green header already handled the status bar.
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: chats.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, indent: 80),
              itemBuilder: (context, index) => _ChatTile(
                chat: chats[index],
                onTap: () => _open(chats[index]),
              ),
            ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final ChatSummary chat;
  final VoidCallback onTap;

  const _ChatTile({required this.chat, required this.onTap});

  String get _preview {
    if (chat.lastOfferPrice != null) {
      final String who = chat.lastIsMine ? 'You offered' : 'Offer:';
      return '$who ${rupees(chat.lastOfferPrice!)} / nut';
    }
    if (chat.lastText != null) {
      return chat.lastIsMine ? 'You: ${chat.lastText}' : chat.lastText!;
    }
    return 'New negotiation - listed at ${rupees(chat.listedPrice)}';
  }

  @override
  Widget build(BuildContext context) {
    final bool unread = chat.unreadCount > 0;
    final CoconutType type = CoconutType.fromCode(chat.productType);
    final String name = chat.counterpartName.isEmpty
        ? '?'
        : chat.counterpartName;
    final String? state = switch (chat.status) {
      'ACCEPTED' =>
        chat.orderStatus == 'COMPLETED' ? 'Completed' : 'Deal accepted',
      'REJECTED' => 'Closed',
      _ => null,
    };

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: _avatarColors[chat.id % _avatarColors.length],
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111B21),
                          ),
                        ),
                      ),
                      Text(
                        chatTime(chat.lastActivityAt),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: unread
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: unread ? _green : _muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${type.label}  ·  ${withCommas(chat.quantity)} nuts'
                    '${state == null ? '' : '  ·  $state'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: _muted),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (chat.lastOfferPrice != null) ...[
                        const Icon(
                          Icons.local_offer,
                          size: 13,
                          color: Color(0xFF8B4A1C),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          _preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: unread
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: unread ? const Color(0xFF111B21) : _muted,
                          ),
                        ),
                      ),
                      if (chat.offerWaiting)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0D9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Reply',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8B4A1C),
                            ),
                          ),
                        ),
                      if (unread)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          constraints: const BoxConstraints(minWidth: 20),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _green,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${chat.unreadCount}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
