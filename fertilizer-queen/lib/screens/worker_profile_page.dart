import 'package:flutter/material.dart';
import '../services/owner_service.dart';

const _profileGreen = Color(0xFF2A704E);
const _profileBackground = Color(0xFFFCF9F3);
const _profileInk = Color(0xFF193126);
const _profileMuted = Color(0xFF65766C);

class WorkerProfilePage extends StatefulWidget {
  final int workerId;
  final String fallbackName;

  const WorkerProfilePage({
    super.key,
    required this.workerId,
    required this.fallbackName,
  });

  @override
  State<WorkerProfilePage> createState() => _WorkerProfilePageState();
}

class _WorkerProfilePageState extends State<WorkerProfilePage> {
  late Future<WorkerProfile> _profile;

  @override
  void initState() {
    super.initState();
    _profile = OwnerService.getWorkerProfile(widget.workerId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _profileBackground,
      appBar: AppBar(
        backgroundColor: _profileBackground,
        foregroundColor: _profileInk,
        elevation: 0,
        title: const Text(
          'Worker Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<WorkerProfile>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _profileGreen),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _errorView();
          }
          return _profileView(snapshot.data!);
        },
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_outlined, size: 54, color: _profileMuted),
            const SizedBox(height: 12),
            Text(
              'Could not load ${widget.fallbackName}\'s profile.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _profileInk, fontSize: 17),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => setState(
                () => _profile = OwnerService.getWorkerProfile(widget.workerId),
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileView(WorkerProfile profile) {
    final categories = profile.workCategories.isEmpty
        ? 'General day work'
        : profile.workCategories.join(', ');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        const CircleAvatar(
          radius: 48,
          backgroundColor: Color(0xFFD8EBDD),
          child: Icon(Icons.person, color: _profileGreen, size: 58),
        ),
        const SizedBox(height: 14),
        Text(
          profile.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _profileInk,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Day Job Worker',
          textAlign: TextAlign.center,
          style: TextStyle(color: _profileMuted, fontSize: 16),
        ),
        const SizedBox(height: 22),
        _card(
          children: [
            _detail(Icons.phone_outlined, 'Phone', profile.phone),
            const Divider(height: 24),
            _detail(
              Icons.location_on_outlined,
              'Location',
              profile.location.isEmpty ? 'Not provided' : profile.location,
            ),
            const Divider(height: 24),
            _detail(Icons.work_outline, 'Work categories', categories),
          ],
        ),
        const SizedBox(height: 16),
        _card(
          children: [
            Row(
              children: [
                Expanded(
                  child: _stat('${profile.completedJobs}', 'Completed jobs'),
                ),
                Container(width: 1, height: 48, color: const Color(0xFFE0E7E2)),
                Expanded(
                  child: _stat('${profile.acceptedJobs}', 'Accepted jobs'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _card({required List<Widget> children}) {
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
        Icon(icon, color: _profileGreen, size: 26),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: _profileMuted)),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: _profileInk,
                  fontSize: 16,
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
            color: _profileGreen,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _profileMuted),
        ),
      ],
    );
  }
}
