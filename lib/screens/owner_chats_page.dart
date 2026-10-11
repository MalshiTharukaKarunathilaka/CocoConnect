import 'package:flutter/material.dart';
import '../services/buyer_service.dart';
import '../services/owner_service.dart';
import '../widgets/async_list.dart';
import '../widgets/owner_widgets.dart';
import 'buyer/buyer_format.dart';
import 'buyer/coconut_type.dart';
import 'negotiation_page.dart';

/// Every negotiation buyers have started on this estate's listings.
class OwnerChatsPage extends StatelessWidget {
  const OwnerChatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return OwnerPage(
      child: Column(
        children: [
          const OwnerHeader(title: 'Buyer Chats', subtitle: 'NEGOTIATIONS'),
          Expanded(
            child: AsyncList<NegotiationSummary>(
              load: OwnerService.getChats,
              emptyText:
                  'No buyer chats yet. Buyers can start one from your '
                  'listings in the marketplace.',
              itemBuilder: (context, chat, reload) => _ChatCard(
                chat: chat,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          NegotiationPage(negotiationId: chat.id),
                    ),
                  );
                  reload();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatCard extends StatelessWidget {
  final NegotiationSummary chat;
  final VoidCallback onTap;

  const _ChatCard({required this.chat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final OwnerPill pill = switch (chat.status) {
      'REJECTED' => const OwnerPill('Closed', tone: PillTone.red),
      'ACCEPTED' =>
        chat.orderStatus == 'COMPLETED'
            ? const OwnerPill('Completed', icon: Icons.check_circle_outline)
            : const OwnerPill('Deal Accepted', icon: Icons.handshake_outlined),
      _ => const OwnerPill('Negotiating', tone: PillTone.neutral),
    };
    final CoconutType type = CoconutType.fromCode(chat.productType);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: OwnerCard(
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: kOwnerGreenSoft,
              child: Text(
                (chat.buyerName ?? 'B').trim().isEmpty
                    ? 'B'
                    : chat.buyerName!.trim()[0].toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: kOwnerGreen,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.buyerName ?? 'Buyer',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: kOwnerInk,
                          ),
                        ),
                      ),
                      pill,
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${type.label}  ·  ${withCommas(chat.quantity)} nuts  ·  '
                    'listed ${rupees(chat.listedPrice)}',
                    style: const TextStyle(fontSize: 12.5, color: kOwnerInk),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    chat.messageCount == 1
                        ? '1 message'
                        : '${chat.messageCount} messages',
                    style: const TextStyle(fontSize: 12, color: kOwnerMuted),
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
