import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_theme.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_data.dart';

const List<String> _districts = [
  'Kurunegala',
  'Puttalam',
  'Gampaha',
  'Colombo',
  'Kandy',
  'Matale',
  'Anuradhapura',
  'Galle',
];

const List<String> _cdoAreas = [
  'CDO - Mawathagama',
  'CDO - Pannala',
  'CDO - Narammala',
  'CDO - Area 01 (demo)',
];

/// The small pop-up shown after a government order is sent.
Future<void> showGovSentDialog(BuildContext context, FertGovRequest r) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      contentPadding: const EdgeInsets.fromLTRB(22, 22, 22, 6),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.greenSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: AppColors.green, size: 34),
          ),
          const SizedBox(height: 14),
          const Text(
            'Order sent',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Your order ${r.id} is sent for ${r.cdo} approval.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.35),
          ),
          const SizedBox(height: 6),
          Text(
            '${r.fertilizer}\n${r.requested} bag${r.requested == 1 ? '' : 's'} in total. You can follow it in My orders.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.only(bottom: 14),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.green,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: const StadiumBorder(),
          ),
          onPressed: () => Navigator.pop(ctx),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: Text('OK'),
          ),
        ),
      ],
    ),
  );
}

/// "Submit a fertilizer request": the form for a government supplier.
/// Pops with the new [FertGovRequest] once it is sent.
class FertilizerGovOrderForm extends StatefulWidget {
  const FertilizerGovOrderForm({super.key, required this.place, required this.draft});

  final FertPlace place;
  final GovOrderDraft draft;

  @override
  State<FertilizerGovOrderForm> createState() => _FertilizerGovOrderFormState();
}

class _FertilizerGovOrderFormState extends State<FertilizerGovOrderForm> {
  final _estate = TextEditingController(text: 'Your Estate');
  final _acres = TextEditingController(text: '8');
  String _district = 'Kurunegala';
  late String _cdo;
  XFile? _nic;
  XFile? _title;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cdo = _cdoAreas.contains(widget.place.who) ? widget.place.who : _cdoAreas.first;
  }

  @override
  void dispose() {
    _estate.dispose();
    _acres.dispose();
    super.dispose();
  }

  Future<void> _pick(bool nic) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.green),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.green),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final f = await ImagePicker().pickImage(source: source, imageQuality: 75);
      if (f == null || !mounted) return;
      setState(() {
        if (nic) {
          _nic = f;
        } else {
          _title = f;
        }
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the photo. Please try again.')),
      );
    }
  }

  void _submit() {
    final acres = double.tryParse(_acres.text.trim()) ?? 0;
    String? err;
    if (_estate.text.trim().isEmpty) {
      err = 'Enter your estate name';
    } else if (acres <= 0) {
      err = 'Enter the estate size in acres';
    } else if (_nic == null) {
      err = 'Attach a copy of your NIC';
    } else if (_title == null) {
      err = 'Attach a recent copy of your land title';
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    final store = FertilizerStore.instance;
    final req = FertGovRequest(
      id: 'FR-${1000 + store.govRequests.length + 1}',
      owner: 'Your Estate',
      fertilizer: widget.draft.summary,
      requested: widget.draft.bags,
      status: 'Pending Ack',
      cdo: _cdo,
      date: DateTime.now(),
      district: _district,
      estateName: _estate.text.trim(),
      acres: acres,
      nicCopy: _nic!.name,
      landTitleCopy: _title!.name,
      outlet: widget.place.company,
      preferred: '${shortDate(widget.draft.date)} \u00b7 ${widget.draft.slot}',
    );
    store.placeGovRequest(req);
    Navigator.pop(context, req);
  }

  InputDecoration _dec({String? hint}) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.green, width: 1.6),
    ),
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        color: AppColors.muted,
      ),
    ),
  );

  Widget _attach(String title, String hint, XFile? file, bool nic) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _pick(nic),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: file == null ? Colors.white : AppColors.greenSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: file == null ? AppColors.line : AppColors.green,
            width: file == null ? 1 : 1.4,
          ),
        ),
        child: Row(
          children: [
            if (file == null)
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.upload_file, color: AppColors.green),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(file.path),
                  width: 46,
                  height: 46,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 46,
                    height: 46,
                    color: Colors.white,
                    child: const Icon(Icons.description_outlined, color: AppColors.green),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    file == null ? hint : file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (file == null)
              const Icon(Icons.add_circle_outline, color: AppColors.green)
            else
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() {
                  if (nic) {
                    _nic = null;
                  } else {
                    _title = null;
                  }
                }),
                icon: const Icon(Icons.close, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: const BoxDecoration(
        color: Color(0xFFFCF8EF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
                  const Expanded(
                    child: Text(
                      'Submit a fertilizer request',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                'Enter your estate and requested quantity. ${widget.place.company} will send it to the CDO for approval.',
                style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.35),
              ),
              _label('Estate name'),
              TextField(controller: _estate, decoration: _dec()),
              _label('District'),
              DropdownButtonFormField<String>(
                initialValue: _district,
                decoration: _dec(),
                items: [for (final d in _districts) DropdownMenuItem(value: d, child: Text(d))],
                onChanged: (v) => setState(() => _district = v ?? _district),
              ),
              _label('Official cultivation area / CDO'),
              DropdownButtonFormField<String>(
                initialValue: _cdo,
                decoration: _dec(),
                items: [for (final c in _cdoAreas) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => setState(() => _cdo = v ?? _cdo),
              ),
              _label('Estate size (acres)'),
              TextField(
                controller: _acres,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _dec(),
              ),
              _label('Your order'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final l in widget.draft.lines)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${l.item.name} \u00d7 ${l.qty50} (50 kg)',
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(rupees(l.lineTotal), style: const TextStyle(fontSize: 13.5)),
                          ],
                        ),
                      ),
                    const Divider(height: 18, color: AppColors.line),
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Total', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        Text(
                          rupees(widget.draft.total),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Preferred ${shortDate(widget.draft.date)} \u00b7 ${widget.draft.slot}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              _label('Documents'),
              _attach('NIC copy', 'Attach a clear photo of your NIC', _nic, true),
              const SizedBox(height: 10),
              _attach(
                'Land title copy',
                'Attach a recent copy of your land title',
                _title,
                false,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dangerText,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Submit request'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
