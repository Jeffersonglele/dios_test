import 'dart:convert';
import 'package:dios_delices/Screen/MealsOfACategory.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FoodCategories extends StatefulWidget {
  const FoodCategories({super.key});
  @override
  State<FoodCategories> createState() => _FoodCategoriesState();
}

class _FoodCategoriesState extends State<FoodCategories> {
  List _items = [];

  @override
  void initState() {
    super.initState();
    readJson();
  }

  Future<void> readJson() async {
    final response = await rootBundle.loadString('assets/static_data/FoodCategories.json');
    final data = await json.decode(response);
    if (mounted) setState(() => _items = data["items"]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Catégories')),
      body: _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => Navigator.push(context,
                    CupertinoPageRoute(builder: (_) => MealsOfACategory(category_id: _items[i]["id"]))),
                child: Container(
                  height: 68,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Row(children: [
                    Icon(Icons.restaurant_rounded, color: AppColors.brand),
                    const SizedBox(width: 14),
                    Text(_items[i]["category"],
                        style: AppTypography.titleMedium().copyWith(fontSize: 20)),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.inkSubtle),
                  ]),
                ),
              ),
            ),
    );
  }
}
