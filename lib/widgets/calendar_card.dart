import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models.dart';
import '../theme.dart';
import 'ui.dart';

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
const _dow = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

class CalendarCard extends StatefulWidget {
  final Map<String, String> accepted; // dateKey -> jobId
  final JobCategory? category;
  final ValueChanged<DateTime> onSelectDay;
  const CalendarCard({
    super.key,
    required this.accepted,
    required this.category,
    required this.onSelectDay,
  });

  @override
  State<CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends State<CalendarCard> {
  late DateTime _month = DateTime(today().year, today().month);

  void _shift(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  /// 6 weeks, Monday first, including leading/trailing days.
  List<DateTime> _cells() {
    final first = DateTime(_month.year, _month.month, 1);
    final offset = first.weekday - 1; // Monday = 0
    return List.generate(
        42, (i) => DateTime(_month.year, _month.month, 1 - offset + i));
  }

  @override
  Widget build(BuildContext context) {
    final now = today();
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    Text('${_months[_month.month - 1]} ${_month.year}',
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.text)),
                    const AppPill('Harvest Peak', bg: AppColors.sand, fg: AppColors.muted),
                  ],
                ),
              ),
              InkWell(
                onTap: () => _shift(-1),
                child: const Padding(
                    padding: EdgeInsets.all(4), child: Icon(Icons.chevron_left, size: 22)),
              ),
              InkWell(
                onTap: () => setState(() => _month = DateTime(now.year, now.month)),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: AppColors.sand, borderRadius: BorderRadius.circular(999)),
                  child: const Text('Today',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
              InkWell(
                onTap: () => _shift(1),
                child: const Padding(
                    padding: EdgeInsets.all(4), child: Icon(Icons.chevron_right, size: 22)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final d in _dow)
                Expanded(
                  child: Center(
                    child: Text(d, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (_, i) => _buildCell(_cells()[i], now),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Legend(color: AppColors.holiday, label: 'Holidays', square: true),
                _Legend(color: AppColors.booked, label: 'Booked'),
                _Legend(color: AppColors.primary, label: 'Available'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(DateTime d, DateTime now) {
    final inMonth = d.month == _month.month;
    final holiday = inMonth && isHoliday(d);
    final hasJobs = inMonth && estatesForDate(d, widget.category).isNotEmpty;
    final booked = inMonth && widget.accepted.containsKey(dateKey(d));
    final isToday = d == now;
    final past = d.isBefore(now);
    final selectable = hasJobs && !holiday;

    Color textColor = AppColors.text;
    if (!inMonth || (past && !holiday)) textColor = AppColors.faint;

    return InkWell(
      onTap: selectable ? () => widget.onSelectDay(d) : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: holiday
              ? AppColors.holiday
              : (isToday ? AppColors.mint : Colors.transparent),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${d.day}', style: TextStyle(fontSize: 16, color: textColor)),
            const SizedBox(height: 3),
            SizedBox(
              height: 6,
              child: booked
                  ? const _Dot(AppColors.booked)
                  : (hasJobs ? const _Dot(AppColors.primary) : null),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot(this.color);

  @override
  Widget build(BuildContext context) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final bool square;
  const _Legend({required this.color, required this.label, this.square = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(square ? 3 : 6),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ],
    );
  }
}
