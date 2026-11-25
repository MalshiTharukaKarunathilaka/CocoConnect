import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../models/estate_plants.dart';
import '../../theme/app_theme.dart';
import 'plant_widgets.dart';

/// What the sheet gives back: a saved mark, or a request to delete it.
/// [repeat] is true when the owner wants to keep placing more of the same kind
/// with one tap each.
class PlantSheetResult {
  final PlantMark? mark;
  final bool delete;
  final bool repeat;

  const PlantSheetResult.saved(PlantMark this.mark, {this.repeat = false})
    : delete = false;
  const PlantSheetResult.deleted() : mark = null, delete = true, repeat = false;
}

/// Opens the sheet for a new mark at [point], or to change [existing].
/// One mark is one plant: the sheet asks what it is and how old it is (or, for
/// a pest or weed, how bad it is).
Future<PlantSheetResult?> showPlantSheet(
  BuildContext context, {
  required LatLng point,
  required String newId,
  PlantMark? existing,
  String? presetKind,
}) {
  return showThemedBottomSheet<PlantSheetResult>(
    context: context,
    builder: (_) => _PlantSheet(
      point: point,
      newId: newId,
      existing: existing,
      presetKind: presetKind,
    ),
  );
}

class _PlantSheet extends StatefulWidget {
  final LatLng point;
  final String newId;
  final PlantMark? existing;
  final String? presetKind;

  const _PlantSheet({
    required this.point,
    required this.newId,
    this.existing,
    this.presetKind,
  });

  @override
  State<_PlantSheet> createState() => _PlantSheetState();
}

class _PlantSheetState extends State<_PlantSheet> {
  late String _kind =
      widget.existing?.kind ?? widget.presetKind ?? kPlantKinds.first.id;
  late final TextEditingController _note = TextEditingController(
    text: widget.existing?.note ?? '',
  );
  late String? _age = widget.existing?.age;
  late String? _severity = widget.existing?.severity;
  bool _repeat = false;
  String? _error;

  PlantKind get _info => plantKind(_kind);

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _save() {
    if (_info.isCrop && _age == null) {
      setState(() => _error = 'Choose how old this tree is');
      return;
    }
    if (_info.isThreat && _severity == null) {
      setState(() => _error = 'Choose how bad it is');
      return;
    }
    final PlantMark base =
        widget.existing ??
        PlantMark(
          id: widget.newId,
          kind: _kind,
          lat: widget.point.latitude,
          lng: widget.point.longitude,
          count: 1,
          updated: DateTime.now(),
        );
    Navigator.pop(
      context,
      PlantSheetResult.saved(
        // A mark stands for one plant. Only an older mark made before this
        // rule keeps the larger number it was saved with.
        base.copyWith(
          kind: _kind,
          count: widget.existing?.count ?? 1,
          age: _info.isCrop ? _age : null,
          severity: _info.isThreat ? _severity : null,
          note: _note.text.trim(),
        ),
        repeat: _repeat && widget.existing == null,
      ),
    );
  }

  Future<void> _delete() async {
    final bool? yes = await showThemedDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this mark?'),
        content: Text(
          'This ${_info.name.toLowerCase()} will be removed from your '
          'estate map.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      Navigator.pop(context, const PlantSheetResult.deleted());
    }
  }

  Widget _kindTile(PlantKind k) {
    final bool on = k.id == _kind;
    return Semantics(
      button: true,
      selected: on,
      label: k.name,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() {
          _kind = k.id;
          _error = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 84,
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: on ? AppColors.green : AppColors.line,
              width: on ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlantBadge(kind: k, size: 46),
              const SizedBox(height: 6),
              Text(
                k.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _group(PlantGroup g) {
    final list = kPlantKinds.where((k) => k.group == g).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Text(
            groupTitle(g),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: g == PlantGroup.crop ? AppColors.green : AppColors.danger,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final k in list) _kindTile(k)],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool editing = widget.existing != null;
    final int legacyCount = widget.existing?.count ?? 1;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    editing ? 'Change this mark' : 'Mark one on your estate',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (editing) MarkStatusPill(widget.existing!.status),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${widget.point.latitude.toStringAsFixed(5)}, '
              '${widget.point.longitude.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
            if (legacyCount > 1)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'This older mark stands for $legacyCount plants.',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            for (final g in PlantGroup.values) _group(g),
            const Divider(height: 28),
            if (_info.isCrop) ...[
              const Text(
                'How old is this tree?',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in kAgeRanges)
                    ChoiceChip(
                      label: Text('${a.id} yrs'),
                      selected: _age == a.id,
                      onSelected: (_) => setState(() {
                        _age = a.id;
                        _error = null;
                      }),
                    ),
                ],
              ),
              if (_age != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${ageRange(_age!).stage} · ${ageRange(_age!).note}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ] else ...[
              const Text(
                'How bad is it here?',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in kSeverities)
                    ChoiceChip(
                      label: Text(s),
                      selected: _severity == s,
                      selectedColor: severityColor(s).withValues(alpha: 0.2),
                      onSelected: (_) => setState(() {
                        _severity = s;
                        _error = null;
                      }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              maxLength: 120,
              decoration: const InputDecoration(
                hintText: 'Note (optional), e.g. near the well',
                counterText: '',
              ),
            ),
            if (!editing) ...[
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _repeat,
                onChanged: (v) => setState(() => _repeat = v),
                title: const Text(
                  'Keep adding the same, one tap each',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Then every tap on the map places one more, with no sheet.',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (editing) ...[
                  OutlinedButton.icon(
                    onPressed: _delete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Remove'),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: _save,
                    child: Text(editing ? 'Save changes' : 'Add to my estate'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
