import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/mock_data.dart';
import '../models.dart';
import '../state/jobs_state.dart';
import '../theme.dart';
import '../widgets/ui.dart';

const _ownerReplies = [
  'Thanks for reaching out. Let me check and get back to you shortly.',
  'We can discuss that. What rate did you have in mind?',
  'Sounds reasonable. I will confirm with the estate manager.',
];

class NegotiationScreen extends StatefulWidget {
  final DateTime date;
  final String jobId;
  const NegotiationScreen({super.key, required this.date, required this.jobId});

  @override
  State<NegotiationScreen> createState() => _NegotiationScreenState();
}

class _NegotiationScreenState extends State<NegotiationScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  int _replyCount = 0;

  Job get _job => getJob(widget.jobId);

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  void _send([String? value]) {
    final text = (value ?? _controller.text).trim();
    if (text.isEmpty) return;
    final state = context.read<JobsState>();
    state.addMessage(widget.date, widget.jobId, Sender.worker, text);
    _controller.clear();
    _scrollToEnd();

    // Simulated estate-owner reply. Replace with a real backend / websocket.
    final reply = _ownerReplies[_replyCount++ % _ownerReplies.length];
    Timer(const Duration(milliseconds: 1200), () {
      state.addMessage(widget.date, widget.jobId, Sender.owner, reply);
      _scrollToEnd();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<JobsState>();
    final job = _job;
    final estate = getEstate(job.estateId);
    final messages = state.chat(widget.date, widget.jobId);
    final mine = state.isMine(widget.date, widget.jobId);
    final quick = [job.rate + 200, job.rate + 400]
        .map((r) => 'Can you do Rs.${money(r)}/day?')
        .toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.arrow_back, size: 24),
                  ),
                  const SizedBox(width: 12),
                  InitialsBox(estate.initials, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(estate.owner,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text)),
                        Text(estate.name,
                            style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppColors.primarySoft, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  const SizedBox(height: 2),
                  Text(
                      'Rs.${money(job.rate)}/day · ${formatDMY(widget.date)}${mine ? ' · Accepted' : ''}',
                      style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                ],
              ),
            ),
            Expanded(
              child: messages.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Start the negotiation by sending a message or an offer.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _bubble(messages[i]),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final q in quick)
                    GestureDetector(
                      onTap: () => _send(q),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: Text(q,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                          color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.send, size: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(ChatMessage m) {
    final mine = m.from == Sender.worker;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
        ),
        child: Text(m.text,
            style: TextStyle(
                fontSize: 16, color: mine ? Colors.white : AppColors.text)),
      ),
    );
  }
}
