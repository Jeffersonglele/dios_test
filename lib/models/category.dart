import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class Category {
  final int categoryID;
  final String name;

  const Category({required this.categoryID, required this.name});

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      categoryID: int.tryParse(map['categoryID']?.toString() ?? '0') ?? 0,
      name: map['name']?.toString() ?? '',
    );
  }
}

class CategoryService {
  const CategoryService._();

  static Future<List<Category>> getAllCategories() async {
    final cloudFunction = ParseCloudFunction('getAllCategories');
    try {
      final response = await cloudFunction.execute();
      if (response.success && response.result != null) {
        final List<dynamic> dataList = response.result;
        return dataList
            .map((data) => Category.fromMap(data as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
    }
    return [];
  }

  static Future<bool> addCategory(String name) async {
    final cloudFunction = ParseCloudFunction('addCategory');
    try {
      final response =
          await cloudFunction.execute(parameters: {'name': name});
      if (response.success && response.result != null) {
        final result = response.result as Map<String, dynamic>;
        return result['success'] == true;
      }
    } catch (e) {
    }
    return false;
  }

  static Future<bool> deleteCategory(int categoryID) async {
    final cloudFunction = ParseCloudFunction('deleteCategory');
    try {
      final response =
          await cloudFunction.execute(parameters: {'categoryID': categoryID});
      if (response.success && response.result != null) {
        final result = response.result as Map<String, dynamic>;
        return result['success'] == true;
      }
    } catch (e) {
    }
    return false;
  }
}
