import 'api_client.dart';

class WorkerJob {
  final int id;
  final String category;
  final int workersNeeded;
  final int confirmedWorkers;
  final DateTime requiredDate;
  final String location;
  final double dailyRate;
  final String paymentMethod;
  final String status;
  final String estateName;
  final String estateOwnerName;
  final int? applicationId;
  final String? applicationStatus;

  const WorkerJob({
    required this.id,
    required this.category,
    required this.workersNeeded,
    required this.confirmedWorkers,
    required this.requiredDate,
    required this.location,
    required this.dailyRate,
    required this.paymentMethod,
    required this.status,
    required this.estateName,
    required this.estateOwnerName,
    required this.applicationId,
    required this.applicationStatus,
  });

  factory WorkerJob.fromJson(Map<String, dynamic> json) => WorkerJob(
    id: (json['id'] as num).toInt(),
    category: json['category'] as String? ?? '',
    workersNeeded: (json['workers_needed'] as num?)?.toInt() ?? 0,
    confirmedWorkers: (json['confirmed_workers'] as num?)?.toInt() ?? 0,
    requiredDate: DateTime.parse('${json['required_date']}'),
    location: json['location'] as String? ?? '',
    dailyRate: _number(json['daily_rate']),
    paymentMethod: json['payment_method'] as String? ?? '',
    status: json['status'] as String? ?? 'OPEN',
    estateName: json['estate_name'] as String? ?? 'Estate',
    estateOwnerName: json['estate_owner_name'] as String? ?? 'Estate owner',
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
