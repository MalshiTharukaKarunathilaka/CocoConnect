import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/mock_data.dart';
import '../state/jobs_state.dart';
import '../theme.dart';
import 'dashboard_screen.dart';
import 'day_estates_screen.dart';
import 'simple_tabs.dart';

/// Bottom-tab shell. The Dashboard and Jobs tabs each own a nested Navigator,
/// so the tab bar stays visible while moving between day / estate / job screens.
class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<AppNav>();

    return Scaffold(
      body: IndexedStack(
        index: nav.tabIndex,
        children: [
          _TabNavigator(
            navKey: nav.dashboardKey,
            builder: (_) => const DashboardScreen(),
          ),
          _TabNavigator(
            navKey: nav.jobsKey,
            builder: (_) => DayEstatesScreen(date: today()),
          ),
          const NotificationScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: nav.tabIndex,
        onTap: (i) {
          if (i == nav.tabIndex && i < 2) {
            // Tapping the active tab returns to its first screen.
            (i == 0 ? nav.dashboardKey : nav.jobsKey)
                .currentState
                ?.popUntil((r) => r.isFirst);
          }
          nav.setTab(i);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.bg,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.text,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view_rounded),
              label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.work_outline),
              activeIcon: Icon(Icons.work),
              label: 'Jobs'),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined),
              activeIcon: Icon(Icons.notifications),
              label: 'Notification'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_circle_outlined),
              activeIcon: Icon(Icons.account_circle),
              label: 'Profile'),
        ],
      ),
    );
  }
}

class _TabNavigator extends StatelessWidget {
  final GlobalKey<NavigatorState> navKey;
  final WidgetBuilder builder;
  const _TabNavigator({required this.navKey, required this.builder});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navKey,
      onGenerateRoute: (settings) =>
          MaterialPageRoute(settings: settings, builder: builder),
    );
  }
}
