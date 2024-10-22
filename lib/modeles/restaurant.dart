import 'dart:ffi';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';

part 'restaurant.g.dart';

@HiveType(typeId: 1)
class Restaurant extends HiveObject {
  @HiveField(0)
  final int restaurantID;

  @HiveField(1)
  final int userID;

  @HiveField(2)
  final String categories;

  @HiveField(3)
  final String description;

  @HiveField(4)
  final String adress;

  @HiveField(5)
  final String name;

  @HiveField(6)
  final double note;

  @HiveField(7)
  final String image;

  @HiveField(8)
  DateTime? date_creation;

  @HiveField(9)
  int valid;

  Restaurant(
      {required this.restaurantID,
      required this.userID,
      required this.categories,
      required this.description,
      required this.adress,
      required this.name,
      required this.note,
      required this.image,
      required this.valid,
      required this.date_creation});

  Map<String, dynamic> toMap() {
    return {
      'restaurantID': restaurantID,
      'userID': userID,
      'categories': categories,
      'description': description,
      'adress': adress,
      'name': name,
      'note': note,
      'valid': valid,
      'image': image,
      'date_creation': date_creation
    };
  }

  // Implement a method to create a Restaurant from a Map
  factory Restaurant.fromMap(Map<String, dynamic> map) {
    return Restaurant(
        restaurantID: int.tryParse(map['restaurantID']?.toString() ?? '0') ?? 0,
        userID: int.tryParse(map['userID']?.toString() ?? '0') ?? 0,
        valid: int.tryParse(map['valid']?.toString() ?? '0') ?? 0,
        note: double.tryParse(map['note']?.toString() ?? '') ?? 0.0,
        categories: map['categories']?.toString() ??
            map['categories']?.toString() ??
            '',
        description: map['description']?.toString() ??
            map['description']?.toString() ??
            '',
        adress: map['adress']?.toString() ?? map['adress']?.toString() ?? '',
        name: map['name']?.toString() ?? map['name']?.toString() ?? '',
        date_creation: map['date_creation'] != null
            ? DateTime.tryParse(map['date_creation'])
            : null,
        image: map['image']?.toString() ?? '');
  }

  Restaurant copy({
    int? restaurantID,
    int? userID,
    double? note,
    int? valid,
    String? categories,
    String? description,
    String? adress,
    String? name,
    DateTime? date_creation,
    String? image,
  }) {
    return Restaurant(
        restaurantID: restaurantID ?? this.restaurantID,
        userID: userID ?? this.userID,
        note: note ?? this.note,
        valid: valid ?? this.valid,
        categories: categories ?? this.categories,
        description: description ?? this.description,
        adress: adress ?? this.adress,
        name: name ?? this.name,
        date_creation: date_creation ?? this.date_creation,
        image: image ?? this.image);
  }

  static Future<String> manageRestaurant({
    int? restaurantID,
    required int userID,
    required int valid,
    required double note,
    required String categories,
    required String description,
    required String adress,
    required String name,
    DateTime? date_creation,
    ParseFile? image,
  }) async {
    // Déterminer le nom de la fonction cloud en fonction de l'opération
    String functionName = restaurantID == null ? 'add1Restaurant' : 'updateRestaurant';
    var cloudFunction = ParseCloudFunction(functionName);

    String imageUrl = "";

    // Sauvegarde de l'image si présente
    if (image != null) {
      print("Uploading image...");

      // Définir une ACL pour permettre l'accès public (lecture/écriture)
      ParseACL parseACL = ParseACL();
      parseACL.setPublicReadAccess(allowed: true);  // Autoriser la lecture publique
      parseACL.setPublicWriteAccess(allowed: true); // Autoriser l'écriture publique

      // Appliquer l'ACL au fichier
      image.setACL(parseACL);

      // Sauvegarder l'image
      final response = await image.save();
      if (response.success && response.result != null) {
        imageUrl = (response.result as ParseFile).url ?? "";
        print("Image uploaded successfully: $imageUrl");
      } else {
        print("Erreur lors de l'upload de l'image: ${response.error?.message}");
        return "Erreur lors de l'upload de l'image: ${response.error?.message}";
      }
    }

    // Construire les paramètres pour l'appel cloud
    var params = <String, dynamic>{
      if (restaurantID != null) 'restaurantID': restaurantID,
      'userID': userID,
      'categories': categories,
      'description': description,
      'adress': adress,
      'name': name,
      'note': note,
      'valid': valid,
      'image': imageUrl,  // Utiliser l'URL de l'image
      'date_creation': {
        "__type": "Date",
        "iso": date_creation?.toIso8601String()
      },
    };

    print("params " + params.toString());

    try {
      final ParseResponse parseResponse = await cloudFunction.execute(parameters: params);

      if (parseResponse.success && parseResponse.result != null) {
        var response = parseResponse.result as Map<String, dynamic>;
        if (response['success'] == false) {
          return "Erreur : ${response['error']}";
        } else {
          print("Restaurant successfully managed");
          return "success";
        }
      } else {
        return "Erreur lors de l'appel de la fonction cloud : ${parseResponse.error?.message}";
      }
    } catch (e) {
      return "Exception lors de l'appel de la fonction cloud : $e";
    }
  }

  static Future<String> updateRestauranStatus(int restaurantID) async {
    // Déterminer le nom de la fonction cloud en fonction de l'opération
    String functionName = 'updateRestaurant';
    var cloudFunction = ParseCloudFunction(functionName);

    int valid = 1; //todo logic

    // Construire les paramètres, y compris restaurantID pour la mise à jour
    var params = <String, dynamic>{
      if (restaurantID != null) 'restaurantID': restaurantID,
      'valid': valid
    };

    try {
      final ParseResponse parseResponse =
          await cloudFunction.execute(parameters: params);

      if (parseResponse.success && parseResponse.result != null) {
        var response = parseResponse.result as Map<String, dynamic>;
        if (response['success'] == false) {
          return "Erreur : ${response['error']}";
        } else {
          await DatabaseHelper.updateRestauranStatus(restaurantID, valid);

          return "success";
        }
      } else {
        return "Erreur lors de l'appel de la fonction cloud : ${parseResponse.error?.message}";
      }
    } catch (e) {
      return "Exception lors de l'appel de la fonction cloud : $e";
    }
  }

  static Future<String> suppr1Restaurant(int restaurantID) async {
    var cloudFunction = ParseCloudFunction('suppr1Restaurant');
    var params = <String, dynamic>{
      'restaurantID': restaurantID,
    };

    try {
      final ParseResponse parseResponse =
          await cloudFunction.execute(parameters: params);

      if (parseResponse.success && parseResponse.result != null) {
        var response = parseResponse.result as Map<String, dynamic>;
        if (response['success'] == true) {
          // Restaurant supprimé avec succès
          await DatabaseHelper.deleteRestaurant(restaurantID);

          return "success";
        } else {
          // Gestion de l'erreur si l'accès n'a pas pu être supprimé
          return "Erreur : ${response['error']}";
        }
      } else {
        // Gestion des erreurs de la réponse
        return "Erreur lors de l'appel de la fonction cloud : ${parseResponse.error?.message}";
      }
    } catch (e) {
      // Gestion des exceptions
      return "Exception lors de l'appel de la fonction cloud : $e";
    }
  }

  static Future<bool> getAllRestaurantDetails() async {
    // Créer une instance de ParseCloudFunction
    var cloudFunction = ParseCloudFunction('getAllRestaurants');

    // Appeler la fonction cloud et attendre la réponse
    try {
      var response = await cloudFunction.execute();

      if (response.success) {
        List<dynamic> restaurantDataList = response.result;
        for (var restaurantData in restaurantDataList) {
          Restaurant restaurant = Restaurant.fromMap(restaurantData);
          await DatabaseHelper.createRestaurant(restaurant);
        }
      } else {
        print(
            'Failed to retrieve restaurant details: ${response.error?.message}');
      }
    } catch (e) {
      print('Error calling cloud function: $e');
    }
    return true;
  }

  static Future<List<Restaurant>> fetchRestaurantFromDB() async {
    List<Restaurant> restaurantList = await DatabaseHelper.readAllRestaurants();
    return restaurantList;
  }

  static Future<Restaurant?> verifRestaurant(
      List<Restaurant> listRestaurants, String name, int userID) async {
    // Chercher l'accès correspondant au restaurantname ou email
    for (final restaurant in listRestaurants) {
      if (restaurant.name == name && restaurant.userID == userID) {
        return restaurant; // Retourner l'utilisateur si trouvé
      }
    }

    // Aucun utilisateur correspondant trouvé
    return null;
  }

  static Restaurant? getRestaurantByRestaurantId(
      List<Restaurant> restaurants, int id) {
    try {
      return restaurants
          .firstWhere((restaurant) => restaurant.restaurantID == id);
    } catch (e) {
      return null;
    }
  }

  static Restaurant? getRestaurantByRestaurantname(
      List<Restaurant> listRestaurants, String restaurantname) {
    try {
      return listRestaurants
          .firstWhere((restaurant) => restaurant.name == restaurantname);
    } catch (e) {
      return null;
    }
  }

  static Restaurant? getRestaurantByUser(
      List<Restaurant> listRestaurants, int userID) {
    try {
      return listRestaurants
          .firstWhere((restaurant) => restaurant.userID == userID);
    } catch (e) {
      return null;
    }
  }

  static Future<bool> checkEmailExists(
      List<Restaurant> listRestaurants, String name, int userID) async {
    try {
      Restaurant restaurant = await listRestaurants.firstWhere((restaurant) =>
          restaurant.name == name && restaurant.userID == userID);
      if (restaurant != null) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}
