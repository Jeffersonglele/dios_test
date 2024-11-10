import 'dart:convert';

import 'package:dios_delices/Screen/MealsOfACategory.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';

import '../Constant/Constant.dart';
import '../Controller/UiController.dart';

class FoodCategories extends StatefulWidget {
  @override
  State<FoodCategories> createState() => _FoodCategoriesState();
}

class _FoodCategoriesState extends State<FoodCategories> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    readJson();
  }

  List _items = [];
  SimpleUIController simpleUIController = Get.put(SimpleUIController());

  Future<void> readJson() async {
    final String response =
        await rootBundle.loadString('assets/static_data/FoodCategories.json');
    final data = await json.decode(response);
    setState(() {
      _items = data["items"];
    });
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    var theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(),
        body: SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: size.height * 0.06,
              ),
              Row(
                children: [
                  SizedBox(width: 25),
                  Text(
                    'Food categories',
                    style: bigTitleStyle(size),
                  ),
                ],
              ),
              SizedBox(
                height: size.height * 0.03,
              ),
              ListView.separated(
                scrollDirection: Axis.vertical,
                shrinkWrap: true,
                itemCount: _items.length,
                separatorBuilder: (BuildContext context, int index) {
                  return SizedBox(
                    height: 25,
                  );
                },
                itemBuilder: (context, index) {
                  return Container(
                    height: 60,
                    margin: const EdgeInsets.only(right: 30, left: 30),
                    child:
                        /*ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacementNamed(
                                MEALS_OF_A_CATEGORY,
                                arguments: ScreenArguments(
                                    _items[index]["id"], 1, ""));
                          },
                          child: SizedBox(
                            height: 70,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                SizedBox(
                                  width: 5,
                                ),
                                Text(
                                  _items[index]["category"],
                                  style: TextStyle(
                                      color: Colors.black, fontSize: 25),
                                ),
                                Spacer(),
                                Icon(
                                  Icons.navigate_next,
                                  size: 24.0,
                                  color: Colors.black,
                                ),
                                SizedBox(
                                  width: 5,
                                ),
                              ],
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.fromARGB(255, 233, 228, 228),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ))*/
                        ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                            context,
                            CupertinoPageRoute(
                                builder: (ctx) => MealsOfACategory(
                                    category_id: _items[index]["id"])));
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 241, 235, 235),
                          shape: StadiumBorder()),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 5,
                          ),
                          Text(
                            _items[index]["category"],
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 30,
                                fontWeight: FontWeight.bold),
                          ),
                          Spacer(),
                          Icon(
                            Icons.navigate_next,
                            size: 24.0,
                            color: Colors.black,
                          ),
                          SizedBox(
                            width: 5,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 55,)
            ],
          ),
        ),
      ),
    );
  }
}
