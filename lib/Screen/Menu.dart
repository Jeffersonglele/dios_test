import 'dart:convert';

import 'package:count_stepper/count_stepper.dart';
import 'package:dios_delices/Screen/FoodDetails.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../Constant/Constant.dart';
import '../Controller/UiController.dart';

class Menu extends StatefulWidget {
  @override
  _MenuState createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  TextEditingController totalController = TextEditingController();

  @override
  void dispose() {
    totalController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    getMeals();
  }

  List _items_meals = [];

  SimpleUIController simpleUIController = Get.put(SimpleUIController());

  Future<void> getMeals() async {
    final String response =
        await rootBundle.loadString('assets/static_data/Meals.json');
    final data = await json.decode(response);
    setState(() {
      _items_meals = data["items"];
    });
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return new WillPopScope(
      onWillPop: () async => false,
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
            backgroundColor: Colors.white,
            resizeToAvoidBottomInset: false,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: size.width > 600
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                SizedBox(
                  height: size.height * 0.01,
                ),
                Row(
                  children: [
                    SizedBox(width: 25),
                    Spacer(),
                    Tooltip(
                      message: "Add a meal to your menu",
                      child: ElevatedButton(
                        onPressed: () {},
                        child: Icon(Icons.add, color: Colors.white),
                        style: ElevatedButton.styleFrom(
                            shape: CircleBorder(),
                            padding: EdgeInsets.all(20),
                            backgroundColor: Colors.red),
                      ),
                    ),
                    SizedBox(width: 25),
                  ],
                ),
                SizedBox(
                  height: size.height * 0.03,
                ),
                Flexible(
                  child: ListView.builder(
                    scrollDirection: Axis.vertical,
                    shrinkWrap: true,
                    itemCount: _items_meals.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                          onTap: () => {
                                Navigator.push(
                                    context,
                                    CupertinoPageRoute(
                                        builder: (ctx) => FoodDetails(
                                            from_page: 2,
                                            meal_id: _items_meals[index]
                                                ["id"])))
                              },
                          child: Column(
                            children: [
                              Card(
                                elevation: 4.0,
                                child: Column(
                                  children: [
                                    Container(
                                      height: 200.0,
                                      child: Ink.image(
                                        image: AssetImage(
                                          _items_meals[index]["image"],
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.all(16.0),
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _items_meals[index]["meal_name"],
                                        style: kLoginSubtitleStyle3(size),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 15,
                                        ),
                                        Text(
                                          _items_meals[index]["price"]
                                                  .toString() +
                                              " " +
                                              _items_meals[index]["currency"],
                                          style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20),
                                        ),
                                        Spacer(),
                                        IconButton(
                                          onPressed: () async {},
                                          icon: Icon(
                                            Icons.navigate_next,
                                            color: Colors.black,
                                            size: 40,
                                          ),
                                        ),
                                        SizedBox(
                                          width: 15,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: 50,
                              )
                            ],
                          ));
                    },
                  ),
                ),
              ],
            )),
      ),
    );
  }

  Widget invisibleButton() {
    return SizedBox(
      width: double.infinity,
      height: 20,
      child: ElevatedButton(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(Colors.white),
        ),
        onPressed: () {},
        child: const Text(''),
      ),
    );
  }
}
