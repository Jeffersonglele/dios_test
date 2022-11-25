import 'dart:convert';

import 'package:dios_delices/Screen/FoodDetails.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';

import '../Constant/Constant.dart';
import '../Controller/UiController.dart';

class Favorites extends StatefulWidget {
  const Favorites({Key? key}) : super(key: key);

  @override
  State<Favorites> createState() => _FavoritesState();
}

class _FavoritesState extends State<Favorites> {
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
  var _is_liked = true;
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
                  height: size.height * 0.06,
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
                                            from_page: 5,
                                            meal_id: _items[index]["id"])))
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
                                          _items[index]["image"],
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.all(16.0),
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _items[index]["meal_name"],
                                        style: kLoginSubtitleStyle3(size),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 15,
                                        ),
                                        Text(
                                          _items[index]["price"].toString() +
                                              " " +
                                              _items[index]["currency"],
                                          style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20),
                                        ),
                                        Spacer(),
                                        IconButton(
                                          onPressed: () async {
                                            setState(() {
                                              _is_liked = !_is_liked;
                                            });
                                          },
                                          icon: Icon(
                                            _is_liked
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            color: Colors.pink,
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
                invisibleButton(theme),
              ],
            )),
      ),
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
