import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:hive/hive.dart';
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

  @HiveField(10)
  int nb_orders;

  Restaurant(
      {required this.restaurantID,
      required this.userID,
      required this.categories,
      required this.description,
      required this.adress,
      required this.name,
      required this.note,
      required this.nb_orders,
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
      'nb_orders': nb_orders,
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
        nb_orders: int.tryParse(map['nb_orders']?.toString() ?? '0') ?? 0,
        note: double.tryParse(map['note']?.toString() ?? '') ?? 0.0,
        categories: map['categories']?.toString() ??
            map['categories']?.toString() ??
            '',
        description: map['description']?.toString() ??
            map['description']?.toString() ??
            '',
        adress: map['adress']?.toString() ?? map['adress']?.toString() ?? '',
        name: map['name']?.toString() ?? map['name']?.toString() ?? '',
        date_creation: map['date_creation'] != null && map['date_creation']['iso'] != null
            ? DateTime.tryParse(map['date_creation']['iso'])
            : null,
        image: map['image']?.toString() ?? '');
  }

  Restaurant copy({
    int? restaurantID,
    int? userID,
    double? note,
    int? valid,
    int? nb_orders,
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
        nb_orders: nb_orders ?? this.nb_orders,
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
    required int nb_orders,
    required double note,
    required String categories,
    required String description,
    required String adress,
    required String name,
    DateTime? date_creation,
    ParseFile? image, // ParseFile passed from above
  }) async {
    // Determine cloud function name based on operation
    String functionName = restaurantID == null ? 'add1Restaurant' : 'update1Restaurant';
    var cloudFunction = ParseCloudFunction(functionName);

    String imageUrl = "";

    // Upload the image if it's not null
    if (image != null) {

      // Attempt to save the file to Parse
      final response = await image.save();

      // Handle the response for file upload
      if (response.success && response.result != null) {
        // Get the URL of the uploaded file
        imageUrl = (response.result as ParseFile).url ?? "";

        // Now save the file reference in the Gallery object in Parse
        final gallery = ParseObject('Gallery')
          ..set('file', image); // Ensure the field name is 'file'

        // Save the Gallery object to Parse
        final galleryResponse = await gallery.save();

        if (galleryResponse.success) {
          print("File saved successfully in Gallery object.");
        } else {

          return "Error while saving the Gallery object: ${galleryResponse.error?.message}";
        }
      } else {
        return "Erreur lors de l'upload de l'image: ${response.error?.message}";
      }
    }

    // Build parameters for the cloud function call
    var params = <String, dynamic>{
      if (restaurantID != null) 'restaurantID': restaurantID,
      'userID': userID,
      'categories': categories,
      'description': description,
      'adress': adress,
      'name': name,
      'note': note,
      'nb_orders': nb_orders,
      'valid': valid,
      'image': imageUrl, // Use the URL of the uploaded image
      'date_creation': {
        "__type": "Date",
        "iso": date_creation?.toIso8601String()
      },
    };

    print("params " + params.toString());

    try {
      final ParseResponse parseResponse =
          await cloudFunction.execute(parameters: params);

      if (parseResponse.success && parseResponse.result != null) {
        var response = parseResponse.result as Map<String, dynamic>;
        if (response['success'] == false) {
          return "Erreur : ${response['error']}";
        } else {
          // L'ID du restau est utile pour la mise à jour, pour l'ajout il est généré par le serveur
          int updatedRestauID = restaurantID ?? response['restaurantID'];

          Restaurant restaurant = Restaurant(restaurantID: updatedRestauID,
            userID: userID,
            valid: valid,
            nb_orders: nb_orders,
            note: note,
            categories: categories,
            description: description,
            adress: adress,
            name: name,
            image: imageUrl, date_creation: date_creation,
          );

          if (restaurantID == null) {
            await DatabaseHelper.createRestaurant(restaurant);
          } else {
            //await DatabaseHelper.updateRestaurant(restaurantID, mot_de_passe_crypte, derniere_connexion);
          }
          return "success";
        }
      } else {
        return "Erreur lors de l'appel de la fonction cloud : ${parseResponse.error?.message}";
      }
    } catch (e) {
      return "Exception lors de l'appel de la fonction cloud : $e";
    }
  }

  static Future<String> updateRestaurantStatus(int restaurantID, int status) async {
    // Déterminer le nom de la fonction cloud en fonction de l'opération
    String functionName = 'update1Restaurant';
    var cloudFunction = ParseCloudFunction(functionName);

    // Construire les paramètres, y compris restaurantID pour la mise à jour
    var params = <String, dynamic>{
      if (restaurantID != null) 'restaurantID': restaurantID,
      'valid': status
    };

    try {
      final ParseResponse parseResponse =
          await cloudFunction.execute(parameters: params);

      if (parseResponse.success && parseResponse.result != null) {
        var response = parseResponse.result as Map<String, dynamic>;
        if (response['success'] == false) {
          return "Erreur : ${response['error']}";
        } else {
          await DatabaseHelper.updateRestauranStatus(restaurantID, status);

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

  static Future<bool> getAllRestaurantsDetails() async {
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
        print('Failed to retrieve restaurant details: ${response.error?.message}');
        return false;
      }
    } catch (e) {
      print('Error calling cloud function: $e');
      return false;
    }
    return true;
  }

  static Future<List<Restaurant>> fetchRestaurantsFromDB() async {
    List<Restaurant> restaurantList = await DatabaseHelper.readAllRestaurants();
    print("fetchRestaurantsFromDB " + restaurantList.toString());
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
}
