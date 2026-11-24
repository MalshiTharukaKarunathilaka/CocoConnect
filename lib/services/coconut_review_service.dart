import 'api_client.dart';

class CoconutReview {
  final int stars;
  final String comment;

  CoconutReview.fromJson(Map<String, dynamic> json)
    : stars = (json['rating'] as num).toInt(),
      comment = json['comment'] as String;
}

class CoconutReviews {
  final double? average;
  final int count;
  final List<CoconutReview> comments;

  CoconutReviews.fromJson(Map<String, dynamic> json)
    : average = (json['average_rating'] as num?)?.toDouble(),
      count = (json['rating_count'] as num?)?.toInt() ?? 0,
      comments = [
        for (final item in json['comments'] as List? ?? const [])
          CoconutReview.fromJson(item as Map<String, dynamic>),
      ];

  static Future<CoconutReviews> loadMine() async => CoconutReviews.fromJson(
    await ApiClient.get('/api/coconut-reviews/me') as Map<String, dynamic>,
  );
}

class CoconutCounterpartProfile {
  final String name;
  final bool isLandOwner;
  final String? estateName;
  final String? location;
  final CoconutReviews reviews;

  CoconutCounterpartProfile.fromJson(Map<String, dynamic> json)
    : name = json['name'] as String? ?? '',
      isLandOwner = json['role'] == 'ESTATE_OWNER',
      estateName = json['estate_name'] as String?,
      location = json['location'] as String?,
      reviews = CoconutReviews.fromJson(json);

  static Future<CoconutCounterpartProfile> load(String path) async =>
      CoconutCounterpartProfile.fromJson(
        await ApiClient.get(path) as Map<String, dynamic>,
      );
}
