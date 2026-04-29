import 'package:hive/hive.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../modeles/address.dart';
import '../modeles/commande.dart';
import '../modeles/dish.dart';
import '../modeles/identity.dart';
import '../modeles/ligne_commande.dart';
import '../modeles/moyen_paiement.dart';
import '../modeles/restaurant.dart';
import '../modeles/users.dart';

class DatabaseHelper {
  static Future<Users> createUser(Users users) async {
    var usersBox = await Hive.openBox<Users>('users');
    await usersBox.put(users.userID, users);
    return users;
  }

  static Future<Users?> updateUser(int userID, DateTime? last_login) async {
    final Box<Users> usersBox = await Hive.openBox<Users>('users');
    final Users? user = usersBox.get(userID);

    if (user != null) {
      user.last_login =
          last_login; // Mettre à jour la date de dernière connexion
      await usersBox.put(userID, user); // Sauvegarder l'utilisateur mis à jour
      return user; // Retourner l'utilisateur mis à jour
    }

    return null;
  }

  static Future<Users?> updateUserStatus(int userID, String status) async {
    final Box<Users> usersBox = await Hive.openBox<Users>('users');
    final Users? user = usersBox.get(userID);

    if (user != null) {
      user.status = status;
      await usersBox.put(userID, user);
      return user; // Retourner l'utilisateur mis à jour
    }

    return null;
  }

  static Future<Users?> updateUserIdentity(int userID, String identity) async {
    final Box<Users> usersBox = await Hive.openBox<Users>('users');
    final Users? user = usersBox.get(userID);

    if (user != null) {
      user.identity = identity;
      await usersBox.put(userID, user);
      return user; // Retourner l'utilisateur mis à jour
    }

    return null;
  }

  static Future<Users?> updateUserPassword(int userID, String password) async {
    final Box<Users> usersBox = await Hive.openBox<Users>('users');
    final Users? user = usersBox.get(userID);

    if (user != null) {
      user.password = password; // Mettre à jour le mot de passe
      await usersBox.put(userID, user); // Sauvegarder l'utilisateur mis à jour
      return user; // Retourner l'utilisateur mis à jour
    }

    return null; // Retourner null si l'utilisateur n'est pas trouvé
  }

  static Future<Users?> updateCountryAndRole(
      int userID, String country, int roleID) async {
    final Box<Users> usersBox = await Hive.openBox<Users>('users');
    final Users? user = usersBox.get(userID);

    if (user != null) {
      user.country = country;
      user.roleID = roleID;
      await usersBox.put(userID, user);
      return user;
    }

    return null; // Retourner null si l'utilisateur n'est pas trouvé
  }

  static Future<List<Users>> readAllUserss() async {
    final Box<Users> usersBox = await Hive.openBox<Users>('users');
    List<Users> usersList = usersBox.values.toList();
    usersList.sort((a, b) => a.username.compareTo(b.username));
    return usersList;
  }

  static Future<int> deleteUser(int userID) async {
    final Box<Users> usersBox = await Hive.openBox<Users>('users');
    await usersBox.delete(userID);
    return 1;
  }

  static Future<Restaurant> createRestaurant(Restaurant restaurant) async {
    var restaurantBox = await Hive.openBox<Restaurant>('restaurant');
    await restaurantBox.put(restaurant.restaurantID, restaurant);
    return restaurant;
  }

  static Future<Restaurant> updateRestaurant(Restaurant restaurant) async {
    final restaurantBox = await Hive.openBox<Restaurant>('restaurant');

    // Vérifie si l'ID existe déjà
    if (restaurantBox.containsKey(restaurant.restaurantID)) {
      await restaurantBox.put(restaurant.restaurantID, restaurant);
      return restaurant;
    } else {
      throw Exception("Le restaurant avec l'ID ${restaurant.restaurantID} n'existe pas.");
    }
  }

  static Future<Restaurant?> updateRestaurantStatus(
      int restaurantID, int valid) async {
    final Box<Restaurant> restaurantBox =
        await Hive.openBox<Restaurant>('restaurant');
    final Restaurant? restaurant = restaurantBox.get(restaurantID);

    if (restaurant != null) {
      restaurant.valid = valid;
      await restaurantBox.put(restaurantID, restaurant);
      return restaurant;
    }

    return null;
  }

  static Future<List<Restaurant>> readAllRestaurants() async {
    final Box<Restaurant> restaurantBox =
        await Hive.openBox<Restaurant>('restaurant');
    List<Restaurant> restaurantList = restaurantBox.values.toList();
    restaurantList.sort((a, b) => a.name.compareTo(b.name));

    return restaurantList.isNotEmpty ? restaurantList : [];
  }

  static Future<int> deleteRestaurant(int restaurantID) async {
    final Box<Restaurant> restaurantBox =
        await Hive.openBox<Restaurant>('restaurant');
    await restaurantBox.delete(restaurantID);
    return 1;
  }

  static Future<Dish> createDish(Dish dish) async {
    var dishBox = await Hive.openBox<Dish>('dish');
    await dishBox.put(dish.dishID, dish);
    return dish;
  }

  static Future<Dish?> updateDish(Dish dish) async {
    final Box<Dish> dishBox = await Hive.openBox<Dish>('dish');
    final Dish? dish_db = dishBox.get(dish.dishID);

    if (dish_db != null) {
      dish_db.name = dish.name;
      dish_db.image = dish.image;
      dish_db.price = dish.price;
      dish_db.description = dish.description;
      dish_db.option1 = dish.option1;
      dish_db.option2 = dish.option2;
      dish_db.option3 = dish.option3;
      dish_db.categories = dish.categories;
      dish_db.nb_servings = dish.nb_servings;
      dish_db.status = dish.status;
      await dishBox.put(dish.dishID, dish_db);
      print("dish image  " + dish.image.toString());
      print("dishID image  " + dish_db.image.toString());
      return dish_db;
    }

    return null;
  }

  static Future<Dish?> updateDishStatus(int dishID, int status) async {
    final Box<Dish> dishBox = await Hive.openBox<Dish>('dish');
    final Dish? dish = dishBox.get(dishID);

    if (dish != null) {
      dish.status = status;
      await dishBox.put(dishID, dish);
      return dish;
    }

    return null;
  }

  static Future<List<Dish>> readAllDishes() async {
    final Box<Dish> dishBox = await Hive.openBox<Dish>('dish');
    List<Dish> dishList = dishBox.values.toList();

    dishList.sort((a, b) => a.note.compareTo(b.note));

    return dishList;
  }

  static Future<int> deleteDish(int dishID) async {
    final Box<Dish> dishBox = await Hive.openBox<Dish>('dish');
    await dishBox.delete(dishID);
    return 1;
  }

  static Future<List<Address>> readAllAddresses() async {
    final Box<Address> addressBox = await Hive.openBox<Address>('address');
    List<Address> addressList = addressBox.values.toList();
    return addressList;
  }

  static Future<Address> createAddress(Address address) async {
    var addressBox = await Hive.openBox<Address>('address');
    await addressBox.put(address.addressID, address);
    return address;
  }

  static Future<void> addAddress(Address address) async {
    print("function addAddress");
    var addressBox = await Hive.openBox<Address>('address');

    if (address.objectID != null) {
      await addressBox.put(address.objectID, address);
    } else {
      // Enregistre sans clé spécifique (Hive assigne un ID auto)
      await addressBox.add(address);
    }
  }

  /// 🔹 **Supprimer une Adresse dans Hive**
  static Future<void> deleteAddress(int addressID) async {
    var addressBox = await Hive.openBox<Address>('address');
    await addressBox.delete(addressID);
  }

  /// 🔹 **Enregistrer toutes les adresses récupérées depuis Back4App**
  static Future<void> saveAllAddresses(List<Address> addresses) async {
    var addressBox = await Hive.openBox<Address>('address');
    await addressBox.clear(); // Supprime les anciennes données
    for (var address in addresses) {
      await addressBox.put(address.objectID, address);
    }
  }

  /// 🔹 **Récupérer toutes les adresses depuis Hive**
  static Future<List<Address>> getAllAddresses() async {
    var addressBox = await Hive.openBox<Address>('address');
    return addressBox.values.toList();
  }

  static Future<List<Identity>> readAllIdentities() async {
    final Box<Identity> identitiesBox = await Hive.openBox<Identity>('identity');
    List<Identity> identitiesList = identitiesBox.values.toList();
    return identitiesList;
  }

  static Future<void> createIdentity(Identity identity) async {
    final box = await Hive.openBox<Identity>('identity');
    await box.put(identity.identityID, identity);
  }


  static Future<Identity?> updateIdentity(Identity identity) async {
    final Box<Identity> identityBox = await Hive.openBox<Identity>('identity');
    final Identity? identity_db = identityBox.get(identity.identityID);

    if (identity_db != null) {
      identity_db.photo = identity.photo;
      identity_db.piece_identite = identity.piece_identite;
      await identityBox.put(identity.identityID, identity_db);
      return identity_db;
    }

    return null;
  }

  // ajouter une identité
  static Future<void> addIdentity(Identity identity) async {
    print("function addIdentity");
    var identityBox = await Hive.openBox<Identity>('identity');

    if (identity.identityID != null) {
      print("identity.identityID != null");
      await identityBox.put(identity.identityID, identity);
    } else {
      print("else identity.identityID != null");
    // Enregistre sans clé spécifique (Hive assigne un ID auto)
      await identityBox.add(identity);
    }
  }

  /// 🔹 **Supprimer une Adresse dans Hive**
  static Future<void> deleteIdentity(int identityID) async {
    var identityBox = await Hive.openBox<Identity>('identity');
    await identityBox.delete(identityID);
  }

  /// 🔹 **Enregistrer toutes les adresses récupérées depuis Back4App**
  static Future<void> saveAllIdentities(List<Identity> identities) async {
    var identityBox = await Hive.openBox<Identity>('identity');
    await identityBox.clear(); // Supprime les anciennes données
    for (var identity in identities) {
      await identityBox.put(identity.identityID, identity);
    }
  }

  /// 🔹 **Récupérer toutes les identités depuis Hive**
  static Future<List<Identity>> getAllIdentities() async {
    var identityBox = await Hive.openBox<Identity>('identity');
    return identityBox.values.toList();
  }

  static Future<MoyenPaiement> createMoyenPaiement(MoyenPaiement moyen) async {
    final box = await Hive.openBox<MoyenPaiement>('moyen_paiement');
    await box.put(moyen.idMoyen, moyen);
    return moyen;
  }

  static Future<List<MoyenPaiement>> readAllMoyensPaiement() async {
    final box = await Hive.openBox<MoyenPaiement>('moyen_paiement');
    return box.values.toList();
  }

  static Future<void> deleteMoyenPaiement(int idMoyen) async {
    final box = await Hive.openBox<MoyenPaiement>('moyen_paiement');
    await box.delete(idMoyen);
  }

  static Future<Commande> createCommande(Commande commande) async {
    final box = await Hive.openBox<Commande>('commande');
    await box.put(commande.commandeID, commande);
    return commande;
  }

  static Future<List<Commande>> readAllCommandes() async {
    final box = await Hive.openBox<Commande>('commande');
    return box.values.toList();
  }

  static Future<void> deleteCommande(int commandeID) async {
    final box = await Hive.openBox<Commande>('commande');
    await box.delete(commandeID);
  }

  static Future<LigneCommande> createLigneCommande(LigneCommande ligne) async {
    final box = await Hive.openBox<LigneCommande>('ligne_commande');
    await box.put(ligne.ligneID, ligne);
    return ligne;
  }


  static Future<List<LigneCommande>> readLignesCommande(int commandeID) async {
    final box = await Hive.openBox<LigneCommande>('ligne_commande');
    return box.values
        .where((ligne) => ligne.commandeID == commandeID.toString())
        .toList();
  }

  static Future<void> deleteLigneCommande(int ligneID) async {
    final box = await Hive.openBox<LigneCommande>('ligne_commande');
    await box.delete(ligneID);
  }


  Future closeHiveBox() async {
    await Hive
        .close(); // Ferme toutes les boxes ouvertes et libère les ressources Hive
  }

  static Future<bool> cleanUpDatabase(bool deleteAll) async {
    try {
      await Hive.deleteFromDisk();

      return true;
    } catch (e) {
      return false;
    }
  }
}
