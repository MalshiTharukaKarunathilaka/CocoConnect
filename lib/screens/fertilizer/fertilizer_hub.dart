import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../account_dialogs.dart';
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
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Material(
            color: AppColors.cream,
            child: SafeArea(
              child: Column(
                children: [
                  _topBar(),
                  Expanded(child: _body()),
                  _bottomNav(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.line)),
        boxShadow: [
          BoxShadow(
            color: Color(0x10183E29),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (Navigator.of(context).canPop())
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: AppColors.ink),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/branding/kapconnect_logo.png',
                      height: 40,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Text(
                        'KapConnect',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.green,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _tabTitle,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: () => confirmLogOut(context),
            icon: const Icon(Icons.logout, color: AppColors.green, size: 22),
          ),
        ],
      ),
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

  Widget _bottomNav() {
    const items = [
      (Icons.home_outlined, 'Hub'),
      (Icons.grid_view_rounded, 'Suppliers'),
      (Icons.account_balance_outlined, 'Government'),
      (Icons.schedule, 'Requests'),
      (Icons.flag_outlined, 'Complaints'),
    ];
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A183E29),
            blurRadius: 18,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _tab = i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _tab == i
                            ? AppColors.greenSoft
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        items[i].$1,
                        size: 20,
                        color: _tab == i ? AppColors.green : AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[i].$2,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: _tab == i ? AppColors.green : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
