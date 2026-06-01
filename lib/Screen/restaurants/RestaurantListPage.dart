import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../../modeles/restaurant.dart';
import '../../modeles/users.dart';
import '../../widgets/dios_image.dart';
import '../../utils/toast.dart';
import 'RestaurantDetails.dart';

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
  bool showOnlyWaitingForValidation = false;
  String sortBy = 'Nom';

  Future<bool> _sendEmailToUser(Restaurant restaurant, bool valid, [String? remark]) async {
    Users? user = Users.getUsersByUserId(users, restaurant.userID);
    final recipientEmail = user?.email ?? 'adigbononrodicaa@gmail.com';
    final subject = valid
        ? '🎉 Bienvenue sur Dios Délices - Votre restaurant est validé !'
        : '❌ Mise à jour : Validation de votre restaurant sur Dios Délices';

    final messageText = valid
        ? 'Bonjour ${user?.firstname},\n\n'
        'Nous sommes ravis de vous informer que votre restaurant "${restaurant.name}" a été validé. '
        'Vous pouvez maintenant accéder à votre compte pour gérer votre restaurant et recevoir des commandes.\n\n'
        'Cordialement,\nL’équipe Dios Délices'
        : 'Bonjour ${user?.firstname},\n\n'
        'Nous regrettons de vous informer que votre restaurant "${restaurant.name}" n’a pas été validé suite à notre processus de vérification.\n\n'
        'Raison du rejet : ${remark ?? "Non spécifiée"}\n\n'
        'Pour plus d’informations, n’hésitez pas à nous contacter.\n\n'
        'Cordialement,\nL’équipe Dios Délices';

    final cloudFunction = ParseCloudFunction('sendEmail');
    try {
      await cloudFunction.execute(parameters: {
        'to': recipientEmail,
        'subject': subject,
        'text': messageText,
      });
      print('Email envoyé avec succès');
      return true;
    } catch (e) {
      print('Erreur lors de l\'envoi de l\'email: $e');
      return false;
    }
  }


  @override
  void initState() {
    super.initState();
    loadData();
  }

  void loadData() async {
    List<Users> usersList = await Users.fetchUsersFromDB();
    List<Restaurant> restausList = await Restaurant.fetchRestaurantsFromDB();

    setState(() {
      users = usersList;
      restaus = restausList;
      _fetchRestaurantsByCountry();
    });
  }

  Future<void> _fetchRestaurantsByCountry() async {
    for (var restaurant in restaus) {
      Users? user = await Users.getUsersByUserId(users, restaurant.userID);
      if (user != null && user.country == widget.country) {
        setState(() {
          filteredRestaurants.add({"restaurant": restaurant, "user": user});
        });
      }
    }
    setState(() {
      isLoading = false;
    });
  }

  void _sortRestaurants(String criterion) {
    setState(() {
      sortBy = criterion;
      if (criterion == 'Nom') {
        filteredRestaurants.sort(
            (a, b) => b["restaurant"].name.compareTo(a["restaurant"].name));
      } else if (criterion == 'Note') {
        filteredRestaurants.sort(
            (a, b) => b["restaurant"].rating.compareTo(a["restaurant"].rating));
      } else if (criterion == 'Nombre de commandes') {
        filteredRestaurants.sort((a, b) =>
            b["restaurant"].orderCount.compareTo(a["restaurant"].orderCount));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    String appBar = widget.country == "Bénin" ? " Restaurants au " : "Restaurants en ";

    return Scaffold(
      appBar: AppBar(
        title: Text(appBar + widget.country),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('En attente de validation'),
                    Switch(
                      value: showOnlyWaitingForValidation,
                      onChanged: (value) {
                        setState(() {
                          showOnlyWaitingForValidation = value;
                        });
                      },
                    ),
                  ],
                ),
                Flexible( // Utiliser Flexible pour s'adapter à la largeur de l'écran
                  child: PopupMenuButton<String>(
                    onSelected: _sortRestaurants,
                    itemBuilder: (BuildContext context) {
                      return {'Nom', 'Note', 'Nombre de commandes'}
                          .map((String choice) {
                        return PopupMenuItem<String>(
                          value: choice,
                          child: Text(choice),
                        );
                      }).toList();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sort, color: Colors.black),
                          SizedBox(width: 5),
                          Flexible( // Flexible ici pour le texte qui pourrait déborder
                            child: Text(
                              "Trier par ",
                              style: TextStyle(color: Colors.black),
                              overflow: TextOverflow.ellipsis, // Tronque le texte si nécessaire
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, color: Colors.black),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
          isLoading
              ? Center(child: CircularProgressIndicator())
              : filteredRestaurants.isEmpty
                  ? Center(
                      child: Text(
                          'Aucun restaurant trouvé pour ${widget.country}'))
                  : Expanded(
                      child: ListView.builder(
                        itemCount: filteredRestaurants.length,
                        itemBuilder: (context, index) {
                          Restaurant restaurant = filteredRestaurants[index]["restaurant"];
                          Users user = filteredRestaurants[index]["user"];

                          if (showOnlyWaitingForValidation && restaurant.valid == 1) {
                            return SizedBox();
                          }

                          return _buildRestaurantCard(restaurant, user);
                        },
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildRestaurantCard(Restaurant restaurant, Users user) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: DiosImage(
                  url: restaurant.image,
                  fit: BoxFit.cover,
                  width: 80,
                  height: 80,
                ),
              ),
              title: Text(
                restaurant.name,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                overflow: TextOverflow.ellipsis, // Empêche le débordement du nom
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hashtags: ${restaurant.categories}",
                    overflow: TextOverflow.ellipsis, // Empêche le débordement des hashtags
                  ),
                  if (restaurant.valid == 1) ...[
                    SizedBox(height: 5),
                    Text("Note: ${restaurant.note}"),
                    Text("Nombre de commandes: ${restaurant.nb_orders}"),
                  ],
                ],
              ),
              trailing: Icon(Icons.chevron_right),
              onTap: () => {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => RestaurantDetails(restaurant_id: restaurant.restaurantID)
                    )
                )
              },
            ),
            /*ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  restaurant.image,
                  fit: BoxFit.cover,
                  width: 80,
                  height: 80,
                ),
              ),
              title: Text(
                restaurant.name,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Hashtags: ${restaurant.categories}"),
                  if (restaurant.valid == 1) ...[
                    SizedBox(height: 5),
                    Text("Note: ${restaurant.note}"),
                    Text("Nombre de commandes: ${restaurant.nb_orders}"),
                  ],
                ],
              ),
            ),*/
            if (restaurant.valid != 1)
              Padding(
                padding: const EdgeInsets.only(left: 12.0, right: 5.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Propriétaire: ${user.firstname}, Email: ${user.email}"),
                    Text("Description: ${restaurant.description}"),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(Icons.check, color: Colors.green),
                          onPressed: () => _validateRestaurant(restaurant),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.red),
                          onPressed: () => _showRejectDialog(restaurant),
                          //onPressed: () => _rejectRestaurant(restaurant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(Restaurant restaurant) {
    final TextEditingController remarkController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Rejeter le restaurant'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Ajouter une remarque pour l'utilisateur :"),
              TextField(
                controller: remarkController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Saisissez votre remarque ici...",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Annuler', style: TextStyle(color: Colors.green),),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _rejectRestaurant(restaurant, remarkController.text);
              },
              child: Text('Envoyer', style: TextStyle(color: Colors.red),),
            ),
          ],
        );
      },
    );
  }

  Future<void> _validateRestaurant(Restaurant restaurant) async {
    String updateResult = await Restaurant.updateRestaurantStatus(restaurant.restaurantID, 1); // Correction du nom de la méthode
    if (updateResult == "success") {
      bool emailSent = await _sendEmailToUser(restaurant, true);
      if (emailSent) {
        setState(() {
          restaurant.valid = 1;
        });
        Toast(context, "Le restaurant ${restaurant.name} a été validé et un mail a été envoyé à l'utilisateur.", true);
      } else {
        Toast(context, "Le restaurant ${restaurant.name} a été validé, mais une erreur est survenue lors de l'envoi de l'email.", false);
      }
    } else {
      Toast(context, "Erreur : $updateResult", false);
    }
  }

  Future<void> _rejectRestaurant(Restaurant restaurant, String remark) async {
    String updateResult = await Restaurant.updateRestaurantStatus(restaurant.restaurantID, 2); // Statut rejeté
    if (updateResult == "success") {
      bool emailSent = await _sendEmailToUser(restaurant, false, remark); // Passer la remarque ici
      if (emailSent) {
        setState(() {
          restaurant.valid = 2;
        });
        Toast(context, "Le restaurant ${restaurant.name} a été rejeté et un mail a été envoyé à l'utilisateur.", false);
      } else {
        Toast(context, "Le restaurant ${restaurant.name} a été rejeté, mais une erreur est survenue lors de l'envoi de l'email.", false);
      }
    } else {
      Toast(context, "Erreur : $updateResult", false);
    }
  }

}
