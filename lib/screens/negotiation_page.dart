import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import '../services/buyer_service.dart';
import '../services/owner_service.dart';
import 'buyer/buyer_format.dart';
import 'buyer/coconut_type.dart';

const Color _navy = Color(0xFF1B3557);
const Color _ink = Color(0xFF0F1F35);
const Color _green = Color(0xFF2E7D32);
const Color _darkGreen = Color(0xFF1F6B3D);
const Color _grey = Color(0xFF6B7280);
const Color _border = Color(0xFFD8E1EA);
const Color _red = Color(0xFFC62828);

/// Estate owner's side of a negotiation with a buyer on one of their
/// listings: read the buyer's messages, reply, counter-offer or decline.
/// The buyer accepts a price from their side.
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
          backgroundColor: error ? _red : _darkGreen,
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

  Future<void> _decline() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline negotiation?'),
        content: Text(
          'This closes the chat with ${_negotiation!.buyerName ?? 'the buyer'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: _red),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _run(
      () => OwnerService.decline(widget.negotiationId),
      'Negotiation declined',
    );
  }

  (String, Color, Color) get _statusPill {
    final Negotiation negotiation = _negotiation!;
    if (negotiation.status == 'REJECTED') {
      return ('CLOSED', const Color(0xFFFBE3E3), _red);
    }
    if (negotiation.status == 'ACCEPTED') {
      return negotiation.orderStatus == 'COMPLETED'
          ? ('COMPLETED', const Color(0xFFE8F5E9), _green)
          : ('ORDER PLACED', const Color(0xFFE8F5E9), _green);
    }
    return ('NEGOTIATING', const Color(0xFFF0EDE6), const Color(0xFF5A5A5A));
  }

  @override
  Widget build(BuildContext context) {
    final String buyerName = _negotiation?.buyerName ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Center(
          child: Container(
            width: 390,
            height: double.infinity,
            color: const Color(0xFFFCF8EF),
            child: SafeArea(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.arrow_back,
                            color: _navy,
                            size: 22,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                buyerName.isEmpty ? 'Negotiation' : buyerName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'BUYER',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Check for new messages',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.refresh, color: _navy),
                          onPressed: _busy ? null : _load,
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _buildBody()),
                  if (_negotiation != null) _buildActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final Negotiation? negotiation = _negotiation;

    if (negotiation == null) {
      if (_loadError == null) {
        return const Center(child: CircularProgressIndicator(color: _green));
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 32, color: _grey),
              const SizedBox(height: 10),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _grey),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() => _loadError = null);
                  _load();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try again'),
                style: TextButton.styleFrom(foregroundColor: _green),
              ),
            ],
          ),
        ),
      );
    }

    final Listing listing = negotiation.listing;
    final (String pillText, Color pillBg, Color pillFg) = _statusPill;

    return RefreshIndicator(
      color: _green,
      onRefresh: _load,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      CoconutType.fromCode(listing.productType).singular,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: pillBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        pillText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: pillFg,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${withCommas(listing.quantity)} nuts  ·  your listing '
                  'price ${rupees(listing.pricePerUnit)}',
                  style: const TextStyle(fontSize: 12, color: _grey),
                ),
                const SizedBox(height: 12),
                Text(
                  negotiation.priceOnTable == listing.pricePerUnit
                      ? 'No counter-offer from the buyer yet'
                      : "Buyer's latest offer",
                  style: const TextStyle(fontSize: 11, color: _grey),
                ),
                const SizedBox(height: 2),
                Text(
                  '${rupees(negotiation.priceOnTable)} / nut',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (negotiation.messages.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(
                child: Text('No messages yet.', style: TextStyle(color: _grey)),
              ),
            ),
          for (final message in negotiation.messages) ...[
            _Bubble(message: message),
            const SizedBox(height: 12),
          ],
          if (negotiation.status == 'ACCEPTED')
            const _Note(
              'The buyer accepted the deal. It appears under Orders.',
            ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final bool canAct = _isOpen && !_busy;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  enabled: _isOpen,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: _isOpen
                        ? 'Reply to the buyer...'
                        : 'Negotiation closed',
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF7F7F7),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Send',
                onPressed: canAct ? _send : null,
                icon: const Icon(Icons.send),
                color: _darkGreen,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: canAct ? _decline : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _red,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: canAct ? _counterOffer : null,
                  icon: const Icon(Icons.local_offer_outlined, size: 18),
                  label: const Text('Make Offer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _darkGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
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
    final List<String> lines = [
      if (message.offerPrice != null)
        mine
            ? 'Your offer: ${rupees(message.offerPrice!)} per nut'
            : 'Buyer offers ${rupees(message.offerPrice!)} per nut',
      if (message.text != null) message.text!,
    ];

    return Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 270),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: mine ? _darkGreen : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: mine ? null : Border.all(color: _border),
          ),
          child: Text(
            lines.join('\n'),
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              fontWeight: message.offerPrice != null
                  ? FontWeight.w600
                  : FontWeight.normal,
              color: mine ? Colors.white : const Color(0xFF263238),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          clockTime(message.createdAt),
          style: const TextStyle(fontSize: 10, color: _grey),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  final String text;

  const _Note(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12.5, color: _darkGreen),
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
