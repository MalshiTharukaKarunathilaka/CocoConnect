import 'package:flutter/material.dart';

import '../../models/estate_plants.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../auth_gate.dart';
import '../location_picker_page.dart';
import 'estate_map_page.dart';
import 'estate_map_preview.dart';
import 'estate_map_view.dart';
import 'plant_widgets.dart';

/// Shown once, right after a land owner signs up:
/// 1. confirm the estate (name, size, place),
/// 2. mark what grows on it,
/// 3. review, then go to the dashboard.
/// Every step can be skipped; the map is always reachable from the dashboard.
class EstateSetupFlow extends StatefulWidget {
  final AppUser user;
  final String estateName;
  final String areaText;
  final PickedLocation location;

  const EstateSetupFlow({
    super.key,
    required this.user,
    required this.estateName,
    required this.areaText,
    required this.location,
  });

  @override
  State<EstateSetupFlow> createState() => _EstateSetupFlowState();
}

class _EstateSetupFlowState extends State<EstateSetupFlow> {
  final EstateMapStore _store = EstateMapStore.instance;
  late final TextEditingController _name = TextEditingController(
    text: widget.estateName,
  );
  late final TextEditingController _area = TextEditingController(
    text: widget.areaText,
  );
  late PickedLocation _loc = widget.location;

  int _step = 0;
  bool _loaded = false;
  String? _error;

  static const List<String> _titles = [
    'Your estate',
    'Mark what grows',
    'All set',
  ];

  @override
  void initState() {
    super.initState();
    _store.load(estateMapKeyFor(widget.user)).then((_) {
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    super.dispose();
  }

  void _finish() => openHomeFor(context, widget.user);

  Future<void> _changePlace() async {
    final PickedLocation? p = await pickLocation(context, initial: _loc);
    if (p != null && mounted) setState(() => _loc = p);
  }

  Future<void> _saveEstate() async {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give your estate a name');
      return;
    }
    final double acres = EstatePlan.acresFrom(_area.text, fallback: 0);
    if (acres <= 0) {
      setState(() => _error = 'Enter the size, for example 5 acres');
      return;
    }
    await _store.setPlan(
      EstatePlan(
        name: name,
        acres: acres,
        lat: _loc.latitude,
        lng: _loc.longitude,
        place: _loc.name,
      ),
    );
    if (mounted) {
      setState(() {
        _error = null;
        _step = 1;
      });
    }
  }

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
                  _header(),
                  Expanded(
                    child: !_loaded
                        ? const Center(child: CircularProgressIndicator())
                        : AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: KeyedSubtree(
                              key: ValueKey(_step),
                              child: switch (_step) {
                                0 => _estateStep(),
                                1 => _mapStep(),
                                _ => _doneStep(),
                              },
                            ),
                          ),
                  ),
                  _footer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 10, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Step ${_step + 1} of 3',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              TextButton(
                onPressed: _finish,
                child: const Text('Skip for now'),
              ),
            ],
          ),
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 5,
                    margin: EdgeInsets.only(right: i < 2 ? 6 : 14),
                    decoration: BoxDecoration(
                      color: i <= _step ? AppColors.green : AppColors.line,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _titles[_step],
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _footer() => ListenableBuilder(
    listenable: _store,
    builder: (context, _) => _footerBar(),
  );

  Widget _footerBar() {
    final bool onMap = _step == 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          if (_step > 0) ...[
            OutlinedButton(
              onPressed: () => setState(() => _step -= 1),
              child: const Text('Back'),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed: switch (_step) {
                0 => _saveEstate,
                1 => () => setState(() => _step = 2),
                _ => _finish,
              },
              child: Text(switch (_step) {
                0 => 'Next: mark my trees',
                1 => onMap && _store.marks.isEmpty
                    ? 'Skip marking for now'
                    : 'Next: review',
                _ => 'Go to my dashboard',
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ---- step 1: the estate ----

  Widget _estateStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF256B45), Color(0xFF5FA47B)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              PlantBadge(kind: plantKind('coconut'), size: 84),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Welcome, ${widget.user.name.trim().split(' ').first}! '
                  'Let us draw your estate. Next you can mark every tree, '
                  'pest and weed on it.',
                  style: const TextStyle(color: Colors.white, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text('Estate name',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: _name,
          onChanged: (_) => setState(() => _error = null),
          decoration: const InputDecoration(
            hintText: 'e.g. Green Valley Estate',
            prefixIcon: Icon(Icons.landscape_outlined),
          ),
        ),
        const SizedBox(height: 14),
        const Text('Total land area',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: _area,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() => _error = null),
          decoration: const InputDecoration(
            hintText: 'e.g. 5 acres',
            prefixIcon: Icon(Icons.crop_square_outlined),
          ),
        ),
        const SizedBox(height: 14),
        const Text('Where is it?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 6),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _changePlace,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.place, color: AppColors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _loc.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Text(
                    'Change on map',
                    style: TextStyle(
                      color: AppColors.green,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Pick the middle of your estate. The next step draws its outline '
          'around this point.',
          style: TextStyle(fontSize: 11.5, color: AppColors.muted),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  // ---- step 2: the map ----

  Widget _mapStep() => const EstateMapView();

  // ---- step 3: review ----

  Widget _doneStep() {
    final EstatePlan p = _store.plan!;
    final threats = _store.threatSpots;
    Widget big(String n, String label, Color c) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(n,
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w900, color: c)),
            Text(label,
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          ],
        ),
      ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      children: [
        Text(
          p.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        Text(
          '${p.acres.toStringAsFixed(p.acres % 1 == 0 ? 0 : 1)} acres'
          '${p.place.isEmpty ? '' : ' · ${p.place}'}',
          style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        // Everything that was marked, drawn on the estate.
        const EstateMapPreview(load: false, height: 220),
        const SizedBox(height: 14),
        Row(
          children: [
            big('${_store.totalTrees}', 'trees marked', AppColors.green),
            const SizedBox(width: 10),
            big('$threats', 'pest / weed spots', AppColors.danger),
          ],
        ),
        const SizedBox(height: 16),
        for (final k in kPlantKinds)
          if (_store.countOf(k.id) > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  PlantBadge(kind: k, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(k.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Text('${_store.countOf(k.id)}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
        if (_store.marks.isEmpty)
          const Text(
            'You have not marked anything yet. No problem: open "Estate map" '
            'on your dashboard whenever you are walking your land.',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warningSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.hourglass_top, color: AppColors.warning, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Every mark waits for your CDO to check it. That check is '
                  'not switched on yet, so for now your marks are kept on this '
                  'phone.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
