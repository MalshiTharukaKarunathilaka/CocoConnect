import 'package:flutter/material.dart';

const Color _workerChatBackground = Color(0xFFFCF9F3);
const Color _workerChatInk = Color(0xFF17243A);
const Color _workerChatMuted = Color(0xFF61718A);
const Color _workerChatGreen = Color(0xFF43855F);

class WorkerChatPage extends StatefulWidget {
  final String workerName;

  const WorkerChatPage({super.key, required this.workerName});

  @override
  State<WorkerChatPage> createState() => _WorkerChatPageState();
}

class _WorkerChatPageState extends State<WorkerChatPage> {
  final _messageController = TextEditingController();
  final List<String> _messages = [''];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _send() {
    final String message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add(message);
      _messageController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
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
                _header(context),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(17, 30, 17, 0),
                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 20),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFDCE5EF)),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        _dateLabel(),
                        const SizedBox(height: 44),
                        Expanded(
                          child: ListView.builder(
                            reverse: false,
                            itemCount: _messages.length,
                            itemBuilder: (context, index) => _messageBubble(
                              _messages[index],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _composer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
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
            icon: const Icon(
              Icons.arrow_back,
              size: 38,
              color: _workerChatMuted,
            ),
          ),
          const SizedBox(width: 20),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.workerName,
                style: const TextStyle(
                  color: _workerChatInk,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'WORKER',
                style: TextStyle(color: _workerChatMuted, fontSize: 21),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateLabel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF1F3),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Text(
        'Negotiation Started - Today',
        style: TextStyle(
          color: _workerChatMuted,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _messageBubble(String message) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 135, minHeight: 143),
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: _workerChatGreen,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 5,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: message.isEmpty
                  ? null
                  : Text(
                      message,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
            ),
            const SizedBox(height: 10),
            const Text(
              '10:45 AM',
              style: TextStyle(color: Color(0xFF8A9BB2), fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(36, 22, 36, 24),
      height: 118,
      padding: const EdgeInsets.fromLTRB(20, 20, 13, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(60),
        border: Border.all(color: const Color(0xFFE0E8F0), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
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
                hintStyle: TextStyle(color: Colors.transparent),
              ),
            ),
          ),
          IconButton(
            onPressed: _send,
            icon: const Icon(Icons.send_outlined, color: Colors.white, size: 34),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF256B45),
              fixedSize: const Size(84, 62),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
