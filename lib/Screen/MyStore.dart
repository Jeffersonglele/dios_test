import 'package:dios_delices/Screen/Administration.dart';
import 'package:dios_delices/Screen/MyProducts.dart';
import 'package:dios_delices/Screen/MySales.dart';
import 'package:dios_delices/Screen/Settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../Logout.dart';
import 'Cart.dart';

class MyStore extends StatefulWidget {
  @override
  _MyStoreState createState() => _MyStoreState();
}

class _MyStoreState extends State<MyStore> {
  @override
  void initState() {
    super.initState();
  }

  List sections = [
    {
      "icon": Icons.grid_view,
      "description": "My products",
      "page": MyProducts(),
    },
    {
      "icon": Icons.shopping_cart,
      "description": "My sales",
      "page": MySales(),
    },
    {
      "icon": Icons.admin_panel_settings_rounded,
      "description": "Administration",
      "page": Administration(),
    },
    {
      "icon": Icons.settings,
      "description": "Settings",
      "page": Settings(),
    },
    {
      "icon": Icons.logout, // Icone pour le logout
      "description": "LOGOUT", // Description qui active la boîte de dialogue
      "page": null, // Pas de page car tu montres une boîte de dialogue
    },
  ];

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return new WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Column(
          children: <Widget>[
            SizedBox(
              height: size.height * 0.06,
            ),
            ListView.separated(
              scrollDirection: Axis.vertical,
              shrinkWrap: true,
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
                      // Ajoute ici la condition pour afficher la boîte de dialogue Logout
                      if (sections[index]["description"] == "LOGOUT") {
                        showDialog(
                          context: context,
                          barrierDismissible: false, // Empêche de fermer en cliquant en dehors
                          builder: (BuildContext context) {
                            return LogoutFormDialog(); // Affiche la boîte de dialogue
                          },
                        );
                      } else {
                        // Si ce n'est pas le bouton LOGOUT, navigue vers la page correspondante
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (BuildContext context) => sections[index]["page"],
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
                          onPressed: () {},
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
                            fontSize: 30,
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

          ],
        ),
      ),
    );
  }
}
