import 'package:dios_delices/Screen/utilisateurs/UsersListPage.dart';
import 'package:flutter/material.dart';
import 'restaurants/RestaurantListPage.dart';

class CountryPage extends StatelessWidget {
  final String sectionType;

  CountryPage({required this.sectionType});

  @override
  Widget build(BuildContext context) {
    List<String> countries = ["France", "Côte d'Ivoire", "Bénin"];

    return Scaffold(
      appBar: AppBar(
        title: Text(sectionType == "utilisateurs"
            ? "Gestion des utilisateurs"
            : "Gestion des restaurants"),
      ),
      body: ListView.builder(
        itemCount: countries.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(countries[index]),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => sectionType == "utilisateurs"
                      ? UsersListPage(country: countries[index])
                      : RestaurantListPage(country: countries[index]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
