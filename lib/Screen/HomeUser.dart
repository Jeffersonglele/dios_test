import 'package:dios_delices/Screen/FoodCategories.dart';
import 'package:dios_delices/Screen/NearMeMeals.dart';
import 'package:dios_delices/Screen/restaurants/NearMeRestaurants.dart';
import 'package:dios_delices/Screen/restaurants/RestaurantDetails.dart';
import 'package:dios_delices/SearchInput.dart';
import 'package:dios_delices/modeles/address.dart';
import 'package:dios_delices/utils/DateTime.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Constant/Constant.dart';
import '../Controller/UiController.dart';
import '../modeles/restaurant.dart';
import '../modeles/users.dart';
import 'dart:math';

class HomeUser extends StatefulWidget {
  @override
  _HomeUserState createState() => _HomeUserState();
}

class _HomeUserState extends State<HomeUser> {
  @override
  void initState() {
    super.initState();
    loadData();
  }

  List<Map<String, dynamic>> filteredRestaurants = [];
  List<Users> users = [];
  List<Restaurant> restaus = [];
  List<Address> addresses = [];

  int current_userID = 0;
  int current_user_role = 0;
  int current_user_restau = 0;

  SimpleUIController simpleUIController = Get.put(SimpleUIController());

  void loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int userID = prefs.getInt('loggedUserID') ?? 0;
    int userRole = prefs.getInt('currentUser_role') ?? 0;
    int userRestauID = prefs.getInt('currentUser_restau') ?? 0;

    List<Users> usersList = await Users.fetchUsersFromDB();
    List<Restaurant> restausList = await Restaurant.fetchRestaurantsFromDB();
    List<Address> addressesList = await Address.fetchAddressesFromDB();

    setState(() {
      current_userID = userID;
      current_user_role = userRole;
      current_user_restau = userRestauID;

      users = usersList;
      restaus = restausList;
      addresses = addressesList;
    });
    await _filterRestaurants();
  }

  Future<void> _filterRestaurants() async {
    for (var a in addresses) {
      if (a.objectID == current_userID && a.object == "User") {
        Address userAddress = a;

        const double maxDistanceKm = 10.0;
        List<Restaurant> nearbyRestaurants = [];

        for (var restau in restaus) {
          print("restau " + restau.restaurantID.toString());
          // 🔥 1. Récupérer l'utilisateur du restaurant
          Users? associatedUser = Users.getUsersByUserId(users, restau.userID);

          // 🔥 2. Vérifier si c'est le restau de l'user
          if (associatedUser == null || restau.userID == current_userID) {
            continue; // ❌ Exclure ce restaurant
          }

          // 🔥 3. Chercher l'adresse du restaurant
          Address? restauAddress = Address.getAddressByObject(addresses, "User", restau.userID);

          if (restauAddress == null) continue;

          try {
            double userLat = double.parse(userAddress.lat ?? "");
            double userLon = double.parse(userAddress.long ?? "");
            double restauLat = double.parse(restauAddress.lat ?? "");
            double restauLon = double.parse(restauAddress.long ?? "");

            double distance = _calculateDistance(userLat, userLon, restauLat, restauLon);

            if (distance <= maxDistanceKm) {
              nearbyRestaurants.add(restau);
            }
          } catch (e) {
            print("Erreur de parsing des coordonnées : $e");
          }
        }

        setState(() {
          restaus = nearbyRestaurants;
        });
      }
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Rayon de la Terre en kilomètres

    double dLat = _degToRad(lat2 - lat1);
    double dLon = _degToRad(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degToRad(double deg) {
    return deg * (pi / 180);
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
        DateTimeDisplay(),
        SizedBox(height: size.height * 0.06),
        _buildSectionTitle(size, 'Restaurants près de chez vous', actionText: "Voir plus",
            onTap: () {
          Navigator.push(
              context, CupertinoPageRoute(builder: (ctx) => NearMeRestaurants()));
        }),
        SizedBox(height: size.height * 0.03),
        _buildMealsGrid(size),
        SizedBox(height: size.height * 0.05),
        _buildSectionTitle(size, 'Plats près de chez vous', actionText: "Voir plus",
            onTap: () {
              print("NearMeMeals");
              Navigator.push(
                  context, CupertinoPageRoute(builder: (ctx) => NearMeMeals()));
            }),
        SizedBox(height: size.height * 0.03),
        ElevatedButton(
          onPressed: () {
            Navigator.push(context,
                CupertinoPageRoute(builder: (ctx) => FoodCategories()));
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
        SizedBox(
          height: 55,
        )
      ],
    );
  }

  Widget _buildSectionTitle(Size size, String title,
      {String? actionText, void Function()? onTap}) {
    return Row(
      children: [
        SizedBox(width: 25),
        Text(title, style: kLoginSubtitleStyle5(size)),
        if (actionText != null) Spacer(),
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
        SizedBox(width: 25),
      ],
    );
  }

  Widget _buildMealsGrid(Size size) {
    return restaus.isNotEmpty
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
              itemCount: restaus.length > 5 ? 5 : restaus.length,
              itemBuilder: (BuildContext ctx, index) {
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (ctx) => RestaurantDetails(
                          restaurant_id: restaus[index].restaurantID),
                    ),
                  ),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 2,
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          // ⬅️ ajuste ici le degré d'arrondi
                          child: Image.network(
                            (restaus[index].image != null && restaus[index].image!.trim().isNotEmpty)
                                ? restaus[index].image!
                                : "https://parsefiles.back4app.com/9qBeGGwSGOQ1iWOJ1UNUXt40NhgwwgbHJYGpV1zg/4f636282d677d999cd624580cdec2ff7_no_image.png",
                            height: 150,
                            width: 170,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Image.asset(
                                'assets/images/no_image.png',
                                height: 150,
                                width: 170,
                                fit: BoxFit.cover,
                              );
                            },
                          ),
                        ),
                        ListTile(
                          title: Text(restaus[index].name),
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
}
