import 'dart:convert';
import 'package:dios_delices/Screen/DishDetails.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ExploreMeals extends StatefulWidget {
  const ExploreMeals({super.key});
  @override
  State<ExploreMeals> createState() => _ExploreMealsState();
}

class _ExploreMealsState extends State<ExploreMeals> {
  List _items = [];

  @override
  void initState() {
    super.initState();
    readJson();
  }

  Future<void> readJson() async {
    final response = await rootBundle.loadString('assets/static_data/Meals.json');
    final data = await json.decode(response);
    if (mounted) setState(() => _items = data["items"]);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Explorer')),
      body: _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWide ? 3 : 2,
                crossAxisSpacing: 12, mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: _items.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => Navigator.push(context,
                    CupertinoPageRoute(builder: (_) => DishDetails(from_page: 3, dish_id: _items[i]["id"]))),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Stack(children: [
                        Positioned.fill(
                          child: Image.asset(_items[i]["image"], fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceWarm))),
                        Positioned(bottom: 0, left: 0, right: 0,
                          child: Container(height: 30,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.transparent, AppColors.ink.withValues(alpha: 0.3)],
                                begin: Alignment.topCenter, end: Alignment.bottomCenter)))),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text('${_items[i]["meal_name"]}\n${_items[i]["price"]} ${_items[i]["currency"]}',
                          style: AppTypography.labelMedium()),
                    ),
                  ]),
                ),
              ),
            ),
    );
  }
}
