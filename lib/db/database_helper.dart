import 'package:hive/hive.dart';
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
      user.last_login = last_login;  // Mettre à jour la date de dernière connexion
      await usersBox.put(userID, user);  // Sauvegarder l'utilisateur mis à jour
      return user;  // Retourner l'utilisateur mis à jour
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

  static Future<Users?> updateCountryAndRole(int userID, String country, int roleID) async {
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

  static Future<Restaurant?> updateRestauranStatus(int restaurantID, int valid) async {
    final Box<Restaurant> restaurantBox = await Hive.openBox<Restaurant>('restaurant');
    final Restaurant? restaurant = restaurantBox.get(restaurantID);

    if (restaurant != null) {
      restaurant.valid = valid;
      await restaurantBox.put(restaurantID, restaurant);
      return restaurant;
    }

    return null;
  }

  static Future<List<Restaurant>> readAllRestaurants() async {
    final Box<Restaurant> restaurantBox = await Hive.openBox<Restaurant>('restaurant');
    List<Restaurant> restaurantList = restaurantBox.values.toList();
    restaurantList.sort((a, b) => a.name.compareTo(b.name));
    return restaurantList;
  }

  static Future<int> deleteRestaurant(int restaurantID) async {
    final Box<Restaurant> restaurantBox = await Hive.openBox<Restaurant>('restaurant');
    await restaurantBox.delete(restaurantID);
    return 1;
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
