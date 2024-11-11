import 'dart:convert';

import 'package:dios_delices/Screen/FoodCategories.dart';
import 'package:dios_delices/Screen/DishDetails.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';

import '../Constant/Constant.dart';
import '../Controller/UiController.dart';

class MealsOfACategory extends StatefulWidget {
  final int category_id;

  MealsOfACategory({required this.category_id});

  @override
  State<MealsOfACategory> createState() => _MealsOfACategoryState();
}

class _MealsOfACategoryState extends State<MealsOfACategory> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    getCategories();
    getMeals();
  }

  List _items_meals = [];
  List _items_categories = [];

  var _category_details = {};
  List _meals_of_category = [];

  SimpleUIController simpleUIController = Get.put(SimpleUIController());

  Future<void> getMeals() async {
    final String response =
        await rootBundle.loadString('assets/static_data/Meals.json');
    final data = await json.decode(response);
    setState(() {
      _items_meals = data["items"];
    });
  }

  Future<void> getCategories() async {
    final String response =
        await rootBundle.loadString('assets/static_data/FoodCategories.json');
    final data = await json.decode(response);
    setState(() {
      _items_categories = data["items"];
    });
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    var theme = Theme.of(context);

    _getCategoryDetails();
    _getMealsByCategoryId();

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: size.height * 0.06,
            ),
            Row(
              children: [
                SizedBox(
                  width: 20,
                ),
                Expanded(
                  child: Text(
                    _category_details["category"] + "'s meals",
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: bigTitleStyle(size),
                  ),
                ),
                SizedBox(
                  width: 20,
                ),
              ],
            ),
            SizedBox(
              height: size.height * 0.03,
            ),
            _meals_of_category.isNotEmpty
                ? Flexible(
                    child: ListView.builder(
                    scrollDirection: Axis.vertical,
                    shrinkWrap: true,
                    itemCount: _meals_of_category.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () => {
                          Navigator.push(
                              context,
                              CupertinoPageRoute(
                                  builder: (ctx) => DishDetails(
                                      from_page: 4,
                                      dish_id: _meals_of_category[index]
                                          ["id"])))
                        },
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          margin: new EdgeInsets.only(
                              left: 50.0, bottom: 20.0, right: 50.0),
                          child: Column(
                            children: [
                              Image.asset(_meals_of_category[index]["image"],
                                  height: 200,
                                  width: 300,
                                  fit: BoxFit.fitWidth),
                              ListTile(
                                title: Text(
                                    _meals_of_category[index]["meal_name"]),
                                subtitle: Text(
                                  _meals_of_category[index]["price"]
                                          .toString() +
                                      " " +
                                      _meals_of_category[index]["currency"],
                                  style: TextStyle(
                                      color: Colors.red.withOpacity(0.6)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ))
                : Container(
                    height: 600,
                  ),
            SizedBox(height: 55,)
          ],
        ),
      ),
    );
  }

  _getCategoryDetails() async {
    var id = widget.category_id;
    for (var i = 0, j = _items_categories.length; i < j; i++) {
      if (_items_categories[i]["id"] == id) {
        setState(() {
          _category_details = _items_categories[i];
        });
      }
    }
  }

  _getMealsByCategoryId() async {
    var id = widget.category_id;
    List tab = [];
    var p = 0;

    for (var i = 0, j = _items_meals.length; i < j; i++) {
      if (_items_meals[i]["category_id"] == id) {
        tab.add(_items_meals[i]);
      }
      p++;

      if (p == _items_meals.length) {
        setState(() {
          _meals_of_category = tab;
        });
      }
    }
  }
}
