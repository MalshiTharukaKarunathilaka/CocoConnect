import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    } else {
      return 'http://10.0.2.2:5000';
    }
  }
  
  static Future<bool> createSellRequest({
  required int estateOwnerId,
  required int buyerRequestId,
  required String productType,
  required int quantity,
  required double sellerPricePerUnit,
  required String availableDate,
}) async {
  final response = await http.post(
    Uri.parse('$baseUrl/api/listings/sell-requests'),
    headers: {
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'estateOwnerId': estateOwnerId,
      'buyerRequestId': buyerRequestId,
      'productType': productType,
      'quantity': quantity,
      'sellerPricePerUnit': sellerPricePerUnit,
      'availableDate': availableDate,
    }),
  );

  if (response.statusCode == 201) {
    return true;
  }

  print('Sell request error: ${response.body}');
  return false;
}


  static Future<void> createListing({
  required int quantity,
  required String availableDate,
  required double offerPricePerUnit,
}) async {
  final response = await http.post(
    Uri.parse('$baseUrl/api/listings'),
    headers: {
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      "estateOwnerId": 1,
      "productType": "RAW_COCONUT",
      "quantity": quantity,
      "availableDate": availableDate,
      "offerPricePerUnit": offerPricePerUnit,
    }),
  );

  if (response.statusCode != 201) {
    throw Exception('Failed to save listing');
  }
}

  static Future<List<dynamic>> getBuyerRequests() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/listings/buyer-requests'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load buyer requests');
    }
  }
}