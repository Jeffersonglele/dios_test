import 'package:flutter/material.dart';

import '../../modeles/restaurant.dart';
import '../../modeles/users.dart';

class RestaurantListPage extends StatefulWidget {
  final String country;

  RestaurantListPage({required this.country});

  @override
  _RestaurantListPageState createState() => _RestaurantListPageState();
}

class _RestaurantListPageState extends State<RestaurantListPage> {
  List<Map<String, dynamic>> filteredRestaurants = [];
  List<Users> users = [];
  List<Restaurant> restaus = [];
  bool isLoading = true;
  bool showOnlyValidated = false; // Filtre: Montrer seulement les restaurants validés
  String sortBy = 'Nom'; // Critère de tri par défaut

  @override
  void initState() {
    super.initState();
    loadData();
  }

  // Charger les utilisateurs et restaurants à partir de la base de données
  void loadData() async {
    List<Users> usersList = await Users.fetchUsersFromDB();
    List<Restaurant> restausList = await Restaurant.fetchRestaurantsFromDB();

    // Une fois que les données sont chargées, les mettre à jour dans l'état
    setState(() {
      users = usersList;
      restaus = restausList;

      // Appeler ensuite la fonction pour filtrer les restaurants par pays
      _fetchRestaurantsByCountry();
    });
  }

  // Filtrer les restaurants par pays après avoir chargé toutes les données
  Future<void> _fetchRestaurantsByCountry() async {
    for (var restaurant in restaus) {
      Users? user = await Users.getUsersByUserId(users, restaurant.userID);

      if (user != null && user.country == widget.country) {
        setState(() {
          filteredRestaurants.add({
            "restaurant": restaurant,
            "user": user,
          });
        });
      }
    }

    setState(() {
      isLoading = false;
    });
  }

  // Méthode pour trier les restaurants en fonction du critère sélectionné
  void _sortRestaurants(String criterion) {
    setState(() {
      sortBy = criterion;

      if (criterion == 'Nom') {
        // Trier par nom
        filteredRestaurants.sort((a, b) =>
            b["restaurant"].name.compareTo(a["restaurant"].name));
      } else if(criterion == 'Note'){
        // Trier par note
        filteredRestaurants.sort((a, b) =>
            b["restaurant"].rating.compareTo(a["restaurant"].rating));
      } else if (criterion == 'Nombre de commandes') {
        // Trier par nombre de commandes
        filteredRestaurants.sort((a, b) => b["restaurant"]
            .orderCount
            .compareTo(a["restaurant"].orderCount));
      } else if (criterion == 'Validation') {
        // Trier par état de validation (non validé en premier)
        filteredRestaurants.sort((a, b) =>
            a["restaurant"].valid.compareTo(b["restaurant"].valid));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery
        .of(context)
        .size;

    return Scaffold(
      appBar: AppBar(
        title: Text('Restaurants en ${widget.country}'),
        actions: [
          // Filtre : Montrer seulement les restaurants validés
          Row(
            children: [
              Text('Montrer validés'),
              Switch(
                value: showOnlyValidated,
                onChanged: (value) {
                  setState(() {
                    showOnlyValidated = value;
                  });
                },
              ),
            ],
          ),
          // Menu pour trier par différents critères
          PopupMenuButton<String>(
            onSelected: _sortRestaurants,
            itemBuilder: (BuildContext context) {
              return {'Note', 'Nombre de commandes', 'Validation'}
                  .map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
            },
            icon: Icon(Icons.sort),
          ),
        ],
      ),
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: size.width > 600
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            isLoading
                ? Center(child: CircularProgressIndicator())
                : filteredRestaurants.isEmpty
                ? Center(child: Text('Aucun restaurant trouvé pour ${widget.country}'))
                : ListView.builder(
              itemCount: filteredRestaurants.length,
              itemBuilder: (context, index) {
                Restaurant restaurant = filteredRestaurants[index]["restaurant"];
                Users user = filteredRestaurants[index]["user"];

                // Filtrer les restaurants par état de validation
                if (showOnlyValidated && restaurant.valid != 1) {
                  return SizedBox(); // Masquer les non validés si le filtre est activé
                }

                return _buildRestaurantCard(restaurant, user);
              },
            ),
          ],
      ),
    );
  }

  // Méthode pour créer la carte d'affichage des restaurants
  Widget _buildRestaurantCard(Restaurant restaurant, Users user) {
    if (restaurant.valid == 1) {
      // Restaurant validé : afficher juste les infos de base
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        child: ListTile(
          leading: Image.network(
            restaurant.image,
            fit: BoxFit.cover,
          ),
          title: Text(restaurant.name),
          subtitle: Text('Note: ${restaurant.note}'),
        ),
      );
    } else {
      // Restaurant non validé : afficher toutes les infos et les options pour valider ou rejeter
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Image.network(
                restaurant.image,
                fit: BoxFit.cover,
                width: 100,
              ),
              title: Text(restaurant.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(restaurant.description),
                  Text("Hashtags: ${restaurant.categories}"),
                  Text("Propriétaire: ${user.firstname}, Email: ${user.email}"),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.check, color: Colors.green),
                  onPressed: () {
                    // Logique pour valider le restaurant
                    _validateRestaurant(restaurant);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.red),
                  onPressed: () {
                    // Logique pour rejeter le restaurant
                    _rejectRestaurant(restaurant);
                  },
                ),
              ],
            ),
          ],
        ),
      );
    }
  }

  // Méthode pour valider un restaurant
  void _validateRestaurant(Restaurant restaurant) {
    setState(() {
      restaurant.valid = 1;
    });
    // Appeler la fonction de mise à jour de la base de données ici
  }

  // Méthode pour rejeter un restaurant
  void _rejectRestaurant(Restaurant restaurant) {
    setState(() {
      restaus.remove(restaurant); // Retirer le restaurant non validé
    });
    // Appeler la fonction de mise à jour de la base de données ici
  }
}
