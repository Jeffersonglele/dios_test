import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class CartSyncSnapshot {
  const CartSyncSnapshot({required this.exists, required this.items});

  final bool exists;
  final List<Map<String, dynamic>> items;
}

class CartSyncService {
  const CartSyncService._();

  static Future<CartSyncSnapshot?> loadCart() async {
    try {
      final response = await ParseCloudFunction('getMyCart').execute();
      if (!response.success || response.result is! Map) return null;

      final result = Map<String, dynamic>.from(response.result as Map);
      final rawItems = result['items'];
      if (rawItems is! List) {
        return CartSyncSnapshot(
          exists: result['exists'] == true,
          items: const [],
        );
      }

      return CartSyncSnapshot(
        exists: result['exists'] == true,
        items: rawItems
            .whereType<Map>()
            .map((item) => _normalizeMap(item))
            .toList(),
      );
    } catch (_) {
      // Le cache local reste utilisable si Parse est momentanément indisponible.
      return null;
    }
  }

  static Future<bool> saveCart(List<Map<String, dynamic>> items) async {
    try {
      final response = await ParseCloudFunction('saveMyCart').execute(
        parameters: {'items': items},
      );
      return response.success &&
          response.result is Map &&
          (response.result as Map)['success'] == true;
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic> _normalizeMap(Map item) {
    return item.map<String, dynamic>(
      (key, value) => MapEntry(key.toString(), _normalizeValue(value)),
    );
  }

  static dynamic _normalizeValue(dynamic value) {
    if (value is Map) return _normalizeMap(value);
    if (value is List) return value.map(_normalizeValue).toList();
    return value;
  }
}
