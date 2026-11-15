import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'job_details_screen.dart';

class DayEstatesScreen extends StatefulWidget {
  final DateTime date;
  final JobCategory? category;
  const DayEstatesScreen({super.key, required this.date, this.category});

  @override
  State<DayEstatesScreen> createState() => _DayEstatesScreenState();
}

class _DayEstatesScreenState extends State<DayEstatesScreen> {
  late JobCategory? _category = widget.category;

  @override
  Widget build(BuildContext context) {
    final list = estatesForDate(widget.date, _category);
    final jobCount = list.fold<int>(
      0,
      (n, e) =>
          n +
          jobsForEstate(e.id)
              .where((j) => _category == null || j.category == _category)
              .length,
    );
    final nearest = list.isEmpty
        ? 0.0
        : list.map((e) => e.distanceKm).reduce((a, b) => a < b ? a : b);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                if (Navigator.of(context).canPop())
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.arrow_back, size: 24),
                    ),
                  ),
                const Expanded(child: ScreenTitle('Jobs for the Day')),
                AppPill('$jobCount jobs\nnear you', bg: AppColors.mintSoft),
              ],
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      _chip(null),
                      for (final c in JobCategory.values) _chip(c),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('$nearest km from your current location',
                            style: const TextStyle(fontSize: 15, color: AppColors.muted)),
                      ),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                            color: AppColors.sand,
                            borderRadius: BorderRadius.circular(999)),
                        child: const Text('Open map',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _RadiusCard(estates: list),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('${worker.district} - ${formatDMY(widget.date)}',
                    style: const TextStyle(fontSize: 18, color: AppColors.muted)),
              ],
            ),
            const SizedBox(height: 14),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text('No estates have published jobs for this day.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: AppColors.muted)),
              )
            else
              for (final e in list) ...[
                _estateTile(e),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  Widget _chip(JobCategory? c) {
    final active = _category == c;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => setState(() => _category = c),
        child: Container(
          constraints: const BoxConstraints(minWidth: 62),
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.primary, width: 1.5),
          ),
          child: c == null
              ? Text('All',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : AppColors.primary))
              : Icon(c.icon, size: 24, color: active ? Colors.white : AppColors.primary),
        ),
      ),
    );
  }

  Widget _estateTile(Estate e) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => JobDetailsScreen(date: widget.date, estateId: e.id),
      )),
      child: AppCard(
        child: Row(
          children: [
            InitialsBox(e.initials, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.name,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text)),
                  const SizedBox(height: 2),
                  Text('Owner: ${e.owner}',
                      style: const TextStyle(fontSize: 15, color: AppColors.muted)),
                ],
              ),
            ),
            for (final c in categoriesForEstate(e.id)) IconBubble(c.icon),
          ],
        ),
      ),
    );
  }
}

/// Stand-in for the map: concentric match zones and estate labels.
/// Replace with google_maps_flutter / flutter_map when you wire up a real map.
class _RadiusCard extends StatelessWidget {
  final List<Estate> estates;
  const _RadiusCard({required this.estates});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 330,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFDDEBDD),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _whitePill(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                          color: AppColors.primary, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  const Text('5 km Standard Base Radius', style: _pillText),
                ],
              )),
              _whitePill(const Text('Kurunegala Rural', style: _pillText)),
            ],
          ),
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _circle(200),
                _circle(130),
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.location_on, size: 18, color: Colors.white),
                ),
                for (var i = 0; i < estates.length && i < 2; i++)
                  Positioned(
                    top: 10.0 + i * 36,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(999)),
                      child: Text(estates[i].name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xF2FFFFFF), borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, size: 22, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(
                    child: Text('Active Match Zone: 0 - 5 km', style: _pillText)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(999)),
                  child: const Text('No Surcharge',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _pillText =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text);

  Widget _whitePill(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
            color: const Color(0xE6FFFFFF), borderRadius: BorderRadius.circular(999)),
        child: child,
      );

  Widget _circle(double size) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
            color: Color(0x2E256445), shape: BoxShape.circle),
      );
}
