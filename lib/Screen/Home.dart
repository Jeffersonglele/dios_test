import 'dart:convert';

import 'package:dios_delices/Screen/ExploreMeals.dart';
import 'package:dios_delices/Screen/FoodCategories.dart';
import 'package:dios_delices/Screen/DishDetails.dart';
import 'package:dios_delices/Screen/NearMeMeals.dart';
import 'package:dios_delices/SearchInput.dart';
import 'package:flutter/cupertino.dart';
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

    return WillPopScope(
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

  Widget _buildSmallScreen(
      Size size, SimpleUIController simpleUIController, ThemeData theme) {
    return Center(
      child: _buildMainBody(size, simpleUIController, theme),
    );
  }

  Widget _buildMainBody(
      Size size, SimpleUIController simpleUIController, ThemeData theme) {
    return Column(
      children: <Widget>[
        SearchInput(),
        SizedBox(height: size.height * 0.02),
        StreamBuilder(
          stream: Stream.periodic(const Duration(seconds: 1)),
          builder: (context, snapshot) {
            DateTime now = DateTime.now();
            String hour = "${now.hour}:${now.minute}:${now.second}";
            String parsedHour = DateFormat.jm().format(DateFormat("hh:mm:ss").parse(hour));

            return Row(
              children: [
                SizedBox(width: 25),
                Icon(Icons.today),
                Expanded(
                  child: Text(
                    "  ${now.day} ${_getMonthName(now.month)} ${now.year}, $parsedHour",
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        ),
        SizedBox(height: size.height * 0.03),
        _buildSectionTitle(size, 'Popular meals'),
        SizedBox(height: size.height * 0.06),
        _buildSectionTitle(size, 'Near you', actionText: "See more", onTap: () {
          Navigator.push(context, CupertinoPageRoute(builder: (ctx) => NearMeMeals()));
        }),
        SizedBox(height: size.height * 0.03),
        _buildMealsGrid(size),
        SizedBox(height: size.height * 0.05),
        _buildSectionTitle(size, 'Explore', actionText: "See more", onTap: () {
          Navigator.push(context, CupertinoPageRoute(builder: (ctx) => ExploreMeals()));
        }),
        SizedBox(height: size.height * 0.03),
        _buildMealsGrid(size),
        SizedBox(height: size.height * 0.03),
        ElevatedButton(
          onPressed: () {
            Navigator.push(context, CupertinoPageRoute(builder: (ctx) => FoodCategories()));
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
        SizedBox(height: 55,)
      ],
    );
  }

  Widget _buildSectionTitle(Size size, String title, {String? actionText, void Function()? onTap}) {
    return Row(
      children: [
        SizedBox(width: 25),
        Text(title, style: bigTitleStyle(size)),
        if (actionText != null)
          Spacer(),
        if (onTap != null)
          GestureDetector(
            onTap: onTap,
            child: Text(
              actionText!,
              style: TextStyle(
                fontSize: 15,
                color: Colors.red,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMealsGrid(Size size) {
    return _items.isNotEmpty
        ? Container(
      height: 200,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 3 / 4.5,
          crossAxisSpacing: 10,
          mainAxisSpacing: 20,
        ),
        itemCount: 3,
        itemBuilder: (BuildContext ctx, index) {
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (ctx) => DishDetails(from_page: 1, dish_id: _items[index]["id"]),
              ),
            ),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Image.asset(
                    _items[index]["image"],
                    height: 100,
                    width: 120,
                    fit: BoxFit.cover,
                  ),
                  ListTile(
                    title: Text(_items[index]["meal_name"]),
                    subtitle: Text(
                      "${_items[index]["price"]} ${_items[index]["currency"]}",
                      style: TextStyle(color: Colors.red.withOpacity(0.6)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    )
        : Container();
  }

  String _getMonthName(int month) {
    List<String> monthNames = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];
    return monthNames.elementAt(month - 1);
  }
}
