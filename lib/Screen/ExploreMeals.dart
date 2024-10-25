import 'dart:convert';

import 'package:dios_delices/Screen/curved_navigation/CurvedNavigation.dart';
import 'package:dios_delices/Screen/FoodDetails.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';

import '../Constant/Constant.dart';
import '../Controller/UiController.dart';

class ExploreMeals extends StatefulWidget {
  const ExploreMeals({Key? key}) : super(key: key);

  @override
  State<ExploreMeals> createState() => _ExploreMealsState();
}

class _ExploreMealsState extends State<ExploreMeals> {
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
        await rootBundle.loadString('assets/static_data/Meals.json');
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
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: size.width > 600
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              SizedBox(
                height: size.height * 0.06,
              ),
              Row(
                children: [
                  SizedBox(width: 25),
                  Text(
                    'Exploring...',
                    style: bigTitleStyle(size),
                  ),
                ],
              ),
              SizedBox(
                height: size.height * 0.03,
              ),
              Flexible(
                  child: ListView.builder(
                scrollDirection: Axis.vertical,
                shrinkWrap: true,
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                      onTap: () => {
                            Navigator.push(
                                context,
                                CupertinoPageRoute(
                                    builder: (ctx) => FoodDetails(
                                        from_page: 3,
                                        meal_id: _items[index]["id"])))
                          },
                      child: Card(
                        semanticContainer: true,
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                        margin: new EdgeInsets.only(bottom: 20.0, right: 20.0),
                        elevation: 3.0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(50.0)),
                        ),
                        child: Column(
                          children: [
                            Image.asset(_items[index]["image"],
                                height: 200, width: 300, fit: BoxFit.fitWidth),
                            ListTile(
                              title: Text(_items[index]["meal_name"]),
                              subtitle: Text(
                                _items[index]["price"].toString() +
                                    " " +
                                    _items[index]["currency"],
                                style: TextStyle(
                                    color: Colors.red.withOpacity(0.6)),
                              ),
                            ),
                          ],
                        ),
                      ));
                },
              )),
              SizedBox(
                height: size.height * 0.03,
              ),
              invisibleButton(theme),
            ],
          )),
    );
  }

  Widget invisibleButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 55,
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
