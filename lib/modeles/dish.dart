import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:hive/hive.dart';
import '../db/database_helper.dart';
import 'package:dios_delices/providers/data_version_notifier.dart';

part 'dish.g.dart';

@HiveType(typeId: 3)
class Dish extends HiveObject {
  @HiveField(0)
  final int dishID;

  @HiveField(1)
  String? name;

  @HiveField(2)
  String? categories;

  @HiveField(3)
  String? image;

  @HiveField(4)
  final int nb_orders;

  @HiveField(5)
  final int userID;

  @HiveField(6)
  double? price;

  @HiveField(7)
  String? description;

  @HiveField(8)
  int? status;

  @HiveField(9)
  int? nb_servings;

  @HiveField(10)
  final int restauID;

  @HiveField(11)
  final double note;

  @HiveField(12)
  String? option1;

  @HiveField(13)
  String? option2;

  @HiveField(14)
  String? option3;

  String currency;

  int stock;
  bool isDailySpecial;

  Dish({
    required this.dishID,
    required this.userID,
    required this.categories,
    required this.description,
    required this.option1,
    required this.option2,
    required this.option3,
    required this.name,
    required this.note,
    required this.nb_orders,
    required this.image,
    required this.price,
    required this.nb_servings,
    required this.restauID,
    required this.status,
    this.currency = 'EUR',
    this.stock = 99,
    this.isDailySpecial = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'dishID': dishID,
      'userID': userID,
      'categories': categories,
      'description': description,
      'option1': option1,
      'option2': option2,
      'option3': option3,
      'name': name,
      'note': note,
      'nb_orders': nb_orders,
      'image': image,
      'price': price,
      'nb_servings': nb_servings,
      'restauID': restauID,
      'status': status,
      'currency': currency,
    };
  }

  factory Dish.fromMap(Map<String, dynamic> map) {
    return Dish(
      dishID: int.tryParse(map['dishID']?.toString() ?? '0') ?? 0,
      userID: int.tryParse(map['userID']?.toString() ?? '0') ?? 0,
      nb_orders: int.tryParse(map['nb_orders']?.toString() ?? '0') ?? 0,
      note: double.tryParse(map['note']?.toString() ?? '') ?? 0.0,
      categories: map['categories']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      option1: map['option1']?.toString() ?? '',
      option2: map['option2']?.toString() ?? '',
      option3: map['option3']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      image: map['image']?.toString() ?? '',
      price: double.tryParse(map['price']?.toString() ?? '0') ?? 0.0,
      nb_servings: int.tryParse(map['nb_servings']?.toString() ?? '0') ?? 0,
      restauID: int.tryParse(map['restauID']?.toString() ?? '0') ?? 0,
      status: int.tryParse(map['status']?.toString() ?? '0') ?? 0,
      currency: map['currency']?.toString() ?? 'EUR',
    );
  }

  Dish copy({
    int? dishID,
    int? userID,
    double? note,
    int? nb_orders,
    String? categories,
    String? description,
    String? option1,
    String? option2,
    String? option3,
    String? name,
    String? image,
    double? price,
    int? nb_servings,
    int? restauID,
    int? status,
    String? currency,
  }) {
    return Dish(
      dishID: dishID ?? this.dishID,
      userID: userID ?? this.userID,
      note: note ?? this.note,
      nb_orders: nb_orders ?? this.nb_orders,
      categories: categories ?? this.categories,
      description: description ?? this.description,
      option1: option1 ?? this.option1,
      option2: option2 ?? this.option2,
      option3: option3 ?? this.option3,
      name: name ?? this.name,
      image: image ?? this.image,
      price: price ?? this.price,
      nb_servings: nb_servings ?? this.nb_servings,
      restauID: restauID ?? this.restauID,
      status: status ?? this.status,
      currency: currency ?? this.currency,
    );
  }

  static Future<String> manageDish({
    int? dishID,
    required int userID,
    required int nb_orders,
    required double note,
    required String categories,
    required String description,
    required String option1,
    required String option2,
    required String option3,
    required String name,
    required double price,
    required int nb_servings,
    required int restauID,
    required int status,
    ParseFile? image,
    String? img_url,
    String currency = 'EUR',
  }) async {
    String functionName = dishID == null ? 'add1Dish' : 'update1Dish';
    var cloudFunction = ParseCloudFunction(functionName);

    String? imageUrl = "";

    if (image != null) {
      final response = await image.save();
      if (response.success && response.result != null) {
        imageUrl = (response.result as ParseFile).url ?? img_url;

        final gallery = ParseObject('Gallery')..set('file', image);

        final galleryResponse = await gallery.save();

        if (!galleryResponse.success) {
          return "Error while saving the Gallery object: ${galleryResponse.error?.message}";
        }
      } else {
        return "Erreur lors de l'upload de l'image: ${response.error?.message}";
      }
    }

    var params = <String, dynamic>{
      if (dishID != null) 'dishID': dishID,
      'userID': userID,
      'categories': categories,
      'description': description,
      'option1': option1,
      'option2': option2,
      'option3': option3,
      'name': name,
      'note': note,
      'nb_orders': nb_orders,
      'image': image == null ? img_url : imageUrl,
      'price': price,
      'nb_servings': nb_servings,
      'restauID': restauID,
      'status': status,
      'currency': currency,
    };

    try {
      final ParseResponse parseResponse =
          await cloudFunction.execute(parameters: params);

      if (parseResponse.success && parseResponse.result != null) {
        var response = parseResponse.result as Map<String, dynamic>;
        if (response['success'] == false) {
          return "Erreur : ${response['error']}";
        } else {
          // L'ID du restau est utile pour la mise à jour, pour l'ajout il est généré par le serveur
          int updatedDishID = dishID ?? response['dishID'];

          Dish dish = Dish(
              dishID: updatedDishID,
              nb_orders: nb_orders,
              note: note,
              categories: categories,
              description: description,
              option1: option1,
              option2: option2,
              option3: option3,
              name: name,
              image: image == null ? img_url : imageUrl,
              userID: userID,
              price: price,
              nb_servings: nb_servings,
              restauID: restauID,
              status: status,
              currency: currency);

          if (dishID == null) {
            await DatabaseHelper.createDish(dish);
          } else {
            await DatabaseHelper.updateDish(dish);
          }

          notifyDataChanged();
          return "success";
        }
      } else {
        return "Erreur lors de l'appel de la fonction cloud : ${parseResponse.error?.message}";
      }
    } catch (e) {
      return "Exception lors de l'appel de la fonction cloud : $e";
    }
  }

  static Future<String> updateDishStatus(int dishID, int status) async {
    String functionName = 'update1Dish';
    var cloudFunction = ParseCloudFunction(functionName);

    var params = <String, dynamic>{
      'dishID': dishID,
      'status': status,
    };

    try {
      final ParseResponse parseResponse =
          await cloudFunction.execute(parameters: params);

      if (parseResponse.success && parseResponse.result != null) {
        var response = parseResponse.result as Map<String, dynamic>;
        if (response['success'] == false) {
          return "Erreur : ${response['error']}";
        } else {
          await DatabaseHelper.updateDishStatus(dishID, status);
          notifyDataChanged();
          return "success";
        }
      } else {
        return "Erreur lors de l'appel de la fonction cloud : ${parseResponse.error?.message}";
      }
    } catch (e) {
      return "Exception lors de l'appel de la fonction cloud : $e";
    }
  }

  static Future<String> suppr1Dish(int dishID) async {
    var cloudFunction = ParseCloudFunction('suppr1Dish');
    var params = <String, dynamic>{
      'dishID': dishID,
    };

    try {
      final ParseResponse parseResponse =
          await cloudFunction.execute(parameters: params);

      if (parseResponse.success && parseResponse.result != null) {
        var response = parseResponse.result as Map<String, dynamic>;
        if (response['success'] == true) {
          await DatabaseHelper.deleteDish(dishID);
          notifyDataChanged();
          return "success";
        } else {
          return "Erreur : ${response['error']}";
        }
      } else {
        return "Erreur lors de l'appel de la fonction cloud : ${parseResponse.error?.message}";
      }
    } catch (e) {
      return "Exception lors de l'appel de la fonction cloud : $e";
    }
  }

  static Future<bool> getAllDishesDetails() async {
    var cloudFunction = ParseCloudFunction('getAllDishes');

    try {
      var response = await cloudFunction.execute();

      if (response.success) {
        List<dynamic> dishDataList = response.result;
        for (var dishData in dishDataList) {
          Dish dish = Dish.fromMap(dishData);
          await DatabaseHelper.createDish(dish);
        }
      } else {
        print('Failed to retrieve dish details: ${response.error?.message}');
        return false;
      }
    } catch (e) {
      print('Error calling cloud function: $e');
      return false;
    }
    return true;
  }

  static Future<List<Dish>> fetchDishesFromDB() async {
    List<Dish> dishList = await DatabaseHelper.readAllDishes();
    return dishList;
  }

  static Dish? getDishByDishId(List<Dish> dishes, int id) {
    try {
      return dishes.firstWhere((dish) => dish.dishID == id);
    } catch (e) {
      return null;
    }
  }

  static Dish? getDishByDishName(List<Dish> dishes, String dishname) {
    try {
      return dishes.firstWhere((dish) => dish.name == dishname);
    } catch (e) {
      return null;
    }
  }

  static Dish? getDishByUser(List<Dish> dishes, int userID) {
    try {
      return dishes.firstWhere((dish) => dish.userID == userID);
    } catch (e) {
      return null;
    }
  }
}
