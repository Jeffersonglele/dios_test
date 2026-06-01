import 'package:dios_delices/Screen/Settings.dart';
import 'package:dios_delices/Screen/restaurants/RestaurantDetails.dart';
import 'package:dios_delices/Screen/ContactPage.dart';
import 'package:flutter/material.dart';
import '../components/Logout.dart';

import 'UserOrdersPage.dart';
import '../services/session_service.dart';

class MyStore extends StatefulWidget {
  const MyStore({super.key});

  @override
  _MyStoreState createState() => _MyStoreState();
}

class _MyStoreState extends State<MyStore> {
  List sections = [];
  static const String logoutLabel = "DÉCONNEXION";

  @override
  void initState() {
    super.initState();
    loadRestaurantID();

    sections = [
      {
        "icon": Icons.restaurant,
        "description": "Mon restaurant",
        "page": null,
      },
      {
        "icon": Icons.fastfood_rounded,
        "description": "Mes commandes",
        "page": const UserOrdersPage(showRestaurantOrders: true),
      },
      {
        "icon": Icons.contact_support,
        "description": "Nous contacter",
        "page": const ContactPage(),
      },
      {
        "icon": Icons.settings,
        "description": "Paramètres",
        "page": Settings(),
      },
      {
        "icon": Icons.logout,
        "description": logoutLabel,
        "page": null,
      },
    ];
  }

  Future<void> loadRestaurantID() async {
    final session = await SessionService.readSession();
    final currentUserRestau = session.restaurantId;

    if (currentUserRestau != null) {
      setState(() {
        sections[0]["page"] =
            RestaurantDetails(restaurant_id: currentUserRestau);
      });
    } else {
      setState(() {
        // Soit on désactive le bouton, soit on met une page vide
        sections[0]["page"] = null;
      });
    }
  }

  void _openSection(int index) {
    if (sections[index]["description"] == logoutLabel) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => LogoutFormDialog(),
      );
      return;
    }

    final page = sections[index]["page"];
    if (page == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Aucune donnée de restaurant disponible."),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => page,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Column(
          children: <Widget>[
            SizedBox(
              height: size.height * 0.06,
            ),
            Expanded(
              // Limite la hauteur de ListView pour éviter d'écraser la barre de navigation
              child: ListView.separated(
                scrollDirection: Axis.vertical,
                itemCount: sections.length,
                separatorBuilder: (BuildContext context, int index) {
                  return SizedBox(
                    height: 50,
                  );
                },
                itemBuilder: (context, index) {
                  return Container(
                    height: 60,
                    margin: const EdgeInsets.only(right: 30, left: 30),
                    child: ElevatedButton(
                      onPressed: () => _openSection(index),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 241, 235, 235),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              sections[index]["icon"],
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Text(
                              sections[index]["description"],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 27,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
