import 'api_client.dart';

class WorkerProfileSummary {
  final int id;
  final String name;
  final String phone;
  final String location;
  final List<String> workCategories;
  final int acceptedJobs;
  final int activeJobs;
  final int completedJobs;
  final int totalRatingMarks;
  final double? averageRating;

  const WorkerProfileSummary({
    required this.id,
    required this.name,
    required this.phone,
    required this.location,
    required this.workCategories,
    required this.acceptedJobs,
    required this.activeJobs,
    required this.completedJobs,
    required this.totalRatingMarks,
    required this.averageRating,
  });

  factory WorkerProfileSummary.fromJson(Map<String, dynamic> json) =>
      WorkerProfileSummary(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? 'Worker',
        phone: json['phone'] as String? ?? '',
        location: json['location'] as String? ?? '',
        workCategories:
            ((json['work_categories'] as List<dynamic>?) ?? const [])
                .map((category) => '$category')
                .toList(),
        acceptedJobs: (json['accepted_jobs'] as num?)?.toInt() ?? 0,
        activeJobs: (json['active_jobs'] as num?)?.toInt() ?? 0,
        completedJobs: (json['completed_jobs'] as num?)?.toInt() ?? 0,
        totalRatingMarks: (json['total_rating_marks'] as num?)?.toInt() ?? 0,
        averageRating: (json['average_rating'] as num?)?.toDouble(),
      );
}

class WorkerJob {
  final int id;
  final int estateOwnerId;
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
  final String estateLocation;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final int? applicationId;
  final String? applicationStatus;
  final bool canDecline;
  final int? rating;
  final int? estateOwnerRating;
  final double? estateOwnerAverageRating;
  final int estateOwnerRatingCount;
  final bool completionAcknowledged;

  const WorkerJob({
    required this.id,
    required this.estateOwnerId,
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
    required this.estateLocation,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.applicationId,
    required this.applicationStatus,
    required this.canDecline,
    required this.rating,
    required this.estateOwnerRating,
    required this.estateOwnerAverageRating,
    required this.estateOwnerRatingCount,
    required this.completionAcknowledged,
  });

  factory WorkerJob.fromJson(Map<String, dynamic> json) => WorkerJob(
    id: (json['id'] as num).toInt(),
    estateOwnerId: (json['estate_owner_id'] as num?)?.toInt() ?? 0,
    category: json['category'] as String? ?? '',
    workersNeeded: (json['workers_needed'] as num?)?.toInt() ?? 0,
    confirmedWorkers: (json['confirmed_workers'] as num?)?.toInt() ?? 0,
    requiredDate: DateTime.parse('${json['required_date']}'),
    location: json['location'] as String? ?? '',
    dailyRate: _number(json['daily_rate']),
    paymentMethod: json['payment_method'] as String? ?? '',
    status:
        json['worker_status'] as String? ?? json['status'] as String? ?? 'OPEN',
    estateName: json['estate_name'] as String? ?? 'Land',
    estateOwnerName: json['estate_owner_name'] as String? ?? 'Land owner',
    estateLocation:
        json['estate_location'] as String? ?? json['location'] as String? ?? '',
    latitude: (json['estate_latitude'] as num?)?.toDouble(),
    longitude: (json['estate_longitude'] as num?)?.toDouble(),
    distanceKm: _optionalNumber(json['distance_km']),
    applicationId: (json['application_id'] as num?)?.toInt(),
    applicationStatus: json['application_status'] as String?,
    canDecline: json['can_decline'] == true,
    rating: (json['rating'] as num?)?.toInt(),
    estateOwnerRating: (json['estate_owner_rating'] as num?)?.toInt(),
    estateOwnerAverageRating: (json['estate_owner_average_rating'] as num?)
        ?.toDouble(),
    estateOwnerRatingCount:
        (json['estate_owner_rating_count'] as num?)?.toInt() ?? 0,
    completionAcknowledged: json['completion_acknowledged'] == true,
  );

  bool get needsCompletionAcknowledgement =>
      applicationStatus?.toUpperCase() == 'ACCEPTED' &&
      status.toUpperCase() == 'AWAITING_WORKER_ACK' &&
      !completionAcknowledged;

  /// Worker already sent completion — waiting for land owner to confirm.
  bool get workerInitiatedCompletion =>
      applicationStatus?.toUpperCase() == 'ACCEPTED' &&
      status.toUpperCase() == 'AWAITING_OWNER_ACK';

  /// Worker can click "Complete Job" for past/today accepted jobs that haven't
  /// been completed or already initiated by either side.
  bool get canInitiateCompletion {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final jobDay = DateTime(requiredDate.year, requiredDate.month, requiredDate.day);
    final isPastOrToday = !jobDay.isAfter(today);
    final st = status.toUpperCase();
    return applicationStatus?.toUpperCase() == 'ACCEPTED' &&
        isPastOrToday &&
        st != 'COMPLETED' &&
        st != 'CANCELLED' &&
        st != 'AWAITING_WORKER_ACK' &&
        st != 'AWAITING_OWNER_ACK';
  }
}

class EstateOwnerWorkerProfile {
  final int id;
  final String ownerName;
  final String estateName;
  final String location;
  final String phone;
  final String? totalLandArea;
  final String? primaryCrop;
  final int? yearEstablished;
  final int completedJobs;
  final int ratingCount;
  final int totalRatingMarks;
  final double? averageRating;
  final int? currentJobRating;

  const EstateOwnerWorkerProfile({
    required this.id,
    required this.ownerName,
    required this.estateName,
    required this.location,
    required this.phone,
    required this.totalLandArea,
    required this.primaryCrop,
    required this.yearEstablished,
    required this.completedJobs,
    required this.ratingCount,
    required this.totalRatingMarks,
    required this.averageRating,
    required this.currentJobRating,
  });

  factory EstateOwnerWorkerProfile.fromJson(Map<String, dynamic> json) =>
      EstateOwnerWorkerProfile(
        id: (json['id'] as num).toInt(),
        ownerName: json['owner_name'] as String? ?? 'Land owner',
        estateName: json['estate_name'] as String? ?? 'Land',
        location: json['location'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        totalLandArea: json['total_land_area'] as String?,
        primaryCrop: json['primary_crop'] as String?,
        yearEstablished: (json['year_established'] as num?)?.toInt(),
        completedJobs: (json['completed_jobs'] as num?)?.toInt() ?? 0,
        ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
        totalRatingMarks: (json['total_rating_marks'] as num?)?.toInt() ?? 0,
        averageRating: (json['average_rating'] as num?)?.toDouble(),
        currentJobRating: (json['current_job_rating'] as num?)?.toInt(),
      );
}

class WorkerEstate {
  final int id;
  final String estateName, ownerName, location;
  final double? latitude, longitude, distanceKm;
  final bool hasMapLocation;
  const WorkerEstate({
    required this.id,
    required this.estateName,
    required this.ownerName,
    required this.location,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.hasMapLocation = false,
  });
  factory WorkerEstate.fromJson(Map<String, dynamic> j) => WorkerEstate(
    id: (j['id'] as num?)?.toInt() ?? 0,
    estateName: j['estate_name'] as String? ?? 'Land',
    ownerName: j['estate_owner_name'] as String? ?? 'Land owner',
    location: j['location'] as String? ?? '',
    latitude: _optionalNumber(j['estate_latitude'] ?? j['latitude']),
    longitude: _optionalNumber(j['estate_longitude'] ?? j['longitude']),
    distanceKm: _optionalNumber(j['distance_km']),
    hasMapLocation:
        j['has_map_location'] == true ||
        (j['estate_latitude'] != null && j['estate_longitude'] != null) ||
        (j['latitude'] != null && j['longitude'] != null),
  );
}

double? _optionalNumber(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value');

double _number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

class WorkerService {
  WorkerService._();

  static Future<WorkerProfileSummary> getProfile() async {
    final data = await ApiClient.get('/api/worker/profile');
    return WorkerProfileSummary.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<WorkerJob>> getAvailableJobs() async {
    final data = await ApiClient.get('/api/worker/jobs');
    return (data as List)
        .map((item) => WorkerJob.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<void> applyForJob(int jobId) async {
    await ApiClient.post('/api/worker/jobs/$jobId/apply');
  }

  static Future<void> declineJob(int jobId, {String? reason, String? note}) async {
    await ApiClient.post('/api/worker/jobs/$jobId/decline', {
      if (reason != null) 'reason': reason,
      if (note != null) 'note': note,
    });
  }

  static Future<void> initiateJobCompletion(int jobId) async {
    await ApiClient.post('/api/worker/jobs/$jobId/initiate-complete');
  }

  static Future<void> acknowledgeJobCompletion({
    required int jobId,
    required int rating,
  }) async {
    await ApiClient.patch('/api/worker/jobs/$jobId/complete', {
      'rating': rating,
    });
  }

  static Future<EstateOwnerWorkerProfile> getEstateOwnerProfile(
    int jobId,
  ) async {
    final data = await ApiClient.get('/api/worker/jobs/$jobId/estate-owner');
    return EstateOwnerWorkerProfile.fromJson(data as Map<String, dynamic>);
  }

  static Future<int> rateEstateOwner({
    required int jobId,
    required int rating,
  }) async {
    final data = await ApiClient.put(
      '/api/worker/jobs/$jobId/estate-owner/rating',
      {'rating': rating},
    );
    return ((data as Map<String, dynamic>)['rating'] as num).toInt();
  }

  static Future<List<WorkerEstate>> getEstates() async {
    final data = await ApiClient.get('/api/worker/estates');
    return (data as List)
        .map((j) => WorkerEstate.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  static Future<WorkerEstate> getEstateLocation(int estateId) async {
    final data = await ApiClient.get('/api/worker/estates/$estateId/location');
    return WorkerEstate.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<WorkerEstate>> getNearbyEstates({
    int radiusKm = 20,
  }) async {
    final data = await ApiClient.get(
      '/api/worker/nearby-estates?radiusKm=$radiusKm',
    );
    return (data as List)
        .map((j) => WorkerEstate.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}
