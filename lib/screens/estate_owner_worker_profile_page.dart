import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/worker_service.dart';

const _ownerGreen = Color(0xFF2A704E);
const _ownerBackground = Color(0xFFFCF9F3);
const _ownerInk = Color(0xFF193126);
const _ownerMuted = Color(0xFF65766C);

class EstateOwnerWorkerProfilePage extends StatefulWidget {
  final WorkerJob job;

  const EstateOwnerWorkerProfilePage({super.key, required this.job});

  @override
  State<EstateOwnerWorkerProfilePage> createState() =>
      _EstateOwnerWorkerProfilePageState();
}

class _EstateOwnerWorkerProfilePageState
    extends State<EstateOwnerWorkerProfilePage> {
  late Future<EstateOwnerWorkerProfile> _profile;
  int? _currentRating;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _profile = WorkerService.getEstateOwnerProfile(widget.job.id);
    _currentRating = widget.job.estateOwnerRating;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ownerBackground,
      appBar: AppBar(
        backgroundColor: _ownerBackground,
        foregroundColor: _ownerInk,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context, _currentRating),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text(
          'Land Owner Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<EstateOwnerWorkerProfile>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _ownerGreen),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _errorView(snapshot.error);
          }
          return _profileView(snapshot.data!);
        },
      ),
    );
  }

  Widget _errorView(Object? error) {
    final message = error is ApiException
        ? error.message
        : 'Could not load this land owner profile.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_outlined, size: 54, color: _ownerMuted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => setState(
                () => _profile = WorkerService.getEstateOwnerProfile(
                  widget.job.id,
                ),
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileView(EstateOwnerWorkerProfile profile) {
    final initials = profile.estateName
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0])
        .join()
        .toUpperCase();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: const Color(0xFFD8EBDD),
          child: Text(
            initials.isEmpty ? 'EO' : initials,
            style: const TextStyle(
              color: _ownerGreen,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          profile.estateName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _ownerInk,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Owner: ${profile.ownerName}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _ownerMuted, fontSize: 16),
        ),
        const SizedBox(height: 12),
        _ratingSummary(profile),
        const SizedBox(height: 18),
        _card([
          _detail(
            Icons.location_on_outlined,
            'Location',
            profile.location.isEmpty ? 'Not provided' : profile.location,
          ),
          const Divider(height: 24),
          _detail(
            Icons.phone_outlined,
            'Phone',
            profile.phone.isEmpty ? 'Not provided' : profile.phone,
          ),
          if (profile.primaryCrop?.trim().isNotEmpty == true) ...[
            const Divider(height: 24),
            _detail(Icons.eco_outlined, 'Primary crop', profile.primaryCrop!),
          ],
          if (profile.totalLandArea?.trim().isNotEmpty == true) ...[
            const Divider(height: 24),
            _detail(
              Icons.landscape_outlined,
              'Land area',
              profile.totalLandArea!,
            ),
          ],
          if (profile.yearEstablished != null) ...[
            const Divider(height: 24),
            _detail(
              Icons.calendar_today_outlined,
              'Established',
              '${profile.yearEstablished}',
            ),
          ],
        ]),
        const SizedBox(height: 16),
        _card([
          Row(
            children: [
              Expanded(
                child: _stat('${profile.completedJobs}', 'Completed jobs'),
              ),
              Container(width: 1, height: 48, color: const Color(0xFFE0E7E2)),
              Expanded(
                child: _stat('${profile.ratingCount}', 'Worker ratings'),
              ),
            ],
          ),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: _saving ? null : () => _rateOwner(profile),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.star),
            label: Text(
              _currentRating == null
                  ? 'Give Rating'
                  : 'Update Rating (${_currentRating!}/5)',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _ownerGreen,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _ratingSummary(EstateOwnerWorkerProfile profile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0D38A)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star, color: Color(0xFFE3A008), size: 28),
          const SizedBox(width: 9),
          Text(
            profile.averageRating == null
                ? 'Not rated yet'
                : '${profile.averageRating!.toStringAsFixed(1)} / 5',
            style: const TextStyle(
              color: _ownerInk,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rateOwner(EstateOwnerWorkerProfile profile) async {
    var selected = _currentRating ?? 0;
    final rating = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: Text('Rate ${profile.ownerName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.job.category,
                style: const TextStyle(color: _ownerMuted),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                runSpacing: 4,
                children: [
                  for (var value = 1; value <= 5; value++)
                    IconButton(
                      onPressed: () => setDialogState(() => selected = value),
                      icon: Icon(
                        value <= selected ? Icons.star : Icons.star_border,
                        color: value <= selected
                            ? const Color(0xFFE3A008)
                            : const Color(0xFFD9D5CC),
                      ),
                    ),
                ],
              ),
              Text(
                selected == 0 ? 'Select a rating' : '$selected / 5',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected == 0
                  ? null
                  : () => Navigator.pop(dialogContext, selected),
              style: FilledButton.styleFrom(backgroundColor: _ownerGreen),
              child: Text(
                _currentRating == null ? 'Save Rating' : 'Update Rating',
              ),
            ),
          ],
        ),
      ),
    );
    if (rating == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final saved = await WorkerService.rateEstateOwner(
        jobId: widget.job.id,
        rating: rating,
      );
      if (!mounted) return;
      setState(() {
        _currentRating = saved;
        _profile = WorkerService.getEstateOwnerProfile(widget.job.id);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Land owner rating saved.')));
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD5E3DB)),
      ),
      child: Column(children: children),
    );
  }

  Widget _detail(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: _ownerGreen, size: 26),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: _ownerMuted)),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: _ownerInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: _ownerGreen,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: _ownerMuted, fontSize: 12)),
      ],
    );
  }
}
