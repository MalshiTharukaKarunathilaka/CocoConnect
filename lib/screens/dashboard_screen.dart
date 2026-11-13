import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/mock_data.dart';
import '../models.dart';
import '../state/jobs_state.dart';
import '../theme.dart';
import '../widgets/calendar_card.dart';
import '../widgets/ui.dart';
import 'day_estates_screen.dart';
import 'my_jobs_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _lang = 'EN';
  JobCategory? _category; // null = all

  void _openDay(DateTime date) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DayEstatesScreen(date: date, category: _category),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final accepted = context.watch<JobsState>().accepted;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _topBar(),
            const SizedBox(height: 14),
            _profileCard(),
            const SizedBox(height: 14),
            AppButton(
              'Search Jobs',
              outline: true,
              onPressed: () => _openDay(today()),
            ),
            const SizedBox(height: 14),
            AppButton(
              'My Jobs',
              outline: true,
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const MyJobsScreen())),
            ),
            const SizedBox(height: 14),
            for (final c in JobCategory.values) ...[
              _categoryRow(c),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 4),
            CalendarCard(
              accepted: accepted,
              category: _category,
              onSelectDay: _openDay,
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        const Icon(Icons.arrow_back, size: 24),
        const SizedBox(width: 12),
        const Expanded(
          child: Text('KapConnect',
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
              color: AppColors.sand, borderRadius: BorderRadius.circular(999)),
          child: Row(
            children: [
              for (final l in ['EN', 'SI', 'TA'])
                GestureDetector(
                  onTap: () => setState(() => _lang = l),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _lang == l ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(l,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _lang == l ? Colors.white : AppColors.text)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => context.read<AppNav>().setTab(3),
          child: Container(
            width: 40,
            height: 40,
            decoration:
                const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.person, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _profileCard() {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipOval(
                child: Image.network(
                  'https://i.pravatar.cc/200?img=12',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 80,
                    height: 80,
                    color: AppColors.sand,
                    child: const Icon(Icons.person, size: 40, color: AppColors.primary),
                  ),
                ),
              ),
              if (worker.verified)
                const Positioned(
                  left: -4,
                  bottom: -4,
                  child: Icon(Icons.verified, size: 26, color: AppColors.primary),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(worker.name,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: AppColors.sand, borderRadius: BorderRadius.circular(999)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 14, color: Color(0xFFF5A25D)),
                          const SizedBox(width: 4),
                          Text('${worker.rating} (${worker.ratingCount})',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(worker.district,
                        style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryRow(JobCategory c) {
    final active = _category == c;
    return GestureDetector(
      onTap: () => setState(() => _category = active ? null : c),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: active ? AppColors.primary : Colors.transparent, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: AppColors.sand, borderRadius: BorderRadius.circular(14)),
              child: Icon(c.icon, size: 24, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(c.label,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
            ),
            if (active)
              const Icon(Icons.check_circle, size: 22, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
