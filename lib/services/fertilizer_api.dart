import 'api_client.dart';

class FertilizerApi {
  static const base = '/api/fertilizer';
  static Future<List<Map<String, dynamic>>> suppliers({
    required bool government,
  }) async =>
      (await ApiClient.get(
                '$base/suppliers',
                query: {'government': '$government'},
              )
              as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
  static Future<List<Map<String, dynamic>>> orders() async =>
      (await ApiClient.get('$base/orders') as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
  static Future<Map<String, dynamic>> create(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(
        await ApiClient.post('$base/orders', body) as Map,
      );
  static Future<void> act(
    int id,
    String action, [
    Map<String, String>? details,
  ]) async {
    await ApiClient.post('$base/orders/$id/$action', details);
  }

  static Future<void> rateOwner(int id, int rating) async {
    await ApiClient.put('$base/orders/$id/rating', {'rating': rating});
  }
}
