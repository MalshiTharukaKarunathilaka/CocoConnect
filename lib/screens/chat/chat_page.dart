import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_client.dart';
import '../../services/chat_service.dart';
import '../../widgets/owner_widgets.dart';
import '../buyer/buyer_format.dart';
import '../buyer/coconut_type.dart';
import '../complete_deal_page.dart';

const Color _green = Color(0xFF256B45);
const Color _wallpaper = Color(0xFFEFE9DF);
const Color _myBubble = Color(0xFFDCF3DC);
const Color _muted = Color(0xFF6B7280);
const Color _red = Color(0xFFC62828);
const Color _brown = Color(0xFF8B4A1C);

/// Opens a chat; returns when the user comes back.
Future<void> openChat(BuildContext context, int chatId) => Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => ChatPage(chatId: chatId)),
);

/// One negotiation, WhatsApp style, the same for buyers and estate owners.
/// It starts with the Current Offer card; either side sends messages and
/// price offers, and only the other side can accept or reject an offer.
class ChatPage extends StatefulWidget {
  final int chatId;

  const ChatPage({super.key, required this.chatId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  /// How often an open chat checks for new messages.
  static const Duration _pollEvery = Duration(seconds: 5);

  final _textController = TextEditingController();
  final _scroll = ScrollController();

  ChatDetail? _chat;
  String? _loadError;
  bool _busy = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(_pollEvery, (_) {
      if (!_busy) _load(quiet: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _textController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final ChatDetail chat = await ChatService.getChat(widget.chatId);
      if (!mounted) return;
      final int before = _chat?.messages.length ?? -1;
      setState(() {
        _chat = chat;
        _loadError = null;
      });
      if (chat.messages.length != before) _scrollToEnd();
    } on ApiException catch (error) {
      if (!mounted || quiet) return;
      if (_chat == null) {
        setState(() => _loadError = error.message);
      } else {
        _snack(error.message, error: true);
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), backgroundColor: error ? _red : _green),
      );
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
      if (mounted && done.isNotEmpty) _snack(done);
    } on ApiException catch (error) {
      if (mounted) _snack(error.message, error: true);
      await _load(quiet: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(
    String title,
    String body,
    String action,
    Color color,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: color),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _send() {
    final String text = _textController.text.trim();
    if (text.isEmpty) return;
    _run(() async {
      await ChatService.send(widget.chatId, text: text);
      _textController.clear();
    }, '');
  }

  Future<void> _makeOffer() async {
    final (double, String)? offer = await showDialog<(double, String)>(
      context: context,
      builder: (context) => _OfferDialog(quantity: _chat!.quantity),
    );
    if (offer == null) return;
    final (double price, String note) = offer;
    _run(
      () => ChatService.send(widget.chatId, text: note, offerPrice: price),
      'Offer sent. ${_chat!.counterpartName} can accept or reject it.',
    );
  }

  Future<void> _accept(ChatMessage offer) async {
    final ChatDetail chat = _chat!;
    final double total = offer.offerPrice! * chat.quantity;
    if (!await _confirm(
      'Accept this offer?',
      '${withCommas(chat.quantity)} nuts at ${rupees(offer.offerPrice!)} per '
          'nut, total ${rupees(total)}.\n\nThis makes the deal with '
          '${chat.counterpartName}.',
      'Accept Deal',
      _green,
    )) {
      return;
    }
    _run(
      () => ChatService.acceptOffer(widget.chatId, offer.id),
      'Deal accepted at ${rupees(offer.offerPrice!)} per nut',
    );
  }

  Future<void> _reject(ChatMessage offer) async {
    if (!await _confirm(
      'Reject this offer?',
      '${rupees(offer.offerPrice!)} per nut from ${_chat!.counterpartName}. '
          'The chat stays open, so you can send your own price.',
      'Reject',
      _red,
    )) {
      return;
    }
    _run(
      () => ChatService.rejectOffer(widget.chatId, offer.id),
      'Offer rejected',
    );
  }

  Future<void> _acceptListing() async {
    final ChatDetail chat = _chat!;
    if (!await _confirm(
      'Accept the listed price?',
      '${withCommas(chat.quantity)} nuts at ${rupees(chat.listedPrice)} per '
          'nut, total ${rupees(chat.listedPrice * chat.quantity)}.',
      'Accept Deal',
      _green,
    )) {
      return;
    }
    _run(
      () => ChatService.acceptListing(widget.chatId),
      'Deal accepted at ${rupees(chat.listedPrice)} per nut',
    );
  }

  Future<void> _closeChat() async {
    if (!await _confirm(
      'Close this negotiation?',
      'It ends without a deal. Neither side can send offers afterwards.',
      'Close',
      _red,
    )) {
      return;
    }
    _run(() => ChatService.close(widget.chatId), 'Negotiation closed');
  }

  Future<void> _complete() async {
    final int? orderId = _chat?.orderId;
    if (orderId == null) return;
    if (await openCompleteDeal(context, orderId)) _load();
  }

  @override
  Widget build(BuildContext context) {
    final ChatDetail? chat = _chat;

    return Scaffold(
      backgroundColor: _wallpaper,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            _ChatHeader(
              chat: chat,
              onClose: chat != null && chat.isOpen && !_busy
                  ? _closeChat
                  : null,
            ),
            Expanded(child: _buildMessages()),
            if (chat != null) _buildBottom(chat),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages() {
    final ChatDetail? chat = _chat;
    if (chat == null) {
      if (_loadError == null) {
        return const Center(child: CircularProgressIndicator(color: _green));
      }
      return OwnerMessage(
        icon: Icons.cloud_off_outlined,
        text: _loadError!,
        onRetry: () {
          setState(() => _loadError = null);
          _load();
        },
      );
    }

    return RefreshIndicator(
      color: _green,
      onRefresh: _load,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        children: [
          if (!chat.iAmBuyer) MarketPulse(productType: chat.productType),
          _CurrentOfferCard(
            chat: chat,
            busy: _busy,
            onAcceptListing: _acceptListing,
            onMakeOffer: _makeOffer,
          ),
          const SizedBox(height: 10),
          if (chat.messages.isEmpty)
            const _SystemNote(
              'Say hello, or send a price with the tag button below.',
            ),
          for (final ChatMessage message in chat.messages)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: message.isOffer
                  ? _OfferBubble(
                      message: message,
                      chat: chat,
                      busy: _busy,
                      onAccept: () => _accept(message),
                      onReject: () => _reject(message),
                    )
                  : _TextBubble(message: message),
            ),
          if (chat.isAccepted)
            _SystemNote(
              chat.isCompleted
                  ? 'Deal completed and delivered.'
                  : 'Deal accepted at ${rupees(chat.orderPrice ?? 0)} per nut. '
                        '${chat.iAmBuyer ? 'The estate owner completes it once the nuts are delivered.' : 'Complete the transaction once the nuts are delivered.'}',
              good: true,
            ),
          if (chat.status == 'REJECTED')
            const _SystemNote('This negotiation was closed without a deal.'),
        ],
      ),
    );
  }

  Widget _buildBottom(ChatDetail chat) {
    Widget bar(Widget child) => Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      color: const Color(0xFFF7F4EE),
      child: SafeArea(top: false, child: child),
    );

    if (chat.isOpen) {
      return bar(
        Row(
          children: [
            IconButton(
              tooltip: 'Send a price offer',
              onPressed: _busy ? null : _makeOffer,
              icon: const Icon(Icons.local_offer_outlined, color: _brown),
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Message',
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
              tooltip: 'Send',
              onPressed: _busy ? null : _send,
              style: IconButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.send, size: 20),
            ),
          ],
        ),
      );
    }

    if (chat.isAccepted && !chat.isCompleted && !chat.iAmBuyer) {
      return bar(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: OwnerPrimaryButton(
            label: 'Complete Transaction',
            arrow: true,
            onPressed: _busy ? null : _complete,
          ),
        ),
      );
    }

    return bar(
      Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          chat.isCompleted
              ? 'Deal completed'
              : chat.isAccepted
              ? 'Deal accepted - waiting for delivery'
              : 'Negotiation closed',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: _muted),
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final ChatDetail? chat;
  final VoidCallback? onClose;

  const _ChatHeader({required this.chat, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final ChatDetail? chat = this.chat;
    final String name = chat?.counterpartName ?? '';
    final String subtitle = chat == null
        ? ''
        : [
            if (chat.iAmBuyer) 'Estate' else 'Buyer',
            if ((chat.counterpartLocation ?? '').isNotEmpty)
              chat.counterpartLocation!,
          ].join('  ·  ');

    return Container(
      color: _green,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              CircleAvatar(
                radius: 19,
                backgroundColor: Colors.white24,
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
                      name.isEmpty ? 'Chat' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (onClose != null)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (_) => onClose!(),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'close',
                      child: Text('Close negotiation'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// First thing in every chat: what is being traded and the price on the
/// table right now.
class _CurrentOfferCard extends StatelessWidget {
  final ChatDetail chat;
  final bool busy;
  final VoidCallback onAcceptListing;
  final VoidCallback onMakeOffer;

  const _CurrentOfferCard({
    required this.chat,
    required this.busy,
    required this.onAcceptListing,
    required this.onMakeOffer,
  });

  @override
  Widget build(BuildContext context) {
    final CoconutType type = CoconutType.fromCode(chat.productType);
    final ChatMessage? latest = chat.latestOffer;
    final bool pending = latest?.offerStatus == OfferStatus.pending;

    final (String caption, double price) = chat.isAccepted
        ? ('Agreed price', chat.orderPrice ?? chat.listedPrice)
        : pending
        ? (
            latest!.isMine
                ? 'Your offer, waiting for an answer'
                : "${chat.counterpartName}'s offer",
            latest.offerPrice!,
          )
        : ('Listed price', chat.listedPrice);

    final OwnerPill pill = switch (chat.status) {
      'ACCEPTED' =>
        chat.isCompleted
            ? const OwnerPill('Completed', icon: Icons.verified_outlined)
            : const OwnerPill('Deal accepted', icon: Icons.handshake_outlined),
      'REJECTED' => const OwnerPill('Closed', tone: PillTone.red),
      _ => const OwnerPill(
        'Negotiating',
        icon: Icons.sync_alt,
        tone: PillTone.neutral,
      ),
    };

    return OwnerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'CURRENT OFFER',
                  style: TextStyle(
                    fontSize: 11.5,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.bold,
                    color: _muted,
                  ),
                ),
              ),
              pill,
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: kOwnerGreenSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(type.icon, size: 15, color: type.iconColor),
                const SizedBox(width: 5),
                Text(
                  '${type.singular}  ·  ${chat.estateName ?? ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(caption, style: const TextStyle(fontSize: 12, color: _muted)),
          Text.rich(
            TextSpan(
              text: rupees(price),
              children: const [
                TextSpan(
                  text: ' / nut',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                    color: _muted,
                  ),
                ),
              ],
            ),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: _green,
            ),
          ),
          const SizedBox(height: 10),
          QuantityPriceBox(
            quantity: chat.quantity,
            pricePerUnit: chat.listedPrice,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  chat.availableDate == null
                      ? 'Listed price shown above'
                      : 'Available ${shortDate(chat.availableDate)}',
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ),
              Text(
                'Total ${rupees(price * chat.quantity)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: kOwnerInk,
                ),
              ),
            ],
          ),
          if (chat.canAcceptListing) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onMakeOffer,
                    icon: const Icon(Icons.local_offer_outlined, size: 18),
                    label: const Text('Make Offer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _brown,
                      side: const BorderSide(color: _brown),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: busy ? null : onAcceptListing,
                    icon: const Icon(Icons.handshake_outlined, size: 18),
                    label: const Text('Accept Deal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final bool mine;
  final Widget child;
  final DateTime? time;
  final double maxWidth;

  const _Bubble({
    required this.mine,
    required this.child,
    required this.time,
    this.maxWidth = 285,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 6),
        decoration: BoxDecoration(
          color: mine ? _myBubble : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 3),
            bottomRight: Radius.circular(mine ? 3 : 14),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(14),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            child,
            const SizedBox(height: 3),
            Text(
              clockTime(time),
              style: const TextStyle(fontSize: 10, color: _muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextBubble extends StatelessWidget {
  final ChatMessage message;

  const _TextBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return _Bubble(
      mine: message.isMine,
      time: message.createdAt,
      child: Align(
        alignment: Alignment.centerLeft,
        widthFactor: 1,
        child: Text(
          message.text ?? '',
          style: const TextStyle(
            fontSize: 14,
            height: 1.35,
            color: Color(0xFF1F2A24),
          ),
        ),
      ),
    );
  }
}

/// A price offer. The other side answers it here: Reject or Accept Deal.
class _OfferBubble extends StatelessWidget {
  final ChatMessage message;
  final ChatDetail chat;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _OfferBubble({
    required this.message,
    required this.chat,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final double price = message.offerPrice!;
    final OfferStatus status = message.offerStatus ?? OfferStatus.pending;
    final bool canAnswer =
        !message.isMine && status == OfferStatus.pending && chat.isOpen;

    final Widget footer = switch (status) {
      OfferStatus.pending when canAnswer => Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: busy ? null : onReject,
              style: OutlinedButton.styleFrom(
                foregroundColor: _red,
                side: const BorderSide(color: _red),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Reject'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: busy ? null : onAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                elevation: 0,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Accept Deal'),
            ),
          ),
        ],
      ),
      OfferStatus.pending => _status(
        Icons.schedule,
        'Waiting for ${chat.counterpartName} to answer',
        _muted,
      ),
      OfferStatus.accepted => _status(
        Icons.check_circle,
        'Accepted - deal made',
        _green,
      ),
      OfferStatus.rejected => _status(Icons.cancel, 'Rejected', _red),
      OfferStatus.superseded => _status(
        Icons.redo,
        'Replaced by a newer offer',
        _muted,
      ),
      OfferStatus.closed => _status(Icons.block, 'Negotiation closed', _muted),
    };

    return _Bubble(
      mine: message.isMine,
      time: message.createdAt,
      maxWidth: 300,
      child: SizedBox(
        width: 260,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_offer, size: 14, color: _brown),
                const SizedBox(width: 5),
                Text(
                  message.isMine ? 'YOUR PRICE OFFER' : 'PRICE OFFER',
                  style: const TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.bold,
                    color: _brown,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${rupees(price)} / nut',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color:
                    status == OfferStatus.superseded ||
                        status == OfferStatus.rejected
                    ? _muted
                    : _green,
                decoration:
                    status == OfferStatus.superseded ||
                        status == OfferStatus.rejected
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            Text(
              'Total ${rupees(price * chat.quantity)} for '
              '${withCommas(chat.quantity)} nuts',
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
            if ((message.text ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message.text!,
                style: const TextStyle(fontSize: 13.5, height: 1.35),
              ),
            ],
            const Divider(height: 18),
            footer,
          ],
        ),
      ),
    );
  }

  Widget _status(IconData icon, String text, Color color) => Row(
    children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 5),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    ],
  );
}

class _SystemNote extends StatelessWidget {
  final String text;
  final bool good;

  const _SystemNote(this.text, {this.good = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: good ? kOwnerGreenSoft : const Color(0xFFFFF6D6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            color: good ? _green : const Color(0xFF5A4A1A),
          ),
        ),
      ),
    );
  }
}

/// Price and an optional note. Owns its controllers so they outlive the
/// closing animation.
class _OfferDialog extends StatefulWidget {
  final int quantity;

  const _OfferDialog({required this.quantity});

  @override
  State<_OfferDialog> createState() => _OfferDialogState();
}

class _OfferDialogState extends State<_OfferDialog> {
  final _price = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  double? get _value => double.tryParse(_price.text.trim());

  void _submit() {
    final double? value = _value;
    if (value != null && value > 0) {
      Navigator.pop(context, (value, _note.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final double? value = _value;
    return AlertDialog(
      title: const Text('Send a Price Offer'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _price,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixText: 'Rs. ',
              suffixText: 'per nut',
              labelText: 'Your price',
            ),
          ),
          if (value != null && value > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Total ${rupees(value * widget.quantity)} for '
                '${withCommas(widget.quantity)} nuts',
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Message (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Send Offer')),
      ],
    );
  }
}
