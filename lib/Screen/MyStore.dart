import 'package:dios_delices/Screen/Settings.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../components/Logout.dart';

class MyStore extends StatefulWidget {
  @override
  _MyStoreState createState() => _MyStoreState();
}

class _MyStoreState extends State<MyStore> {
  List sections = [];

  @override
  void initState() {
    super.initState();

    // Filtrer les sections pour ne garder que "Settings" et "Logout"
    sections = [
      {
        "icon": Icons.settings,
        "description": "Settings",
        "page": Settings(),
      },
      {
        "icon": Icons.logout,
        "description": "LOGOUT",
        "page": null,
      },
    ];
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
            ),
          ],
        ),
      ),
    );
  }
}
