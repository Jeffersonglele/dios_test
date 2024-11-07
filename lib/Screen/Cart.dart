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

  Future<void> getOrders() async {
    final String response = await rootBundle.loadString('assets/static_data/Orders.json');
    final data = await json.decode(response);
    setState(() {
      _items_orders = data["items"];
    });
  }

  Future<void> getOrdersDetails() async {
    final String response = await rootBundle.loadString('assets/static_data/OrdersDetails.json');
    final data = await json.decode(response);
    setState(() {
      _items_orders_details = data["items"];
    });
  }

  Future<void> getMeals() async {
    final String response = await rootBundle.loadString('assets/static_data/Meals.json');
    final data = await json.decode(response);
    setState(() {
      _items_meals = data["items"];
    });
  }

  Future<void> getDeliveriesTypes() async {
    final String response = await rootBundle.loadString('assets/static_data/DeliveriesTypes.json');
    final data = await json.decode(response);
    setState(() {
      _items_deliveries_types = data["items"];
    });
  }

  Future<void> _makePayment() async {
    setState(() {
      total = total;
    });

    final paymentIntent = await _createPaymentIntent();

    if (paymentIntent != null) {
    }
  }

  Future<Map<String, dynamic>?> _createPaymentIntent() async {
    // Implémentez un appel à votre backend pour obtenir le clientSecret
    // Exemple simplifié :
    return {
      'clientSecret': 'votre_client_secret_obtenu_du_backend',
    };
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(title: Text('Votre Panier')),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Détails de la Commande", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ListView.builder(
                scrollDirection: Axis.vertical,
                shrinkWrap: true,
                itemCount: _current_meals.length,
                itemBuilder: (context, index) {
                  return Card(
                    color: Color.fromARGB(255, 240, 238, 238),
                    margin: EdgeInsets.symmetric(vertical: 10),
                    child: ListTile(
                      leading: Image.asset(_current_meals[index]["meal"]["image"], fit: BoxFit.cover),
                      title: Text(_current_meals[index]["meal"]["meal_name"]),
                      subtitle: Row(
                        children: [
                          Text("${_current_meals[index]["meal"]["price"].toString()} ${_current_meals[index]["meal"]["currency"]}"),
                          Spacer(),
                          CountStepper(
                            iconColor: Colors.black,
                            defaultValue: _current_meals[index]["order"]["quantity"],
                            max: _current_meals[index]["meal"]["number_of_servings"],
                            min: 1,
                            onPressed: (value) {
                              setState(() {
                                final pricePerItem = _current_meals[index]["meal"]["price"];
                                final quantityDifference = value - _current_meals[index]["order"]["quantity"];
                                total += pricePerItem * quantityDifference;
                                _current_meals[index]["order"]["quantity"] = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Divider(),
              Text("Options de Livraison", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              for (var delivery in _items_deliveries_types)
                RadioListTile(
                  title: Text(delivery["description"]),
                  value: delivery["id"],
                  groupValue: _valueCheck,
                  onChanged: (value) {
                    setState(() {
                      _valueCheck = value;
                    });
                  },
                ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Total : ", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text("$total ${_current_meals[0]["meal"]["currency"]}", style: TextStyle(fontSize: 20, color: Colors.red)),
                ],
              ),
              SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _makePayment,
                  child: Text("Procéder au Paiement"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
