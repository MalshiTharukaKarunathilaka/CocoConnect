import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models.dart';

enum AcceptFailure { conflict, full }

class AcceptResult {
  final bool ok;
  final AcceptFailure? failure;
  final Job? conflictJob; // the job already accepted for that day
  const AcceptResult.success()
      : ok = true,
        failure = null,
        conflictJob = null;
  const AcceptResult.fail(this.failure, {this.conflictJob}) : ok = false;
}

class MyJob {
  final DateTime date;
  final Job job;
  const MyJob(this.date, this.job);
}

/// Holds the worker's accepted jobs and negotiation chats.
///
/// Rules:
///  - at most ONE accepted job per day
///  - only a job the worker accepted can be declined
///  - a full job cannot be accepted
class JobsState extends ChangeNotifier {
  // dateKey -> jobId
  final Map<String, String> _accepted = {};
  // "dateKey:jobId" -> messages
  final Map<String, List<ChatMessage>> _chats = {};

  Map<String, String> get accepted => Map.unmodifiable(_accepted);

  String? acceptedJobId(DateTime date) => _accepted[dateKey(date)];

  bool isMine(DateTime date, String jobId) => _accepted[dateKey(date)] == jobId;

  int acceptedCount(DateTime date, Job job) =>
      job.baseAccepted + (isMine(date, job.id) ? 1 : 0);

  AcceptResult acceptJob(DateTime date, String jobId) {
    final existing = _accepted[dateKey(date)];
    if (existing != null) {
      return AcceptResult.fail(AcceptFailure.conflict,
          conflictJob: getJob(existing));
    }
    final job = getJob(jobId);
    if (job.baseAccepted >= job.capacity) {
      return const AcceptResult.fail(AcceptFailure.full);
    }
    _accepted[dateKey(date)] = jobId;
    notifyListeners();
    return const AcceptResult.success();
  }

  void declineJob(DateTime date, String jobId) {
    if (!isMine(date, jobId)) return;
    _accepted.remove(dateKey(date));
    notifyListeners();
  }

  List<MyJob> get myJobs {
    final list = _accepted.entries.map((e) {
      final p = e.key.split('-').map(int.parse).toList();
      return MyJob(DateTime(p[0], p[1], p[2]), getJob(e.value));
    }).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  String _chatKey(DateTime date, String jobId) => '${dateKey(date)}:$jobId';

  List<ChatMessage> chat(DateTime date, String jobId) =>
      List.unmodifiable(_chats[_chatKey(date, jobId)] ?? const []);

  void addMessage(DateTime date, String jobId, Sender from, String text) {
    _chats.putIfAbsent(_chatKey(date, jobId), () => []).add(ChatMessage(from, text));
    notifyListeners();
  }
}

/// Bottom-tab selection plus the navigators inside the tabs, so the
/// confirmation screen can send the worker back to the dashboard.
class AppNav extends ChangeNotifier {
  int tabIndex = 0;
  final dashboardKey = GlobalKey<NavigatorState>();
  final jobsKey = GlobalKey<NavigatorState>();

  void setTab(int i) {
    tabIndex = i;
    notifyListeners();
  }

  void goToDashboard() {
    dashboardKey.currentState?.popUntil((r) => r.isFirst);
    setTab(0);
  }
}
