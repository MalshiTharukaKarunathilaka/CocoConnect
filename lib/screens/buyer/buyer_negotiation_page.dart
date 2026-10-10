import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/buyer_widgets.dart';
import 'coconut_type.dart';

enum _DealStatus { negotiating, accepted, rejected, completed }

class _ChatMessage {
  final String text;
  final String time;
  final bool isMine;

  const _ChatMessage(this.text, this.time, {required this.isMine});
}

class BuyerNegotiationPage extends StatefulWidget {
  final CoconutType type;
  final String estateName;
  final String ownerName;
  final int pricePerNut;
  final int quantity;

  const BuyerNegotiationPage({
    super.key,
    this.type = CoconutType.raw,
    this.estateName = 'ABC Estate',
    this.ownerName = 'ABC Estate Owner',
    this.pricePerNut = 130,
    this.quantity = 1200,
  });

  @override
  State<BuyerNegotiationPage> createState() => _BuyerNegotiationPageState();
}

class _BuyerNegotiationPageState extends State<BuyerNegotiationPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  /// Messages the buyer sends on this screen, shown after the seeded history.
  final List<_ChatMessage> _messages = [];

  _DealStatus _status = _DealStatus.negotiating;

  /// Buyer opens 20 below asking, owner counters 5 under, then offers 10 under.
  int get _buyerOffer => widget.pricePerNut - 20;
  int get _ownerCounter => widget.pricePerNut - 5;
  int get _latestOffer => widget.pricePerNut - 10;

  bool get _isOpen => _status == _DealStatus.negotiating;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _now() => TimeOfDay.now().format(context);

  void _showSnack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _addMessage(String text) {
    setState(() => _messages.add(_ChatMessage(text, _now(), isMine: true)));
    // Wait for the new bubble to lay out before scrolling to it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final String text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    _addMessage(text);
  }

  Future<bool> _confirm(String title, String body, String action) async {
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
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _counterOffer() async {
    final controller = TextEditingController();
    final int? price = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Counter Offer'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            prefixText: 'Rs. ',
            suffixText: 'per nut',
            hintText: 'Your price',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final int? value = int.tryParse(controller.text);
              if (value != null && value > 0) Navigator.pop(context, value);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (price != null) {
      _addMessage(
        'Counter offer: Rs. $price.00 per nut '
        'for ${widget.quantity} nuts.',
      );
    }
  }

  Future<void> _reject() async {
    final bool ok = await _confirm(
      'Reject offer?',
      'This ends the negotiation with ${widget.estateName}.',
      'Reject',
    );
    if (!ok || !mounted) return;
    setState(() => _status = _DealStatus.rejected);
    _showSnack('Offer rejected');
  }

  Future<void> _accept() async {
    // 144000 -> "144,000"
    final String total = (_latestOffer * widget.quantity)
        .toString()
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    final bool ok = await _confirm(
      'Accept deal?',
      'Rs. $_latestOffer.00 per nut for ${widget.quantity} nuts\n'
          'Total: Rs. $total.00',
      'Accept',
    );
    if (!ok || !mounted) return;
    setState(() => _status = _DealStatus.accepted);
    _showSnack('Deal accepted at Rs. $_latestOffer.00 per nut');
  }

  Future<void> _complete() async {
    final bool ok = await _confirm(
      'Complete transaction?',
      'Confirm that you have collected the nuts and paid the estate owner.',
      'Complete',
    );
    if (!ok || !mounted) return;
    setState(() => _status = _DealStatus.completed);
    _showSnack('Transaction completed');
  }

  BuyerPill get _statusPill {
    switch (_status) {
      case _DealStatus.negotiating:
        return const BuyerPill(
          text: 'PENDING ORDER',
          background: Color(0xFFF0EDE6),
          foreground: Color(0xFF5A5A5A),
        );
      case _DealStatus.accepted:
        return const BuyerPill(
          text: 'DEAL ACCEPTED',
          background: Color(0xFFDDEEE0),
          foreground: kBuyerGreen,
        );
      case _DealStatus.rejected:
        return const BuyerPill(
          text: 'REJECTED',
          background: Color(0xFFFBE3E3),
          foreground: Color(0xFFC62828),
        );
      case _DealStatus.completed:
        return const BuyerPill(
          text: 'COMPLETED',
          background: Color(0xFFDDEEE0),
          foreground: kBuyerGreen,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int shownPrice =
        _status == _DealStatus.negotiating || _status == _DealStatus.rejected
        ? widget.pricePerNut
        : _latestOffer;

    return BuyerScaffold(
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.arrow_back,
                    size: 22,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.estateName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.ownerName,
                        style: const TextStyle(fontSize: 11, color: kBuyerGrey),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'Seller',
                  style: TextStyle(fontSize: 12, color: kBuyerGrey),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: BuyerPill(
                      text: 'ORDER ESTABLISHED',
                      background: Color(0xFFDDEEE0),
                      foreground: kBuyerGreen,
                      icon: Icons.circle,
                    ),
                  ),

                  const SizedBox(height: 16),

                  BuyerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _isOpen ? 'Current Offer' : 'Agreed Price',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  widget.type.singular,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF3A3A3A),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: kBuyerGrey,
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        Text(
                          '${widget.quantity} nuts',
                          style: const TextStyle(
                            fontSize: 12,
                            color: kBuyerGrey,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rs. $shownPrice.00',
                                  style: const TextStyle(
                                    fontSize: 25,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'per nut',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: kBuyerGrey,
                                  ),
                                ),
                              ],
                            ),
                            _statusPill,
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Center(
                    child: BuyerPill(
                      text: 'Negotiation Started - Today',
                      background: Color(0xFFF0EDE6),
                      foreground: Color(0xFF5A5A5A),
                      fontSize: 11,
                    ),
                  ),

                  const SizedBox(height: 18),

                  Align(
                    alignment: Alignment.centerRight,
                    child: NegotiationBubble(
                      message:
                          "Hello, I'm interested in the ${widget.quantity} "
                          'nuts. Can you do Rs.$_buyerOffer?',
                      time: '10:42AM',
                      isMine: true,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: NegotiationBubble(
                      message:
                          'Thanks for reaching out. The quality is premium '
                          'this season. Best I can do is Rs. $_ownerCounter.',
                      time: '10:45 AM',
                      isMine: false,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Container(
                    width: 250,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kBuyerGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'NEW OFFER RECEIVED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1, color: Color(0x55FFFFFF)),
                        ),
                        Text(
                          'Rs. $_latestOffer.00',
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 4),

                  const Text(
                    '10:50 AM',
                    style: TextStyle(fontSize: 10, color: kBuyerGrey),
                  ),

                  for (final message in _messages) ...[
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: NegotiationBubble(
                        message: message.text,
                        time: message.time,
                        isMine: message.isMine,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: kBuyerBorder)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Counter offer',
                      onPressed: _isOpen ? _counterOffer : null,
                      icon: const Icon(Icons.local_offer_outlined),
                      color: kBuyerGreen,
                    ),
                    Expanded(
                      child: BuyerInputField(
                        controller: _messageController,
                        hint: _isOpen
                            ? 'Type a message...'
                            : 'Negotiation closed',
                        enabled: _isOpen,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        suffix: IconButton(
                          icon: const Icon(Icons.send, size: 18),
                          color: kBuyerGreen,
                          onPressed: _isOpen ? _sendMessage : null,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: BuyerOutlinedButton(
                        label: 'Reject',
                        onPressed: _isOpen ? _reject : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isOpen ? _accept : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kBuyerGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Accept Deal',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Only possible once a deal has been accepted.
                BuyerOutlinedButton(
                  label: 'Complete Transaction',
                  leadingIcon: Icons.check_circle_outline,
                  onPressed: _status == _DealStatus.accepted ? _complete : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
