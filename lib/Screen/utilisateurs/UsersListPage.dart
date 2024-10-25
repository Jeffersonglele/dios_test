import 'package:flutter/material.dart';

class UsersListPage extends StatelessWidget {
  final String country;

  UsersListPage({required this.country});

  // Exemple de données pour les users
  final List<Map<String, String>> users = [
    {
      "name": "Le Gourmet",
      "description": "Un restaurant français traditionnel",
      "image": "assets/images/restaurant1.jpg"
    },
    {
      "name": "Côte d'Or",
      "description": "Une cuisine ivoirienne exceptionnelle",
      "image": "assets/images/restaurant2.jpg"
    },
    {
      "name": "Bénin Bites",
      "description": "Cuisine béninoise authentique",
      "image": "assets/images/restaurant3.jpg"
    },
  ];

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return Scaffold(
        appBar: AppBar(
          title: Text('Utilisateurs en $country'),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: size.width > 600
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            SizedBox(height: size.height * 0.1),
            ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                  child: ListTile(
                    leading: Image.asset(users[index]["image"]!, fit: BoxFit.cover),
                    title: Text(users[index]["name"]!),
                    subtitle: Text(users[index]["description"]!),
                  ),
                );
              },
            ),
          ],
        ));
  }
}
