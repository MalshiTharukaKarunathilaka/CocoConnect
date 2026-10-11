import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_client.dart';
import '../../services/buyer_service.dart';
import '../../widgets/buyer_widgets.dart';
import 'buyer_format.dart';
import 'coconut_type.dart';

enum _DealStatus { negotiating, accepted, rejected, completed }

class BuyerNegotiationPage extends StatefulWidget {
  final int negotiationId;
  final CoconutType type;

  const BuyerNegotiationPage({
    super.key,
    required this.negotiationId,
    required this.type,
  });

  @override
  State<BuyerNegotiationPage> createState() => _BuyerNegotiationPageState();
}

class _BuyerNegotiationPageState extends State<BuyerNegotiationPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  Negotiation? _negotiation;
  String? _loadError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  _DealStatus get _status {
    final Negotiation? negotiation = _negotiation;
    if (negotiation == null) return _DealStatus.negotiating;
    switch (negotiation.status) {
      case 'REJECTED':
        return _DealStatus.rejected;
      case 'ACCEPTED':
        return negotiation.orderStatus == 'COMPLETED'
            ? _DealStatus.completed
            : _DealStatus.accepted;
      default:
        return _DealStatus.negotiating;
    }
  }

  bool get _isOpen => _status == _DealStatus.negotiating;

  Future<void> _load({bool scrollToEnd = true}) async {
    try {
      final negotiation = await BuyerService.getNegotiation(
        widget.negotiationId,
      );
      if (!mounted) return;
      setState(() {
        _negotiation = negotiation;
        _loadError = null;
      });
      if (scrollToEnd) _scrollToEnd();
    } on ApiException catch (error) {
      if (!mounted) return;
      if (_negotiation == null) {
        setState(() => _loadError = error.message);
      } else {
        // Keep showing what we have; just say the refresh failed.
        _showSnack(error.message, error: true);
      }
    }
  }

  void _scrollToEnd() {
    // Wait for the new bubbles to lay out before scrolling to them.
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

  void _showSnack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? const Color(0xFFC62828) : null,
        ),
      );
  }

  /// Runs a server action with the buttons disabled, then reloads.
  Future<void> _run(Future<void> Function() action, String doneMessage) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
      if (mounted && doneMessage.isNotEmpty) _showSnack(doneMessage);
    } on ApiException catch (error) {
      if (mounted) _showSnack(error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _sendMessage() {
    final String text = _messageController.text.trim();
    if (text.isEmpty) return;
    _run(() async {
      await BuyerService.sendMessage(widget.negotiationId, text: text);
      _messageController.clear();
    }, '');
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
    final int? price = await showDialog<int>(
      context: context,
      builder: (context) => const _CounterOfferDialog(),
    );

    if (price == null) return;
    _run(
      () => BuyerService.sendMessage(
        widget.negotiationId,
        offerPrice: price.toDouble(),
      ),
      'Counter offer sent',
    );
  }

  Future<void> _reject() async {
    final bool ok = await _confirm(
      'Reject offer?',
      'This ends the negotiation with ${_negotiation!.listing.estateName}.',
      'Reject',
    );
    if (!ok) return;
    _run(() => BuyerService.rejectDeal(widget.negotiationId), 'Offer rejected');
  }

  Future<void> _accept() async {
    final Negotiation negotiation = _negotiation!;
    final double price = negotiation.priceOnTable;
    final int quantity = negotiation.listing.quantity;
    final bool ok = await _confirm(
      'Accept deal?',
      '${rupees(price)} per nut for ${withCommas(quantity)} nuts\n'
          'Total: ${rupees(price * quantity)}',
      'Accept',
    );
    if (!ok) return;
    _run(
      () => BuyerService.acceptDeal(widget.negotiationId),
      'Deal accepted at ${rupees(price)} per nut',
    );
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
    final Negotiation? negotiation = _negotiation;

    return BuyerScaffold(
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(18, 12, 8, 14),
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
                        negotiation?.listing.estateName ?? 'Negotiation',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        negotiation?.listing.ownerName ?? '',
                        style: const TextStyle(fontSize: 11, color: kBuyerGrey),
                      ),
                    ],
                  ),
                ),
                // The owner replies from their own app, so new messages
                // appear on refresh.
                IconButton(
                  tooltip: 'Check for replies',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.refresh, color: kBuyerGrey),
                  onPressed: _busy ? null : () => _load(),
                ),
              ],
            ),
          ),

          Expanded(child: _buildBody()),

          if (negotiation != null) _buildActions(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final Negotiation? negotiation = _negotiation;

    if (negotiation == null) {
      if (_loadError == null) {
        return const Center(
          child: CircularProgressIndicator(color: kBuyerGreen),
        );
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 32, color: kBuyerGrey),
              const SizedBox(height: 10),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: kBuyerGrey),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() => _loadError = null);
                  _load();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try again'),
                style: TextButton.styleFrom(foregroundColor: kBuyerGreen),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: kBuyerGreen,
      onRefresh: () => _load(scrollToEnd: false),
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BuyerCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        switch (_status) {
                          _DealStatus.negotiating => 'Current Offer',
                          _DealStatus.rejected => 'Last Offer',
                          _ => 'Agreed Price',
                        },
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        widget.type.singular,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3A3A3A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${withCommas(negotiation.listing.quantity)} nuts',
                    style: const TextStyle(fontSize: 12, color: kBuyerGrey),
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
                            rupees(negotiation.priceOnTable),
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'per nut',
                            style: TextStyle(fontSize: 11, color: kBuyerGrey),
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
                text: 'Negotiation Started',
                background: Color(0xFFF0EDE6),
                foreground: Color(0xFF5A5A5A),
                fontSize: 11,
              ),
            ),

            if (negotiation.messages.isEmpty && _isOpen)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(
                  child: Text(
                    'Send a message or a counter offer to start.',
                    style: TextStyle(fontSize: 12.5, color: kBuyerGrey),
                  ),
                ),
              ),

            for (final message in negotiation.messages) ...[
              const SizedBox(height: 14),
              _buildMessage(message),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(NegotiationMessage message) {
    final String time = clockTime(message.createdAt);

    // The estate owner's counter-offer gets the highlighted offer card.
    if (!message.isMine && message.offerPrice != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                const Row(
                  children: [
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
                  rupees(message.offerPrice!),
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (message.text != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    message.text!,
                    style: const TextStyle(fontSize: 12.5, color: Colors.white),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(time, style: const TextStyle(fontSize: 10, color: kBuyerGrey)),
        ],
      );
    }

    final List<String> lines = [
      if (message.offerPrice != null)
        'Counter offer: ${rupees(message.offerPrice!)} per nut',
      if (message.text != null) message.text!,
    ];

    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: NegotiationBubble(
        message: lines.join('\n'),
        time: time,
        isMine: message.isMine,
      ),
    );
  }

  Widget _buildActions() {
    final bool canAct = _isOpen && !_busy;

    return Container(
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
                onPressed: canAct ? _counterOffer : null,
                icon: const Icon(Icons.local_offer_outlined),
                color: kBuyerGreen,
              ),
              Expanded(
                child: BuyerInputField(
                  controller: _messageController,
                  hint: _isOpen ? 'Type a message...' : 'Negotiation closed',
                  enabled: _isOpen,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  suffix: IconButton(
                    icon: const Icon(Icons.send, size: 18),
                    color: kBuyerGreen,
                    onPressed: canAct ? _sendMessage : null,
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
                  onPressed: canAct ? _reject : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: canAct ? _accept : null,
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

          if (_status == _DealStatus.accepted ||
              _status == _DealStatus.completed) ...[
            const SizedBox(height: 12),
            // The estate owner completes the deal with the delivered figures.
            Text(
              _status == _DealStatus.completed
                  ? 'Deal completed by the estate owner.'
                  : 'The estate owner completes the deal once the nuts '
                        'are delivered.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: kBuyerGrey),
            ),
          ],
        ],
      ),
    );
  }
}

/// Owns its text controller so it is only disposed once the dialog's closing
/// animation has finished with it.
class _CounterOfferDialog extends StatefulWidget {
  const _CounterOfferDialog();

  @override
  State<_CounterOfferDialog> createState() => _CounterOfferDialogState();
}

class _CounterOfferDialogState extends State<_CounterOfferDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final int? value = int.tryParse(_controller.text);
    if (value != null && value > 0) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Counter Offer'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onSubmitted: (_) => _send(),
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
        TextButton(onPressed: _send, child: const Text('Send')),
      ],
    );
  }
}
