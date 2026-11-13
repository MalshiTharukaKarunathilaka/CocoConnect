import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../account_dialogs.dart';
import 'fertilizer_complaints_page.dart';
import 'fertilizer_gov_request_sheet.dart';
import 'fertilizer_map_page.dart';
import 'fertilizer_requests_page.dart';

/// Owner fertilizer shell — same tabs as the HTML demo bottom nav.
/// Why: one place for map filters + requests + complaints so the flow feels like the demo.
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

  /// Map channel for tabs 0/1/2 (hub / shops / government).
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
                Text(
                  'KapConnect',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.green,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  'Fertilizer hub',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Switch role / log out',
            onPressed: () => confirmLogOut(context),
            icon: const Icon(Icons.logout, color: AppColors.green, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_tab == 3) return const FertilizerRequestsPage(embedded: true);
    if (_tab == 4) return const FertilizerComplaintsPage(embedded: true);
    if (_tab == 2) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'ESTATE OWNER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.green,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Government programme',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Check demo CDO-area stock and submit a quantity request. Map pins also filter to government.',
            style: TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () async {
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const FertilizerGovRequestSheet(),
              );
              setState(() {});
            },
            child: const Text('Request Board fertilizer'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Government suppliers on the map',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 420,
            child: FertilizerMapPage(
              key: const ValueKey('map-gov-embedded'),
              channel: 'gov',
              embedded: true,
            ),
          ),
        ],
      );
    }
    return FertilizerMapPage(
      key: ValueKey('map-$_channel'),
      channel: _channel,
      embedded: true,
    );
  }

  Widget _bottomNav() {
    const items = [
      (Icons.home_outlined, 'Fertilizer hub'),
      (Icons.grid_view_rounded, 'Private suppliers'),
      (Icons.account_balance_outlined, 'Government programme'),
      (Icons.schedule, 'My requests & messages'),
      (Icons.flag_outlined, 'Quality complaints'),
    ];
    return Container(
      height: 68,
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
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 8.5,
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
