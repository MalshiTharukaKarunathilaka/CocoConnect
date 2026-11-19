import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_data.dart';

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
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.green,
              size: 34,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Application sent',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Your fertilizer application ${r.id} is with ${r.cdo} for verification.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, height: 1.35),
          ),
          const SizedBox(height: 6),
          Text(
            '${r.fertilizer}\n${r.requested} bag${r.requested == 1 ? '' : 's'}. Follow it in My orders.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.muted,
              height: 1.4,
            ),
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

/// CDO Annex 01 (RH/AGRI/CDO/01) — Application for Obtaining Fertilizer.
/// Estate / land size fields are filled from the owner profile and locked.
class FertilizerGovOrderForm extends StatefulWidget {
  const FertilizerGovOrderForm({
    super.key,
    required this.place,
    required this.draft,
  });

  final FertPlace place;
  final GovOrderDraft draft;

  @override
  State<FertilizerGovOrderForm> createState() => _FertilizerGovOrderFormState();
}

class _FertilizerGovOrderFormState extends State<FertilizerGovOrderForm> {
  late final FertOwnerProfile _profile;
  XFile? _nic;
  XFile? _title;
  bool _agree = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final store = FertilizerStore.instance;
    final me = AuthService.currentUser;
    if (me != null) store.bindUser(me);
    _profile = store.ownerProfile;
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
              leading: const Icon(
                Icons.photo_camera_outlined,
                color: AppColors.green,
              ),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.green,
              ),
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
        const SnackBar(
          content: Text('Could not open the photo. Please try again.'),
        ),
      );
    }
  }

  Future<void> _submit() async {
    String? err;
    if (_nic == null) {
      err = 'Attach a copy of your National Identity Card';
    } else if (_title == null) {
      err = 'Attach a copy of the coconut land deed / land title';
    } else if (!_agree) {
      err = 'Tick the declaration before you submit';
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }

    final store = FertilizerStore.instance;
    final p = _profile;
    // Why: keep bytes so the CDO office can open/view the NIC, not only the name.
    List<int>? nicBytes;
    List<int>? titleBytes;
    try {
      nicBytes = await _nic!.readAsBytes();
      titleBytes = await _title!.readAsBytes();
    } catch (_) {
      nicBytes = null;
      titleBytes = null;
    }
    final req = FertGovRequest(
      id: 'FR-${1000 + store.govRequests.length + 1}',
      owner: p.estateName,
      fertilizer: widget.draft.summary,
      requested: widget.draft.bags,
      status: 'Pending Ack',
      cdo: widget.place.who,
      date: DateTime.now(),
      district: p.district,
      estateName: p.estateName,
      acres: p.acres.toDouble(),
      nicCopy: _nic!.name,
      nicCopyPath: _nic!.path,
      nicBytes: nicBytes,
      landTitleCopy: _title!.name,
      landTitleCopyPath: _title!.path,
      landTitleBytes: titleBytes,
      outlet: widget.place.company,
      preferred: '${shortDate(widget.draft.date)} · ${widget.draft.slot}',
      beneficiaryName: p.fullName,
      address: p.address,
      phone: p.phone,
      nicNumber: p.nicNumber,
      landAddress: p.landAddress,
      deedNumber: p.deedNumber,
      roods: p.roods,
      perches: p.perches,
      coconutTrees: p.coconutTrees,
      coconutSaplings: p.coconutSaplings,
      annualHarvestNuts: p.annualHarvestNuts,
    );
    store.placeGovRequest(req);
    if (!mounted) return;
    Navigator.pop(context, req);
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance, color: AppColors.green),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Coconut Cultivation Board',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Annex 01 · RH/AGRI/CDO/01',
                      style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Special Coconut Land Rehabilitation Programme',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Conducted with the Department of Agrarian Services / Kapruka Society or other registered coconut grower societies',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.3),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Application for Obtaining Fertilizer',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppColors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String n, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.green,
              shape: BoxShape.circle,
            ),
            child: Text(
              n,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  /// Locked field — filled from the estate account, not typed by the owner.
  Widget _locked(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F1EA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(Icons.lock_outline, size: 16, color: AppColors.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sizeGrid() {
    final p = _profile;
    Widget cell(String label, String value) => Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 6, bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F1EA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
    return Column(
      children: [
        Row(
          children: [
            cell('Acres', '${p.acres}'),
            cell('Roods', '${p.roods}'),
            cell('Perches', '${p.perches}'),
          ],
        ),
        Row(
          children: [
            cell('Coconut trees', '${p.coconutTrees}'),
            cell('Saplings', '${p.coconutSaplings}'),
          ],
        ),
        Row(
          children: [
            cell('Current harvest (nuts / year)', '${p.annualHarvestNuts}'),
          ],
        ),
      ],
    );
  }

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
            else if (!kIsWeb)
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
                    child: const Icon(
                      Icons.description_outlined,
                      color: AppColors.green,
                    ),
                  ),
                ),
              )
            else
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: AppColors.green,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    file == null ? hint : file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
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
    final p = _profile;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.94,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFCF8EF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
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
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Text(
                        'CDO fertilizer application',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 18 + bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    const SizedBox(height: 8),
                    Text(
                      'Outlet: ${widget.place.company}. Estate details and land size are taken from your account and cannot be edited here.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.muted,
                        height: 1.35,
                      ),
                    ),

                    _sectionTitle('1', 'Full name of beneficiary'),
                    _locked('Name', p.fullName),

                    _sectionTitle('2', 'Address'),
                    _locked('Postal address', p.address),

                    _sectionTitle('3', 'Telephone number'),
                    _locked('Phone', p.phone),

                    _sectionTitle('4', 'National Identity Card (N.I.C.) number'),
                    _locked('NIC number', p.nicNumber),

                    _sectionTitle('5', 'Address of the land'),
                    _locked('Coconut land address', p.landAddress),

                    _sectionTitle('6', 'Deed number of the coconut land'),
                    _locked('Deed number', p.deedNumber),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        '6 (a–d) Coconut acreage, trees, saplings and current harvest',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    _sizeGrid(),

                    _sectionTitle('7', 'Subsidy requested for'),
                    const Text(
                      'Taken from your registered coconut land (same size as above). Fertilizer bags are from your cart.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 8),
                    _sizeGrid(),
                    const SizedBox(height: 8),
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
                          const Text(
                            'Fertilizer requested',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          for (final l in widget.draft.lines)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${l.item.name} × ${l.qty50} (50 kg)',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    rupees(l.lineTotal),
                                    style: const TextStyle(fontSize: 13.5),
                                  ),
                                ],
                              ),
                            ),
                          const Divider(height: 18, color: AppColors.line),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Total',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
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
                            'Preferred ${shortDate(widget.draft.date)} · ${widget.draft.slot}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),

                    _sectionTitle('8', 'Supporting documents'),
                    _attach(
                      'NIC copy',
                      'Clear photo of both sides of your NIC',
                      _nic,
                      true,
                    ),
                    const SizedBox(height: 10),
                    _attach(
                      'Land deed / title copy',
                      'Recent copy of the coconut land deed',
                      _title,
                      false,
                    ),

                    _sectionTitle('9', 'Declarations'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '1. I certify that the information given above is true and correct, and that the fertilizer obtained under this programme will be used only on the coconut land stated in this application.',
                            style: TextStyle(fontSize: 12, height: 1.4),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '2. I acknowledge that fertilizer supplied under this programme is government property. Using it for any other crop, selling it, or misusing it is a punishable offence.',
                            style: TextStyle(fontSize: 12, height: 1.4),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '3. If dolomite is not available at the issuing centre, I agree to buy the required dolomite myself and apply it together with APM / YPM fertilizer as instructed.',
                            style: TextStyle(fontSize: 12, height: 1.4),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '4. I undertake to increase the coconut yield of this land and thereby contribute to Sri Lanka’s national export income.',
                            style: TextStyle(fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _agree,
                      onChanged: (v) => setState(() {
                        _agree = v ?? false;
                        _error = null;
                      }),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.green,
                      title: const Text(
                        'I have read and agree to the declarations above (applicant confirmation).',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      'Applicant date: ${shortDate(DateTime.now())} · For official use: Coconut Development Officer / Assistant CDO / Development Officer / ARPA / Divi Neguma Development Officer / Grama Niladhari will certify items 1–7.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.muted,
                        height: 1.35,
                      ),
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
                        child: const Text('Submit fertilizer application'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
