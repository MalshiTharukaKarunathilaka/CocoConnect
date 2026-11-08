import 'package:flutter/material.dart';
import '../services/owner_service.dart';

const Color _jobGreen = Color(0xFF245F48);
const Color _jobBackground = Color(0xFFFCF9F3);
const Color _jobInk = Color(0xFF17251F);

class PostDayJobPage extends StatefulWidget {
  final DateTime requiredDate;

  const PostDayJobPage({super.key, required this.requiredDate});

  @override
  State<PostDayJobPage> createState() => _PostDayJobPageState();
}

class _PostDayJobPageState extends State<PostDayJobPage> {
  int _workers = 5;
  String _category = 'Nut Gatherer';
  String _paymentMethod = 'Direct Bank Transfer';
  final TextEditingController _rateController = TextEditingController(
    text: '2500',
  );

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  String get _dateLabel {
    final now = DateTime.now();
    final date = widget.requiredDate;
    final prefix =
        date.difference(DateTime(now.year, now.month, now.day)).inDays == 1
        ? 'Tomorrow, '
        : '';
    return '$prefix${date.day} ${_months[date.month - 1]}';
  }

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  Future<void> _broadcast() async {
    final rate = double.tryParse(_rateController.text.trim());
    if (rate == null || rate < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid daily rate')),
      );
      return;
    }

    try {
      await OwnerService.createDayJob(
        category: _category,
        workersNeeded: _workers,
        requiredDate: widget.requiredDate,
        location: 'Green Valley Estate, Wattagama Rd, Kurunegala',
        dailyRate: rate,
        paymentMethod: _paymentMethod,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Day job broadcast successfully')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not broadcast job: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE7E5DF),
      body: Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 430),
          color: _jobBackground,
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: 338,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _title(),
                            const SizedBox(height: 10),
                            _categoryCard(),
                            const SizedBox(height: 8),
                            _workersCard(),
                            const SizedBox(height: 8),
                            _dateCard(),
                            const SizedBox(height: 8),
                            _locationCard(),
                            const SizedBox(height: 8),
                            _rateCard(),
                            const SizedBox(height: 8),
                            _paymentCard(),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 56,
                              width: 338,
                              child: FilledButton.icon(
                                onPressed: _broadcast,
                                icon: const Icon(Icons.arrow_forward, size: 25),
                                label: const Text(
                                  'Broadcast Job',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _jobGreen,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(38),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _title() {
    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(
            color: Color(0xFFD8EEE1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.sensors, color: _jobGreen, size: 31),
        ),
        const SizedBox(width: 14),
        const Text(
          'Post Day Job',
          style: TextStyle(
            color: _jobInk,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _outlinedCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
      decoration: BoxDecoration(
        color: _jobBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFA8C1B2), width: 1.4),
      ),
      child: child,
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFF68766F),
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
  );

  Widget _categoryCard() {
    return _outlinedCard(
      child: DropdownButtonFormField<String>(
        initialValue: _category,
        decoration: InputDecoration(
          labelText: 'Job Category',
          labelStyle: const TextStyle(color: Color(0xFF68766F), fontSize: 13),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        icon: const Icon(Icons.keyboard_arrow_down, color: _jobGreen, size: 22),
        items: const [
          DropdownMenuItem(value: 'Nut Gatherer', child: Text('Nut Gatherer')),
          DropdownMenuItem(
            value: 'Machine Weeder',
            child: Text('Machine Weeder'),
          ),
          DropdownMenuItem(
            value: 'Manual Worker',
            child: Text('Manual Worker'),
          ),
        ],
        onChanged: (value) => setState(() => _category = value!),
        style: const TextStyle(
          color: _jobInk,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _workersCard() {
    return _outlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Workers Needed'),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _roundButton(Icons.remove, () {
                if (_workers > 1) setState(() => _workers--);
              }),
              Column(
                children: [
                  Text(
                    '$_workers',
                    style: const TextStyle(
                      color: _jobGreen,
                      fontSize: 35,
                      height: .9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _workers == 1 ? 'Gatherer' : 'Gatherers',
                    style: const TextStyle(
                      color: Color(0xFF68766F),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              _roundButton(Icons.add, () => setState(() => _workers++)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 30, color: const Color(0xFF3D4958)),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        fixedSize: const Size(45, 45),
        side: const BorderSide(color: Color(0xFFDCE1E6)),
      ),
    );
  }

  Widget _dateCard() {
    return _outlinedCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('Required Date'),
                const SizedBox(height: 3),
                Text(
                  _dateLabel,
                  style: const TextStyle(
                    color: _jobInk,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.event_available, color: _jobGreen, size: 25),
        ],
      ),
    );
  }

  Widget _locationCard() {
    return _outlinedCard(
      child: Row(
        children: [
          const Icon(
            Icons.location_on_outlined,
            color: Color(0xFFB77A39),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Green Valley Estate, Wattagama Rd, Kurunegala',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _jobInk,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rateCard() {
    return _outlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Daily Rate'),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Rs. ',
                style: TextStyle(
                  color: _jobInk,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _rateController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    color: _jobInk,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const Text(
                '/ day',
                style: TextStyle(color: Color(0xFF68766F), fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentCard() {
    return _outlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _label('Payment Method')),
              const Icon(Icons.credit_card, color: _jobGreen, size: 20),
            ],
          ),
          const SizedBox(height: 5),
          for (final method in [
            'Cash',
            'Direct Bank Transfer',
            'Cash or Bank Transfer',
          ])
            _paymentOption(method),
        ],
      ),
    );
  }

  Widget _paymentOption(String method) {
    final selected = _paymentMethod == method;
    return InkWell(
      onTap: () => setState(() => _paymentMethod = method),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFFFDFCF8),
          borderRadius: BorderRadius.circular(18),
          border: selected
              ? Border.all(color: const Color(0xFFA8C1B2), width: 1.6)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? _jobGreen : const Color(0xFFD7DDE3),
              size: 20,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                method,
                style: const TextStyle(
                  color: _jobInk,
                  fontSize: 12,
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
