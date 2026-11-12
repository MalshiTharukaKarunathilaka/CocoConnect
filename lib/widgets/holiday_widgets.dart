import 'package:flutter/material.dart';
import '../services/holiday_service.dart';
import '../theme/app_theme.dart';

/// Small gold flag for a holiday on a calendar day.
class HolidayFlag extends StatelessWidget {
  final bool onDark;
  final double size;

  const HolidayFlag({super.key, this.onDark = false, this.size = 12});

  @override
  Widget build(BuildContext context) => Icon(
    Icons.flag_rounded,
    size: size,
    color: onDark ? AppColors.gold : AppColors.warning,
  );
}

/// "Holiday" entry for a calendar legend.
class HolidayLegend extends StatelessWidget {
  const HolidayLegend({super.key});

  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      HolidayFlag(size: 13),
      SizedBox(width: 5),
      Text('Holiday', style: TextStyle(fontSize: 11.5, color: AppColors.ink)),
    ],
  );
}

/// The holiday's name for a selected day, as a chip. Nothing when it is not a holiday.
class HolidayNote extends StatelessWidget {
  final DateTime day;

  const HolidayNote(this.day, {super.key});

  @override
  Widget build(BuildContext context) {
    final Holiday? holiday = HolidayService.of(day);
    if (holiday == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HolidayFlag(),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              holiday.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Redraws its [builder] when holidays for a new year arrive, and asks for the
/// year of every month it shows.
class HolidayListener extends StatelessWidget {
  final Iterable<int> years;
  final WidgetBuilder builder;

  const HolidayListener({
    super.key,
    required this.years,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    for (final int year in years) {
      HolidayService.ensure(year);
    }
    return ValueListenableBuilder<int>(
      valueListenable: HolidayService.revision,
      builder: (context, _, _) => builder(context),
    );
  }
}
