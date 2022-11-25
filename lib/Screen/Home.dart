import 'dart:convert';

import 'package:dios_delices/Screen/ExploreMeals.dart';
import 'package:dios_delices/Screen/FoodCategories.dart';
import 'package:dios_delices/Screen/FoodDetails.dart';
import 'package:dios_delices/Screen/NearMeMeals.dart';
import 'package:dios_delices/SearchInput.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../Constant/Constant.dart';
import '../Controller/UiController.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
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

    return new WillPopScope(
      onWillPop: () async => false,
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: false,
          body: SingleChildScrollView(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  return _buildLargeScreen(size, simpleUIController, theme);
                } else {
                  return _buildSmallScreen(size, simpleUIController, theme);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  // For large screens
  Widget _buildLargeScreen(
      Size size, SimpleUIController simpleUIController, ThemeData theme) {
    return Row(
      children: [
        SizedBox(width: size.width * 0.06),
        Expanded(
          flex: 5,
          child: _buildMainBody(size, simpleUIController, theme),
        ),
      ],
    );
  }

  // For Small screens
  Widget _buildSmallScreen(
      Size size, SimpleUIController simpleUIController, ThemeData theme) {
    return Center(
      child: _buildMainBody(size, simpleUIController, theme),
    );
  }

  // Main Body
  Widget _buildMainBody(
      Size size, SimpleUIController simpleUIController, ThemeData theme) {
    return Column(children: <Widget>[
      new SearchInput(),
      SizedBox(
        height: size.height * 0.02,
      ),
      StreamBuilder(
          stream: Stream.periodic(const Duration(seconds: 1)),
          builder: (context, snapshot) {
            DateTime now = new DateTime.now();
            String hour = now.hour.toString() +
                ":" +
                now.minute.toString() +
                ":" +
                now.second.toString();
            String parsed_hour =
                DateFormat.jm().format(DateFormat("hh:mm:ss").parse(hour));

            return Row(
              children: [
                SizedBox(width: 25),
                Icon(Icons.today),
                Text(
                  "  " +
                      now.day.toString() +
                      " " +
                      _getMonthName(now.month) +
                      " " +
                      now.year.toString() +
                      ", " +
                      parsed_hour,
                ),
              ],
            );
          }),
      SizedBox(
        height: size.height * 0.03,
      ),
      Row(
        children: [
          SizedBox(width: 25),
          Text(
            'Popular meals',
            style: bigTitleStyle(size),
          ),
        ],
      ),
      SizedBox(
        height: size.height * 0.06,
      ),
      Row(
        children: [
          SizedBox(width: 25),
          Text(
            'Near you',
            style: kLoginSubtitleStyle2(size),
          ),
        ],
      ),
      SizedBox(
        height: size.height * 0.01,
      ),
      Row(
        children: [
          SizedBox(width: 320),
          Text.rich(
            TextSpan(
                style: TextStyle(
                  fontSize: 15,
                ),
                children: [
                  TextSpan(
                      style: TextStyle(
                          color: Colors.red,
                          decoration: TextDecoration.underline),
                      //make link blue and underline
                      text: "See more",
                      recognizer: TapGestureRecognizer()
                        ..onTap = () async {
                          Navigator.push(
                              context,
                              CupertinoPageRoute(
                                  builder: (ctx) => NearMeMeals()));
                        }),

                  //more text paragraph, sentences here.
                ]),
          ),
        ],
      ),
      SizedBox(
        height: size.height * 0.03,
      ),
      _items.isNotEmpty
          ? Container(
              height: 200,
              child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      childAspectRatio: 3 / 4.5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 20),
                  itemCount: 3,
                  itemBuilder: (BuildContext ctx, index) {
                    return GestureDetector(
                      onTap: () => {
                        Navigator.push(
                            context,
                            CupertinoPageRoute(
                                builder: (ctx) => FoodDetails(
                                    from_page: 1,
                                    meal_id: _items[index]["id"])))
                      },
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            Image.asset(_items[index]["image"],
                                height: 100, width: 120, fit: BoxFit.fitWidth),
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
                      ),
                    );
                  }))
          : Container(),
      SizedBox(
        height: size.height * 0.05,
      ),
      Row(
        children: [
          SizedBox(width: 25),
          Text(
            'Explore',
            style: kLoginSubtitleStyle2(size),
          ),
        ],
      ),
      Row(
        children: [
          SizedBox(width: 320),
          Text.rich(
            TextSpan(
                style: TextStyle(
                  fontSize: 15,
                ),
                children: [
                  TextSpan(
                      style: TextStyle(
                          color: Colors.red,
                          decoration: TextDecoration.underline),
                      text: "See more",
                      recognizer: TapGestureRecognizer()
                        ..onTap = () async {
                          Navigator.push(
                              context,
                              CupertinoPageRoute(
                                  builder: (ctx) => ExploreMeals()));
                        }),

                  //more text paragraph, sentences here.
                ]),
          ),
        ],
      ),
      SizedBox(
        height: size.height * 0.03,
      ),
      _items.isNotEmpty
          ? Container(
              height: 200,
              child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      childAspectRatio: 3 / 4.5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 20),
                  itemCount: 3,
                  itemBuilder: (BuildContext ctx, index) {
                    return GestureDetector(
                      onTap: () => {
                        Navigator.push(
                            context,
                            CupertinoPageRoute(
                                builder: (ctx) => FoodDetails(
                                    from_page: 1,
                                    meal_id: _items[index]["id"])))
                      },
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            Image.asset(_items[index]["image"],
                                height: 100, width: 120, fit: BoxFit.fitWidth),
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
                      ),
                    );
                  }))
          : Container(),
      SizedBox(
        height: size.height * 0.03,
      ),
      ElevatedButton(
        onPressed: () {
          Navigator.push(
              context, CupertinoPageRoute(builder: (ctx) => FoodCategories()));
        },
        child: Text(
          'Show all food categories',
          style: TextStyle(color: Colors.red),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 5,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent.withOpacity(0.1),
          side: BorderSide(
            width: 2,
            color: Colors.red,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
      invisibleButton(),
    ]);
  }

  _getMonthName(currentMonth) {
    List<String> month_names = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ];

    return month_names.elementAt(currentMonth - 1);
  }

  Widget invisibleButton() {
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
