import 'package:dios_delices/Screen/FoodDetails.dart';
import 'package:dios_delices/Screen/dish/DishFormPage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Constant/Constant.dart';
import '../Controller/UiController.dart';
import '../modeles/dish.dart';

class Menu extends StatefulWidget {
  @override
  _MenuState createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  String? country = "";
  int currentUser_restau = 0;

  TextEditingController totalController = TextEditingController();

  List<Dish> dishes = [];
  List<Dish> filteredDishes = []; // Change Map to Dish to directly hold Dish objects

  @override
  void dispose() {
    totalController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    loadData();
  }

  void loadData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    country = prefs.getString('currentUser_country');
    currentUser_restau = prefs.getInt('currentUser_restau') ?? 0;

    // Chargement des données Dish depuis la base de données
    List<Dish> dishesList = await Dish.fetchDishesFromDB();

    setState(() {
      dishes = dishesList;
      print("dishes " + dishes.toString());
      _fetchDishesByRestaurant();
    });
  }

  void _fetchDishesByRestaurant() {
    filteredDishes = dishes.where((dish) => dish.restauID == currentUser_restau).toList();
  }

  SimpleUIController simpleUIController = Get.put(SimpleUIController());

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return WillPopScope(
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
              SizedBox(height: size.height * 0.01),
              Row(
                children: [
                  SizedBox(width: 25),
                  Text(
                    'Votre Menu',
                    style: kLoginSubtitleStyle(size),
                  ),
                  Spacer(),
                  Tooltip(
                    message: "Ajouter un plat",
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => DishFormPage(),
                          ),
                        );
                      },
                      child: Icon(Icons.add, color: Colors.white),
                      style: ElevatedButton.styleFrom(
                        shape: CircleBorder(),
                        padding: EdgeInsets.all(20),
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ),
                  SizedBox(width: 25),
                ],
              ),
              SizedBox(height: size.height * 0.03),
              Flexible(
                child: ListView.builder(
                  scrollDirection: Axis.vertical,
                  shrinkWrap: true,
                  itemCount: filteredDishes.length, // Use filteredDishes here
                  itemBuilder: (context, index) {
                    final dish = filteredDishes[index]; // Access filteredDishes
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (ctx) => FoodDetails(
                              from_page: 2,
                              meal_id: dish.dishID, // Passer l'ID du plat
                            ),
                          ),
                        );
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
                                    image: dish.image != null && dish.image.isNotEmpty
                                        ? NetworkImage(dish.image)
                                        : AssetImage('assets/images/placeholder.png')
                                    as ImageProvider,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.all(16.0),
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    dish.name,
                                    style: kLoginSubtitleStyle3(size),
                                  ),
                                ),
                                Row(
                                  children: [
                                    SizedBox(width: 15),
                                    Text(
                                      "${dish.price} ${country == "France " ? "€" : 'FCFA'}",
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
                                    Spacer(),
                                    IconButton(
                                      onPressed: () {},
                                      icon: Icon(
                                        Icons.navigate_next,
                                        color: Colors.black,
                                        size: 40,
                                      ),
                                    ),
                                    SizedBox(width: 15),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 50),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
