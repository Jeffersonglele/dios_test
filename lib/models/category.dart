import 'package:dios_delices/services/node_auth_service.dart';
import 'package:dios_delices/services/session_service.dart';

class Category {
  final String id;
  final int categoryID;
  final String name;

  const Category({this.id = '', required this.categoryID, required this.name});

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id']?.toString() ?? '',
      categoryID: int.tryParse(map['categoryID']?.toString() ?? map['categoryId']?.toString() ?? '0') ?? 0,
      name: map['name']?.toString() ?? '',
    );
  }
}

class CategoryService {
  const CategoryService._();

  static Future<List<Category>> getAllCategories() async {
    try {
      final token = await SessionService.readNodeToken();
      if (token == null) return [];
      
      final response = await NodeAuthService.getJson('/categories', token: token);
      final data = response['data'];
      
      if (data != null && data is List) {
        return data.map((item) => Category.fromMap(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      // Ignore et retourne une liste vide
    }
    return [];
  }

  static Future<bool> addCategory(String name) async {
    try {
      final token = await SessionService.readNodeToken();
      if (token == null) return false;

      final response = await NodeAuthService.postJson(
        '/categories',
        token: token,
        body: {'name': name},
      );
      
      return response['data'] != null;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteCategory(int categoryID) async {
    try {
      final token = await SessionService.readNodeToken();
      if (token == null) return false;

      final all = await getAllCategories();
      final category = all.firstWhere((c) => c.categoryID == categoryID, orElse: () => const Category(categoryID: 0, name: ''));
      if (category.categoryID == 0 || category.id.isEmpty) return false;

      await NodeAuthService.deleteJson('/categories/${category.id}', token: token);
      return true;
    } catch (e) {
      return false;
    }
  }
}
