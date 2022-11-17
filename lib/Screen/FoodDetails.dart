import 'dart:convert';

import 'package:dios_delices/Screen/CurvedNavigation.dart';
import 'package:dios_delices/Screen/Home.dart';
import 'package:dios_delices/Screen/ScreenArguments.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:get/get.dart';

import '../Constant/Constant.dart';
import '../Controller/UiController.dart';

class FoodDetails extends StatefulWidget {
  const FoodDetails({Key? key}) : super(key: key);
  static const routeName = '/FoodDetails';

  @override
  State<FoodDetails> createState() => _FoodDetailsState();
}

var screenArguments;

class _FoodDetailsState extends State<FoodDetails> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    readJson();
  }

  var current_food = {};
  List _items = [];
  var number_of_parts = 1;

  SimpleUIController simpleUIController = Get.put(SimpleUIController());

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    var theme = Theme.of(context);
    bool isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    screenArguments =
        ModalRoute.of(context)!.settings.arguments as ScreenArguments;
    _getFoodDetailsById();

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
            leading: IconButton(
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => CurvedNavigation(),
                ),
                (route) => route.isActive);
          },
          icon: isIOS ? Icon(Icons.arrow_back_ios) : Icon(Icons.arrow_back),
        )),
        body: SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment:
          size.width > 600 ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        SizedBox(
          height: size.height * 0.06,
        ),
        Container(
          constraints: new BoxConstraints.expand(height: 300.0, width: 400),
          padding: new EdgeInsets.only(left: 16.0, bottom: 8.0, right: 16.0),
          margin: new EdgeInsets.only(left: 16.0, bottom: 8.0, right: 16.0),
          decoration: new BoxDecoration(
            image: new DecorationImage(
              image: new AssetImage(current_food["image"]),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.all(Radius.circular(30)),
          ),
          child: new Stack(
            children: <Widget>[
              new Positioned(
                right: 0.0,
                top: 5,
                child: Container(
                  width: 60,
                  decoration: new BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                    color: Colors.white,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.favorite_border_outlined,
                    ),
                    iconSize: 30,
                    color: Colors.black,
                    onPressed: () {},
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: size.height * 0.03,
        ),
        Row(
          children: [
            SizedBox(width: 25),
            Text(
              current_food["meal_name"],
              style: kLoginSubtitleStyle3(size),
            ),
            Spacer(),
            Text(
              current_food["price"].toString() + " " + current_food["currency"],
              style: TextStyle(
                  color: Colors.red, fontWeight: FontWeight.bold, fontSize: 20),
            ),
            SizedBox(width: 20),
          ],
        ),
        SizedBox(
          height: size.height * 0.03,
        ),
        Row(
          children: [
            SizedBox(
              width: 20,
            ),
            Expanded(
              child: Text(
                current_food["description"],
                maxLines: 3, // you can change it accordingly
                overflow: TextOverflow.ellipsis, // and this
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
        Row(
          children: [
            SizedBox(
              width: 20,
            ),
            ElevatedButton(
              onPressed: () {},
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See options',
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                  SizedBox(
                    width: 5,
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 24.0,
                    color: Colors.grey,
                  ),
                ],
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ],
        ),
        SizedBox(
          height: size.height * 0.03,
        ),
        Row(
          children: [
            SizedBox(
              width: 20,
            ),
            Text(
              "Quantity",
              style: kLoginSubtitleStyle4(size),
            ),
            Spacer(),
            Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Color.fromARGB(255, 225, 221, 221)),
              child: Row(
                children: [
                  InkWell(
                      onTap: () {
                        if (number_of_parts != 0) {
                          setState(() {
                            number_of_parts = number_of_parts - 1;
                          });
                        }
                      },
                      child: Icon(
                        Icons.remove,
                        color: Colors.black,
                        size: 16,
                      )),
                  SizedBox(
                    width: 10,
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 3),
                    padding: EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Color.fromARGB(255, 225, 221, 221)),
                    child: Text(
                      number_of_parts.toString(),
                      style: TextStyle(color: Colors.black, fontSize: 20),
                    ),
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  InkWell(
                      onTap: () {
                        if (number_of_parts <
                            current_food["number_of_servings"]) {
                          setState(() {
                            number_of_parts = number_of_parts + 1;
                          });
                        }
                      },
                      child: Icon(
                        Icons.add,
                        color: Colors.black,
                        size: 16,
                      )),
                ],
              ),
            ),
            SizedBox(
              width: 20,
            ),
          ],
        ),
        SizedBox(
          height: size.height * 0.08,
        ),
        Center(
          child: ElevatedButton(
            onPressed: () {},
            child: Text(
              'Add to cart',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              elevation: 5,
              fixedSize: const Size(200, 40),
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
        invisibleButton(theme),
      ],
    );
  }

  Widget invisibleButton(ThemeData theme) {
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

  _getFoodDetailsById() async {
    var id = screenArguments.getId();
    for (var i = 0, j = _items.length; i < j; i++) {
      if (_items[i]["id"] == id) {
        setState(() {
          current_food = _items[i];
        });
      }
    }
  }

  Future<void> readJson() async {
    final String response =
        await rootBundle.loadString('assets/static_data/Meals.json');
    final data = await json.decode(response);

    setState(() {
      _items = data["items"];
    });
  }
}
