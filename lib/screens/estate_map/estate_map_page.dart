import 'package:flutter/material.dart';

import '../../models/estate_plants.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/owner_service.dart';
import '../../theme/app_theme.dart';
import 'estate_map_view.dart';

/// The key one login's marks are kept under.
String estateMapKeyFor(AppUser? user) => 'u${user?.id ?? 0}';

/// The estate map as a page of its own, opened from the owner dashboard. The
/// first time, it builds the estate's outline from the name, size and place
/// the owner gave at sign-up.
class EstateMapPage extends StatefulWidget {
  const EstateMapPage({super.key});

  @override
  State<EstateMapPage> createState() => _EstateMapPageState();
}

/// Loads this login's marks and, the first time, builds the estate's outline
/// from the name, size and place on the account.
Future<void> ensureEstatePlan() async {
  final AppUser? user = AuthService.currentUser;
  final EstateMapStore store = EstateMapStore.instance;
  await store.load(estateMapKeyFor(user));
  if (store.ready) return;

  Estate? estate;
  try {
    estate = await OwnerService.getEstate();
  } catch (_) {
    // Offline or not set up yet: fall back to what the login knows.
  }
  final String name = (estate?.estateName ?? '').trim();
  await store.setPlan(
    EstatePlan(
      name: name.isEmpty ? 'My estate' : name,
      acres: EstatePlan.acresFrom(estate?.totalLandArea ?? ''),
      lat: user?.latitude ?? LocationService.defaultLatitude,
      lng: user?.longitude ?? LocationService.defaultLongitude,
      place: user?.location ?? estate?.location ?? '',
    ),
  );
}

class _EstateMapPageState extends State<EstateMapPage> {
  late final Future<void> _ready = ensureEstatePlan();

  @override
  Widget build(BuildContext context) {
    return AppThemeScope(
      child: Scaffold(
        backgroundColor: const Color(0xFFEFEFEF),
        body: Center(
          child: Container(
            width: 390,
            height: double.infinity,
            color: const Color(0xFFFCF8EF),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 6, 14, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back,
                              color: AppColors.green),
                        ),
                        Expanded(
                          child: ListenableBuilder(
                            listenable: EstateMapStore.instance,
                            builder: (context, _) {
                              final EstatePlan? p = EstateMapStore.instance.plan;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p?.name ?? 'Estate map',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    p == null
                                        ? 'Mark what grows on your land'
                                        : '${p.acres.toStringAsFixed(p.acres % 1 == 0 ? 0 : 1)} acres · mark what grows on your land',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<void>(
                      future: _ready,
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        return const EstateMapView();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
