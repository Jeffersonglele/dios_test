import 'package:flutter/material.dart';
import 'Screen/CustomSearchDelegate.dart';

class SearchInput extends StatefulWidget {
  @override
  State<SearchInput> createState() => _SearchInputState();
}

class _SearchInputState extends State<SearchInput> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 25, left: 25, right: 25),
      child: Column(
        children: [
          Row(
            children: [
              Flexible(
                flex: 1,
                child: TextField(
                  readOnly: true,
                  cursorColor: Colors.grey,
                  decoration: InputDecoration(
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    hintText: 'Rechercher des plats, des commerces ...',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 18),
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(15),
                      child: Icon(
                        Icons.search, // Remplace l'image par l'icône "search"
                        color: Colors.grey,
                        size: 24,
                      ),
                    ),
                  ),
                  onTap: () {
                    // Aller à l'écran suivant
                    showSearch(
                      context: context,
                      // Déléguer pour personnaliser la barre de recherche
                      delegate: CustomSearchDelegate(),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
