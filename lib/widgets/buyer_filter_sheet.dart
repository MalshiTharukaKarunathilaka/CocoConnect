import 'package:flutter/material.dart';
import 'nearby_filter.dart';
import 'owner_widgets.dart';

/// What the estate owner's Interested Buyers list shows.
typedef BuyerFilter = ({String sort, int? radiusKm, bool matchHarvest});

/// Sort, distance and "match my harvest" in one sheet. Returns the new
/// choice, or null if dismissed.
Future<BuyerFilter?> showBuyerFilterSheet(
  BuildContext context,
  BuyerFilter current,
) {
  return showModalBottomSheet<BuyerFilter>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _BuyerFilterSheet(current: current),
  );
}

class _BuyerFilterSheet extends StatefulWidget {
  final BuyerFilter current;

  const _BuyerFilterSheet({required this.current});

  @override
  State<_BuyerFilterSheet> createState() => _BuyerFilterSheetState();
}

class _BuyerFilterSheetState extends State<_BuyerFilterSheet> {
  late String _sort = widget.current.sort;
  late int? _radius = widget.current.radiusKm;
  late bool _match = widget.current.matchHarvest;

  static const Map<String, String> _sorts = {
    'price': 'Best price',
    'date': 'Earliest pickup date',
    'nearest': 'Nearest location',
  };

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        letterSpacing: 0.6,
        fontWeight: FontWeight.bold,
        color: kOwnerMuted,
      ),
    ),
  );

  Widget _chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onTap(),
    selectedColor: kOwnerGreen,
    labelStyle: TextStyle(
      fontWeight: FontWeight.w600,
      color: selected ? Colors.white : kOwnerInk,
    ),
    showCheckmark: false,
    backgroundColor: Colors.white,
    side: BorderSide(color: selected ? kOwnerGreen : kOwnerBorder),
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filter Interested Buyers',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: kOwnerInk,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _sort = 'price';
                    _radius = null;
                    _match = true;
                  }),
                  style: TextButton.styleFrom(foregroundColor: kOwnerGreen),
                  child: const Text('Reset'),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: kOwnerGreen,
              value: _match,
              onChanged: (value) => setState(() => _match = value),
              title: const Text(
                'Match my harvest',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Only buyers who need your nuts on your available date or up '
                'to 7 days before it, and no more than you have.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            _title('SORT BY'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in _sorts.entries)
                  _chip(
                    entry.value,
                    _sort == entry.key,
                    () => setState(() => _sort = entry.key),
                  ),
              ],
            ),
            _title('DISTANCE'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final int? km in kRadiusOptions)
                  _chip(
                    km == null ? 'Any distance' : 'Within $km km',
                    _radius == km,
                    () => setState(() => _radius = km),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            OwnerPrimaryButton(
              label: 'Apply',
              onPressed: () => Navigator.pop(context, (
                sort: _sort,
                radiusKm: _radius,
                matchHarvest: _match,
              )),
            ),
          ],
        ),
      ),
    );
  }
}
