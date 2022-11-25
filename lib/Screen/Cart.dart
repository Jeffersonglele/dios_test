import 'dart:convert';

import 'package:count_stepper/count_stepper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../Constant/Constant.dart';
import '../Controller/UiController.dart';

class Cart extends StatefulWidget {
  @override
  _CartState createState() => _CartState();
}

class _CartState extends State<Cart> {
  TextEditingController totalController = TextEditingController();

  @override
  void dispose() {
    totalController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    getOrders();
    getOrdersDetails();
    getMeals();
    getDeliveriesTypes();
  }

  List _items_orders = [];
  List _items_orders_details = [];
  List _items_meals = [];
  List _items_deliveries_types = [];
  List _current_orders = [];
  List _current_meals = [];
  var _current_order_details = {};
  var selected = {};
  var number_of_parts = 1;
  var total = 0.0;
  var _valueCheck;

  SimpleUIController simpleUIController = Get.put(SimpleUIController());

  Future<void> getOrders() async {
    final String response =
        await rootBundle.loadString('assets/static_data/Orders.json');
    final data = await json.decode(response);
    setState(() {
      _items_orders = data["items"];
    });
  }

  Future<void> getOrdersDetails() async {
    final String response =
        await rootBundle.loadString('assets/static_data/OrdersDetails.json');
    final data = await json.decode(response);
    setState(() {
      _items_orders_details = data["items"];
    });
  }

  Future<void> getMeals() async {
    final String response =
        await rootBundle.loadString('assets/static_data/Meals.json');
    final data = await json.decode(response);
    setState(() {
      _items_meals = data["items"];
    });
  }

  Future<void> getDeliveriesTypes() async {
    final String response =
        await rootBundle.loadString('assets/static_data/DeliveriesTypes.json');
    final data = await json.decode(response);
    setState(() {
      _items_deliveries_types = data["items"];
    });
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    var theme = Theme.of(context);

    _get_current_order_details();

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
      SizedBox(
        height: size.height * 0.06,
      ),
      _current_orders.isNotEmpty
          ? SizedBox(
              child: ListView.builder(
                  scrollDirection: Axis.vertical,
                  shrinkWrap: true,
                  itemCount: _current_meals.length,
                  itemBuilder: (context, index) {
                    return Container(
                      child: Card(
                        color: Color.fromARGB(255, 240, 238, 238),
                        clipBehavior: Clip.antiAlias,
                        margin: new EdgeInsets.only(
                            left: 50.0, bottom: 20.0, right: 50.0),
                        child: ListTile(
                          leading: SizedBox(
                            width: 100,
                            height: 150,
                            child: Image.asset(
                                _current_meals[index]["meal"]["image"],
                                fit: BoxFit.fitWidth),
                          ),
                          title: Text(
                            _current_meals[index]["meal"]["meal_name"],
                            style: TextStyle(color: Colors.black, fontSize: 15),
                          ),
                          subtitle: Row(
                            children: [
                              Text(
                                _current_meals[index]["meal"]["price"]
                                        .toString() +
                                    " " +
                                    _current_meals[index]["meal"]["currency"],
                                style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold),
                              ),
                              Spacer(),
                              Container(
                                padding: EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    color: Color.fromARGB(255, 193, 188, 193)),
                                child: CountStepper(
                                  iconColor: Colors.black,
                                  defaultValue: _current_meals[index]["order"]
                                      ["quantity"],
                                  max: _current_meals[index]["meal"]
                                      ["number_of_servings"],
                                  min: 1,
                                  iconDecrementColor: Colors.black,
                                  splashRadius: 25,
                                  onPressed: (value) {
                                    if (value <
                                        _current_meals[index]["order"]
                                            ["quantity"]) {
                                      setState(() {
                                        total = total -
                                            _current_meals[index]["meal"]
                                                ["price"];
                                      });
                                    } else {
                                      setState(() {
                                        total = total +
                                            _current_meals[index]["meal"]
                                                ["price"];
                                      });
                                    }
                                  },
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  }))
          : Container(
              height: 400,
            ),
      SizedBox(
        height: size.height * 0.01,
      ),
      Row(
        children: [
          SizedBox(width: 20),
          Spacer(),
          Text(
            "TOTAL:  ",
            style: kLoginSubtitleStyle3(size),
          ),
          Text(
            total.toString() + _current_meals[0]["meal"]["currency"],
            style: TextStyle(
                color: Colors.red, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(width: 45),
        ],
      ),
      invisibleButton(),
      SizedBox(
        height: 5,
      ),
      Column(
        children: <Widget>[
          for (int i = 0, j = _items_deliveries_types.length; i < j; i++)
            Column(
              children: [
                RadioListTile(
                  title: Row(
                    children: <Widget>[
                      Expanded(
                        flex: 3,
                        child: Text(
                          _items_deliveries_types[i]["description"],
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.black, fontSize: 18.0),
                        ),
                      )
                    ],
                  ),
                  value: _items_deliveries_types[i]["id"],
                  groupValue: _valueCheck,
                  onChanged: (value) {
                    setState(() {
                      _valueCheck = value;
                    });
                  },
                ),
              ],
            )
        ],
      ),
      SizedBox(
        height: size.height * 0.08,
      ),
      Center(
        child: ElevatedButton(
          onPressed: () {},
          child: Text(
            'Place Order',
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
          style: ElevatedButton.styleFrom(
            elevation: 5,
            fixedSize: const Size(300, 60),
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ),
      SizedBox(
        height: size.height * 0.08,
      ),
    ]);
  }

  _get_current_order_details() async {
    var id = 6;
    for (var i = 0, j = _items_orders_details.length; i < j; i++) {
      if (_items_orders_details[i]["id"] == id) {
        setState(() {
          _current_order_details = _items_orders_details[i];

          _get_current_orders(_items_orders_details[i]);
        });
      }
    }
  }

  _get_current_orders(order) async {
    var tab = [];
    var r = 0;

    for (var i = 0, j = order["lines"].length; i < j; i++) {
      for (var m = 0, n = _items_orders.length; m < n; m++) {
        if (_items_orders[m]["id"] == order["lines"][i]) {
          tab.add(_items_orders[m]);

          r++;
          if (r == order["lines"].length) {
            setState(() {
              _current_orders = tab;
              _get_current_Meals(tab);
            });
          }
        }
      }
    }
  }

  _get_current_Meals(orders) async {
    var tab = [];
    var tmp = 0.0;
    var r = 0;
    for (var i = 0, j = orders.length; i < j; i++) {
      for (var m = 0, n = _items_meals.length; m < n; m++) {
        if (orders[i]["meal_id"] == _items_meals[m]["id"]) {
          tab.add({"order": orders[i], "meal": _items_meals[m]});

          tmp = tmp + (orders[i]["quantity"] * _items_meals[m]["price"]);
          r++;
          if (r == orders.length) {
            setState(() {
              _current_meals = tab;
              total = tmp;
            });
          }
        }
      }
    }
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
