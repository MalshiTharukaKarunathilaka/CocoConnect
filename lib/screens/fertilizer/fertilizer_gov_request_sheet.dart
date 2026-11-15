import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'fertilizer_data.dart';

/// Government / CCB order form.
/// Profile fields are locked — wrong data must be fixed in Profile, then return.
/// Order stays Pending Ack until the CDO acknowledges.
/// Owner can pick one or more fertilizer types (ERP + UREA, etc.).
class FertilizerGovRequestSheet extends StatefulWidget {
  const FertilizerGovRequestSheet({
    super.key,
    this.place,
    this.preselectedTypes = const {},
  });

  final FertPlace? place;
  final Set<String> preselectedTypes;

  @override
  State<FertilizerGovRequestSheet> createState() =>
      _FertilizerGovRequestSheetState();
}

class _FertilizerGovRequestSheetState extends State<FertilizerGovRequestSheet> {
  late final Map<String, int> _qtyByType;
  String? _dropdownPick;
  bool _nicConfirmed = true;
  bool _titleConfirmed = true;

  FertPlace get _place =>
      widget.place ??
      FertilizerStore.instance.places.firstWhere((p) => p.isGov);

  @override
  void initState() {
    super.initState();
    _qtyByType = {};
    final codes = _place.fertilizerCodes.toSet();
    final preset = widget.preselectedTypes
        .map((t) => t.toUpperCase())
        .where(codes.contains)
        .toSet();
    // Why: map filter can pre-tick types; otherwise start with the first CCB item.
    final start =
        preset.isNotEmpty ? preset : {_place.fertilizerCodes.first};
    for (final code in start) {
      _qtyByType[code] = 12;
    }
  }

  List<String> get _selectedCodes => _qtyByType.keys.toList()..sort();

  List<String> get _addableCodes => _place.fertilizerCodes
      .where((c) => !_qtyByType.containsKey(c))
      .toList();

  void _addFromDropdown(String? code) {
    if (code == null) return;
    setState(() {
      _qtyByType[code] = 12;
      _dropdownPick = null;
    });
  }

  void _submit() {
    if (!_nicConfirmed || !_titleConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confirm NIC and land title copies from your profile.'),
        ),
      );
      return;
    }
    if (_qtyByType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one fertilizer type.')),
      );
      return;
    }

    final store = FertilizerStore.instance;
    final lines = <CartLine>[];
    for (final e in _qtyByType.entries) {
      final item = _place.itemForType(e.key);
      if (item == null || e.value < 1) continue;
      lines.add(CartLine(item: item, qty50: e.value));
    }
    if (lines.isEmpty) return;

    final productLabel =
        lines.map((l) => '${l.item.type} ${l.item.name} (${l.qty50} bags)').join(', ');
    final totalBags = lines.fold(0, (s, l) => s + l.qty50);
    final totalPrice = lines.fold(0, (s, l) => s + l.lineTotal);

    store.placeGovRequest(
      FertGovRequest(
        id: 'FR-${1000 + store.govRequests.length + 1}',
        owner: FertOwnerProfile.estateName,
        fertilizer: productLabel,
        requested: totalBags,
        status: 'Pending Ack',
        cdo: _place.who,
        date: DateTime.now(),
        district: FertOwnerProfile.district,
      ),
    );
    store.placeOrder(
      FertOrder(
        id: store.nextId(),
        placeId: _place.id,
        company: _place.company,
        agent: _place.who,
        owner: FertOwnerProfile.estateName,
        product: productLabel,
        items: lines,
        qty50: totalBags,
        price: totalPrice,
        preferredDate: DateTime.now().add(const Duration(days: 3)),
        slot: 'Morning 8–11',
        status: 'Pending Ack',
        message:
            'Government form submitted · awaits CDO acknowledgement · '
            '${FertOwnerProfile.acres} acres · NIC on file · '
            '${_selectedCodes.join(' + ')}',
      ),
    );
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Government order sent · Pending Ack until CDO acknowledges',
        ),
      ),
    );
  }

  Widget _lockedField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF0F0F0),
          isDense: true,
          suffixIcon: const Icon(
            Icons.lock_outline,
            size: 18,
            color: AppColors.muted,
          ),
        ),
        child: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Government order form',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.green,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.ink),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warningSoft,
                    borderRadius: BorderRadius.circular(AppRadius.field),
                    border: Border.all(color: const Color(0xFFE8D9B0)),
                  ),
                  child: const Text(
                    'Estate details are locked from your profile. '
                    'If anything is wrong, edit it in Profile and come back. '
                    'You can request more than one fertilizer type. '
                    'The order proceeds only after the CDO acknowledges this form.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.warning),
                  ),
                ),
                const SizedBox(height: 14),
                _lockedField('Estate owner name', FertOwnerProfile.ownerName),
                _lockedField('Estate size (acres)', FertOwnerProfile.acres),
                _lockedField('District', FertOwnerProfile.district),
                _lockedField('NIC (from profile)', FertOwnerProfile.nicOnFile),
                _lockedField(
                  'Land title (from profile)',
                  FertOwnerProfile.landTitleOnFile,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _nicConfirmed,
                  activeColor: AppColors.green,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'Use NIC copy from my profile',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  onChanged: (v) => setState(() => _nicConfirmed = v ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _titleConfirmed,
                  activeColor: AppColors.green,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'Attach recent land title copy from my profile',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  onChanged: (v) =>
                      setState(() => _titleConfirmed = v ?? false),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Fertilizer types',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _dropdownPick,
                  decoration: const InputDecoration(
                    labelText: 'Add fertilizer type',
                    isDense: true,
                  ),
                  hint: Text(
                    _addableCodes.isEmpty
                        ? 'All CCB types are in this form'
                        : 'Add another type (e.g. ERP + UREA)',
                    style: const TextStyle(fontSize: 13),
                  ),
                  items: [
                    for (final c in _addableCodes)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: _addableCodes.isEmpty ? null : _addFromDropdown,
                ),
                const SizedBox(height: 10),
                for (final code in _selectedCodes)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.field),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.greenSoft,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            code,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.green,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _place.itemForType(code)?.name ?? code,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          onPressed: () =>
                              setState(() => _qtyByType.remove(code)),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                        IconButton(
                          onPressed: (_qtyByType[code] ?? 1) <= 1
                              ? null
                              : () => setState(
                                    () => _qtyByType[code] =
                                        (_qtyByType[code] ?? 1) - 1,
                                  ),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          '${_qtyByType[code] ?? 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.green,
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(
                            () => _qtyByType[code] =
                                (_qtyByType[code] ?? 1) + 1,
                          ),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: const Text('Submit for CDO acknowledgement'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
