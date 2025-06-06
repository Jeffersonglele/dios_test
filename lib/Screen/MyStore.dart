import 'package:dios_delices/Screen/Settings.dart';
import 'package:dios_delices/Screen/restaurants/RestaurantDetails.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../components/Logout.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MyStore extends StatefulWidget {
  @override
  _MyStoreState createState() => _MyStoreState();
}

class _MyStoreState extends State<MyStore> {
  List sections = [];

  @override
  void initState() {
    super.initState();
    loadRestaurantID();

    sections = [
      {
        "icon": Icons.restaurant,
        "description": "Mon restaurant",
        "page": null, // page à mettre après récupération de l'ID
      },
      {
        "icon": Icons.fastfood_rounded,
        "description": "Mes commandes",
        //"page": ,
      },
      {
        "icon": Icons.settings,
        "description": "Paramètres",
        "page": Settings(),
      },
      {
        "icon": Icons.logout,
        "description": "DÉCONNEXION",
        "page": null,
      },
    ];
  }

  int? _restaurantID;

  Future<void> loadRestaurantID() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserRestau = prefs.getInt('currentUser_restau');

    print("currentUser_restau $currentUserRestau");

    if (currentUserRestau != null) {
      setState(() {
        _restaurantID = currentUserRestau;
        sections[0]["page"] = RestaurantDetails(restaurant_id: currentUserRestau);
      });
    } else {
      print("Aucun restaurantID valide trouvé dans SharedPreferences.");
      setState(() {
        // Soit on désactive le bouton, soit on met une page vide
        sections[0]["page"] = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Column(
          children: <Widget>[
            SizedBox(
              height: size.height * 0.06,
            ),
            Expanded( // Limite la hauteur de ListView pour éviter d'écraser la barre de navigation
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
                      onPressed: () {
                        if (sections[index]["description"] == "LOGOUT") {
                          // Affiche la boîte de dialogue Logout
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (BuildContext context) {
                              return LogoutFormDialog();
                            },
                          );
                        } else {
                          // Navigue vers la page "Settings"
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (BuildContext context) =>
                              sections[index]["page"],
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(255, 241, 235, 235),
                        shape: StadiumBorder(),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              if (sections[index]["page"] != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (BuildContext context) => sections[index]["page"],
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Aucune donnée de restaurant disponible.")),
                                );
                              }
                            },
                            child: Icon(sections[index]["icon"], color: Colors.white),
                            style: ElevatedButton.styleFrom(
                              shape: CircleBorder(),
                              padding: EdgeInsets.only(top: 4),
                              backgroundColor: Colors.red,
                            ),
                          ),
                          SizedBox(width: 20),
                          Text(
                            sections[index]["description"],
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 27,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 5),
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
