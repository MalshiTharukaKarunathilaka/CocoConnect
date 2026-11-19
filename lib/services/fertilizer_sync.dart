import 'package:flutter/foundation.dart';

import 'api_client.dart';
import '../screens/fertilizer/fertilizer_data.dart';

/// Loads and saves fertilizer ops data through the Express → Supabase API.
class FertilizerSync {
  FertilizerSync._();

  static Future<Map<String, dynamic>?> bootstrap() async {
    try {
      final data = await ApiClient.get('/api/fertilizer/bootstrap');
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return null;
    } on ApiException catch (e) {
      debugPrint('fertilizer bootstrap failed: $e');
      return null;
    } catch (e) {
      debugPrint('fertilizer bootstrap error: $e');
      return null;
    }
  }

  static Future<void> upsertOrder(FertOrder order) async {
    await ApiClient.put('/api/fertilizer/orders', {
      'id': order.id,
      'place_id': order.placeId,
      'owner': order.owner,
      'company': order.company,
      'agent': order.agent,
      'product': order.product,
      'qty50': order.qty50,
      'price': order.price,
      'preferred_date': order.preferredDate.toIso8601String().split('T').first,
      'slot': order.slot,
      'status': order.status,
      'message': order.message,
      'items': [
        for (final line in order.items)
          {
            'name': line.item.name,
            'brand': line.item.brand,
            'type': line.item.type,
            'price': line.item.price,
            'unit': line.item.unit,
            'stock': line.item.stock,
            'qty50': line.qty50,
          },
      ],
      'negotiation': [
        for (final m in order.negotiation)
          {'from': m.from, 'text': m.text, 'time': m.time},
      ],
      'owner_stars': order.ownerStars,
      'supplier_stars': order.supplierStars,
      'owner_rate_note': order.ownerRateNote,
      'supplier_rate_note': order.supplierRateNote,
    });
  }

  static Future<void> upsertGov(FertGovRequest r) async {
    await ApiClient.put('/api/fertilizer/gov-requests', {
      'id': r.id,
      'owner': r.owner,
      'cdo': r.cdo,
      'fertilizer': r.fertilizer,
      'requested': r.requested,
      'approved': r.approved,
      'distributed': r.distributed,
      'status': r.status,
      'district': r.district,
      'date': r.date.toIso8601String().split('T').first,
      'delivery_at': r.deliveryAt?.toUtc().toIso8601String(),
      'preferred': r.preferred,
      'outlet': r.outlet,
      'estate_name': r.estateName,
      'acres': r.acres,
      'nic_copy': r.nicCopy,
      'land_title_copy': r.landTitleCopy,
      'beneficiary_name': r.beneficiaryName,
      'address': r.address,
      'phone': r.phone,
      'nic_number': r.nicNumber,
      'land_address': r.landAddress,
      'deed_number': r.deedNumber,
      'coconut_trees': r.coconutTrees,
      'coconut_saplings': r.coconutSaplings,
      'annual_harvest_nuts': r.annualHarvestNuts,
      'chat': [
        for (final m in r.chat) {'from': m.from, 'text': m.text, 'time': m.time},
      ],
    });
  }

  static Future<void> upsertShopTalk({
    required String placeId,
    required String ownerKey,
    required List<FertChat> messages,
    required int unreadSupplier,
  }) async {
    await ApiClient.put('/api/fertilizer/shop-talks/$placeId', {
      'owner_key': ownerKey,
      'messages': [
        for (final m in messages)
          {'from': m.from, 'text': m.text, 'time': m.time},
      ],
      'unread_supplier': unreadSupplier,
    });
  }

  static Future<void> upsertComplaint(FertComplaint c) async {
    await ApiClient.put('/api/fertilizer/complaints', {
      'id': c.id,
      'owner': c.owner,
      'category': c.category,
      'product': c.product,
      'status': c.status,
      'description': c.description,
      'district': c.district,
      'date': c.date.toIso8601String().split('T').first,
    });
  }

  static Future<void> upsertAlert(FertOwnerAlert a, String audience) async {
    await ApiClient.put('/api/fertilizer/alerts', {
      'id': a.id,
      'audience': audience,
      'title': a.title,
      'body': a.body,
      'kind': a.kind,
      'order_id': a.orderId,
      'read': a.read,
      'at': a.at.toUtc().toIso8601String(),
    });
  }
}
