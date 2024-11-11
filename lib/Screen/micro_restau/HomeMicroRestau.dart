import 'dart:convert';

import 'package:dios_delices/Screen/DishDetails.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../Constant/Constant.dart';
import '../../Controller/UiController.dart';

class HomeMicroRestau extends StatefulWidget {
  @override
  _HomeMicroRestauState createState() => _HomeMicroRestauState();
}

class _HomeMicroRestauState extends State<HomeMicroRestau> {
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
        SizedBox(height: size.height * 0.02),
        // Date et heure actuelles
        StreamBuilder(
          stream: Stream.periodic(const Duration(seconds: 1)),
          builder: (context, snapshot) {
            DateTime now = DateTime.now();

            // Format pour l'heure (hh:mm:ss en format français)
            String parsedHour = DateFormat('HH:mm', 'fr').format(now);

            // Format pour la date avec le mois en français
            String formattedDate = DateFormat('d MMMM y', 'fr').format(now);

            return Row(
              children: [
                SizedBox(width: 25),
                Icon(Icons.today),
                Text(
                  "  $formattedDate, $parsedHour",
                  style: TextStyle(fontSize: 16),
                ),
              ],
            );
          },
        ),
        SizedBox(
          height: 10,
        )
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
