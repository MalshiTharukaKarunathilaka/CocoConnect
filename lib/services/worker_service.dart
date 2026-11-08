import 'api_client.dart';

class WorkerJob {
  final int id;
  final String category;
  final int workersNeeded;
  final DateTime requiredDate;
  final String location;
  final double dailyRate;
  final String paymentMethod;
  final int? applicationId;
  final String? applicationStatus;

  const WorkerJob({
    required this.id,
    required this.category,
    required this.workersNeeded,
    required this.requiredDate,
    required this.location,
    required this.dailyRate,
    required this.paymentMethod,
    required this.applicationId,
    required this.applicationStatus,
  });

  factory WorkerJob.fromJson(Map<String, dynamic> json) => WorkerJob(
    id: (json['id'] as num).toInt(),
    category: json['category'] as String? ?? '',
    workersNeeded: (json['workers_needed'] as num?)?.toInt() ?? 0,
    requiredDate: DateTime.parse('${json['required_date']}'),
    location: json['location'] as String? ?? '',
    dailyRate: _number(json['daily_rate']),
    paymentMethod: json['payment_method'] as String? ?? '',
    applicationId: (json['application_id'] as num?)?.toInt(),
    applicationStatus: json['application_status'] as String?,
  );
}

double _number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

class WorkerService {
  WorkerService._();

  static Future<List<WorkerJob>> getAvailableJobs() async {
    final data = await ApiClient.get('/api/worker/jobs');
    return (data as List)
        .map((item) => WorkerJob.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<void> applyForJob(int jobId) async {
    await ApiClient.post('/api/worker/jobs/$jobId/apply');
  }
}
