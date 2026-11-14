import 'package:flutter/material.dart';
import 'fertilizer_chrome.dart';
import 'fertilizer_complaints_page.dart';
import 'fertilizer_map_page.dart';
import 'fertilizer_requests_page.dart';

/// Owner fertilizer shell — same tabs as the HTML demo bottom nav.
class FertilizerHub extends StatefulWidget {
  const FertilizerHub({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<FertilizerHub> createState() => _FertilizerHubState();
}

class _FertilizerHubState extends State<FertilizerHub> {
  late int _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 4);
  }

  /// Same as the HTML demo: Hub=all, Suppliers=shops, Government=CDO map.
  String get _channel {
    if (_tab == 1) return 'private';
    if (_tab == 2) return 'gov';
    return 'all';
  }

  @override
  Widget build(BuildContext context) {
    return FertPage(
      title: _tabTitle,
      subtitle: 'FERTILIZER \u00b7 ESTATE OWNER',
      showLogout: true,
      bottom: FertTabBar(
        items: const [
          (Icons.home_outlined, 'Hub'),
          (Icons.grid_view_rounded, 'Suppliers'),
          (Icons.account_balance_outlined, 'Government'),
          (Icons.schedule, 'Requests'),
          (Icons.flag_outlined, 'Complaints'),
        ],
        current: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
      child: _body(),
    );
  }

  String get _tabTitle {
    switch (_tab) {
      case 1:
        return 'Private suppliers';
      case 2:
        return 'Government';
      case 3:
        return 'Requests';
      case 4:
        return 'Complaints';
      default:
        return 'Fertilizer hub';
    }
  }

  Widget _body() {
    if (_tab == 3) return const FertilizerRequestsPage(embedded: true);
    if (_tab == 4) return const FertilizerComplaintsPage(embedded: true);
    // Government = same map + list as demo, filtered to CDO pins only.
    return FertilizerMapPage(
      key: ValueKey('map-$_channel'),
      channel: _channel,
      embedded: true,
    );
  }
}
