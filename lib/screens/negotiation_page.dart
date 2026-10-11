import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import '../services/buyer_service.dart';
import '../services/owner_service.dart';
import '../widgets/owner_widgets.dart';
import 'buyer/buyer_format.dart';
import 'buyer/coconut_type.dart';
import 'complete_deal_page.dart';

/// Estate owner's side of a negotiation with a buyer on one of their
/// listings: chat, counter-offer, reject, accept the buyer's offer and,
/// once delivered, complete the deal.
class NegotiationPage extends StatefulWidget {
  final int negotiationId;

  const NegotiationPage({super.key, required this.negotiationId});

  @override
  State<NegotiationPage> createState() => _NegotiationPageState();
}

class _NegotiationPageState extends State<NegotiationPage> {
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

  bool get _isOpen => _negotiation?.status == 'OPEN';

  bool get _buyerHasOffered =>
      _negotiation?.messages.any((m) => !m.isMine && m.offerPrice != null) ??
      false;

  Future<void> _load() async {
    try {
      final negotiation = await OwnerService.getChat(widget.negotiationId);
      if (!mounted) return;
      setState(() {
        _negotiation = negotiation;
        _loadError = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (_negotiation == null) {
        setState(() => _loadError = error.message);
      } else {
        _showSnack(error.message, error: true);
      }
    }
  }

  void _showSnack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? kOwnerRed : kOwnerGreen,
        ),
      );
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
      if (mounted && done.isNotEmpty) _showSnack(done);
    } on ApiException catch (error) {
      if (mounted) _showSnack(error.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _send() {
    final String text = _messageController.text.trim();
    if (text.isEmpty) return;
    _run(() async {
      await OwnerService.reply(widget.negotiationId, text: text);
      _messageController.clear();
    }, '');
  }

  Future<void> _counterOffer() async {
    final int? price = await showDialog<int>(
      context: context,
      builder: (context) => const _PriceDialog(),
    );
    if (price == null) return;
    _run(
      () => OwnerService.reply(
        widget.negotiationId,
        offerPrice: price.toDouble(),
      ),
      'Offer sent to the buyer',
    );
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
    required Color color,
  }) async {
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

  Future<void> _reject() async {
    final bool ok = await _confirm(
      title: 'Reject this negotiation?',
      body:
          'This closes the chat with '
          '${_negotiation!.buyerName ?? 'the buyer'}.',
      action: 'Reject',
      color: kOwnerRed,
    );
    if (!ok) return;
    _run(
      () => OwnerService.decline(widget.negotiationId),
      'Negotiation rejected',
    );
  }

  Future<void> _accept() async {
    final Negotiation negotiation = _negotiation!;
    final double price = negotiation.priceOnTable;
    final int quantity = negotiation.listing.quantity;
    final bool ok = await _confirm(
      title: 'Accept this deal?',
      body:
          '${withCommas(quantity)} nuts at ${rupees(price)} per nut, '
          'total ${rupees(quantity * price)}.\n\n'
          'This creates an order with '
          '${negotiation.buyerName ?? 'the buyer'}.',
      action: 'Accept Deal',
      color: kOwnerGreen,
    );
    if (!ok) return;
    _run(
      () => OwnerService.acceptChat(widget.negotiationId),
      'Deal accepted. It is now in your Deal Window.',
    );
  }

  Future<void> _complete() async {
    final int? orderId = _negotiation?.orderId;
    if (orderId == null) return;
    if (await openCompleteDeal(context, orderId)) _load();
  }

  @override
  Widget build(BuildContext context) {
    final String buyerName = _negotiation?.buyerName ?? '';

    return OwnerPage(
      child: Column(
        children: [
          OwnerHeader(
            title: buyerName.isEmpty ? 'Negotiation' : buyerName,
            subtitle: 'BUYER NEGOTIATION',
            actions: [
              IconButton(
                tooltip: 'Check for new messages',
                icon: const Icon(Icons.refresh, color: kOwnerGreen),
                onPressed: _busy ? null : _load,
              ),
            ],
          ),
          Expanded(child: _buildBody()),
          if (_negotiation != null) _buildActions(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final Negotiation? negotiation = _negotiation;

    if (negotiation == null) {
      if (_loadError == null) {
        return const Center(
          child: CircularProgressIndicator(color: kOwnerGreen),
        );
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

    final Listing listing = negotiation.listing;

    return RefreshIndicator(
      color: kOwnerGreen,
      onRefresh: _load,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        children: [
          MarketPulse(productType: listing.productType),
          _OfferCard(
            negotiation: negotiation,
            buyerHasOffered: _buyerHasOffered,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            decoration: BoxDecoration(
              color: kOwnerPanel,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.forum_outlined, size: 16, color: kOwnerMuted),
                    SizedBox(width: 6),
                    Text(
                      'Negotiation Chat',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: kOwnerMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (negotiation.messages.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'No messages yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: kOwnerMuted),
                    ),
                  ),
                for (final message in negotiation.messages) ...[
                  _Bubble(message: message),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          if (negotiation.status == 'ACCEPTED') ...[
            const SizedBox(height: 12),
            _Note(
              negotiation.orderStatus == 'COMPLETED'
                  ? 'Deal completed. See it in your Deal Window.'
                  : 'Deal accepted. Complete the transaction once the nuts '
                        'are delivered.',
            ),
          ],
          if (negotiation.status == 'REJECTED') ...[
            const SizedBox(height: 12),
            const _Note('This negotiation is closed.', closed: true),
          ],
        ],
      ),
    );
  }

  Widget _buildActions() {
    final Negotiation negotiation = _negotiation!;
    final bool canAct = _isOpen && !_busy;
    final bool canComplete =
        negotiation.status == 'ACCEPTED' &&
        negotiation.orderId != null &&
        negotiation.orderStatus != 'COMPLETED';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kOwnerBorder)),
      ),
      child: Column(
        children: [
          if (_isOpen) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF7F7F5),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: kOwnerBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: kOwnerBorder),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Make an offer',
                  onPressed: canAct ? _counterOffer : null,
                  icon: const Icon(Icons.local_offer_outlined),
                  color: kOwnerBrown,
                ),
                IconButton.filled(
                  tooltip: 'Send',
                  onPressed: canAct ? _send : null,
                  icon: const Icon(Icons.send, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: kOwnerGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canAct ? _reject : null,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kOwnerRed,
                      side: const BorderSide(color: kOwnerRed),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: canAct ? _accept : null,
                    icon: const Icon(Icons.handshake_outlined, size: 18),
                    label: const Text('Accept Deal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kOwnerGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (canComplete)
            OwnerPrimaryButton(
              label: 'Complete Transaction',
              arrow: true,
              onPressed: _busy ? null : _complete,
            )
          else
            Text(
              negotiation.status == 'REJECTED'
                  ? 'Negotiation closed'
                  : 'Deal completed',
              style: const TextStyle(fontSize: 13, color: kOwnerMuted),
            ),
        ],
      ),
    );
  }
}

/// "Current Offer": product, status and the price the buyer is offering.
class _OfferCard extends StatelessWidget {
  final Negotiation negotiation;
  final bool buyerHasOffered;

  const _OfferCard({required this.negotiation, required this.buyerHasOffered});

  OwnerPill get _pill {
    if (negotiation.status == 'REJECTED') {
      return const OwnerPill('Closed', tone: PillTone.red);
    }
    if (negotiation.status == 'ACCEPTED') {
      return negotiation.orderStatus == 'COMPLETED'
          ? const OwnerPill('Completed', icon: Icons.verified_outlined)
          : const OwnerPill('Accepted', icon: Icons.handshake_outlined);
    }
    return const OwnerPill(
      'Negotiating',
      icon: Icons.sync_alt,
      tone: PillTone.neutral,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Listing listing = negotiation.listing;
    final CoconutType type = CoconutType.fromCode(listing.productType);
    final double price = negotiation.priceOnTable;

    return OwnerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Current Offer',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: kOwnerInk,
                  ),
                ),
              ),
              _pill,
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
                  type.singular,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kOwnerGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            buyerHasOffered
                ? "Buyer's latest offer"
                : 'No counter-offer yet - your listed price',
            style: const TextStyle(fontSize: 11.5, color: kOwnerMuted),
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              text: rupees(price),
              children: const [
                TextSpan(
                  text: ' / nut',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                    color: kOwnerMuted,
                  ),
                ),
              ],
            ),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: kOwnerGreen,
            ),
          ),
          const SizedBox(height: 12),
          QuantityPriceBox(
            quantity: listing.quantity,
            pricePerUnit: listing.pricePerUnit,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your listing  ·  total at offer',
                  style: TextStyle(fontSize: 12, color: kOwnerMuted),
                ),
              ),
              Text(
                rupees(listing.quantity * price),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: kOwnerInk,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final NegotiationMessage message;

  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final bool mine = message.isMine;

    return Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: mine ? kOwnerGreen : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(mine ? 14 : 3),
              bottomRight: Radius.circular(mine ? 3 : 14),
            ),
            border: mine ? null : Border.all(color: kOwnerBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.offerPrice != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_offer,
                      size: 14,
                      color: mine ? const Color(0xFFFFE08A) : kOwnerBrown,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        mine
                            ? 'Your offer: ${rupees(message.offerPrice!)} / nut'
                            : 'Offer: ${rupees(message.offerPrice!)} / nut',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: mine ? Colors.white : kOwnerInk,
                        ),
                      ),
                    ),
                  ],
                ),
              if (message.offerPrice != null && message.text != null)
                const SizedBox(height: 4),
              if (message.text != null)
                Text(
                  message.text!,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: mine ? Colors.white : const Color(0xFF263238),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${mine ? 'You' : 'Buyer'}  ·  ${clockTime(message.createdAt)}',
          style: const TextStyle(fontSize: 10, color: kOwnerMuted),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  final bool closed;

  const _Note(this.text, {this.closed = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: closed ? const Color(0xFFFDECEC) : kOwnerGreenSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          color: closed ? kOwnerRed : kOwnerGreen,
        ),
      ),
    );
  }
}

/// Owns its controller so it is only disposed after the dialog closes.
class _PriceDialog extends StatefulWidget {
  const _PriceDialog();

  @override
  State<_PriceDialog> createState() => _PriceDialogState();
}

class _PriceDialogState extends State<_PriceDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final int? value = int.tryParse(_controller.text);
    if (value != null && value > 0) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Make an Offer'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onSubmitted: (_) => _submit(),
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
        TextButton(onPressed: _submit, child: const Text('Send')),
      ],
    );
  }
}
