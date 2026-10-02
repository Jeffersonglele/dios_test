import 'package:hive/hive.dart';
import 'dart:io';
import '../db/database_helper.dart';
import 'package:dios_delices/providers/data_version_notifier.dart';
import '../services/node_auth_service.dart';
import '../services/session_service.dart';

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

  @HiveField(15)
  int cityID;

  String currency;
  String images;
  String country;

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
    this.images = '',
    this.country = '',
    this.stock = 99,
    this.isDailySpecial = false,
    this.cityID = 1,
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
      'images': images,
      'price': price,
      'nb_servings': nb_servings,
      'cityID': cityID,
      'restauID': restauID,
      'status': status,
      'currency': currency,
      'country': country,
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
      images: map['images']?.toString() ?? '',
      price: double.tryParse(map['price']?.toString() ?? '0') ?? 0.0,
      nb_servings: int.tryParse(map['nb_servings']?.toString() ?? '0') ?? 0,
      restauID: int.tryParse(map['restauID']?.toString() ?? '0') ?? 0,
      status: int.tryParse(map['status']?.toString() ?? '0') ?? 0,
      currency: map['currency']?.toString() ?? 'EUR',
      country: map['country']?.toString() ?? '',
      cityID: int.tryParse(map['cityID']?.toString() ?? '1') ?? 1,
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
    String? images,
    double? price,
    int? nb_servings,
    int? restauID,
    int? status,
    String? currency,
    int? cityID,
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
      images: images ?? this.images,
      price: price ?? this.price,
      nb_servings: nb_servings ?? this.nb_servings,
      restauID: restauID ?? this.restauID,
      status: status ?? this.status,
      currency: currency ?? this.currency,
      cityID: cityID ?? this.cityID,
    );
  }

  /// Crée ou met à jour un plat via l'API REST Node.js.
  ///
  /// Les images sont d'abord uploadées via `/uploads/image`, puis le plat est
  /// créé (POST) ou modifié (PATCH) via `/dishes`.
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
    /// Chemins locaux des fichiers images à uploader.
    List<String>? imagePaths,
    String? img_url,
    String? images,
    String currency = 'EUR',
    int cityID = 1,
  }) async {
    try {
      final token = await SessionService.readNodeToken();
      if (token == null || token.isEmpty) {
        return "Erreur : Authentification requise. Veuillez vous reconnecter.";
      }

      // --- Upload des images via l'API Node.js ---
      String imageUrl = img_url ?? "";
      List<String> allUrls = [];

      if (imagePaths != null && imagePaths.isNotEmpty) {
        // Upload de l'image principale
        try {
          final imagePath = imagePaths.first;
          print('Upload image path: $imagePath');

          // Vérifier que le fichier existe
          final file = File(imagePath);
          if (!await file.exists()) {
            return "Erreur : Fichier image introuvable: $imagePath";
          }

          // Vérifier l'extension
          final extension = imagePath.toLowerCase().split('.').last;
          if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
            return "Erreur : Format non supporté ($extension). Utilisez JPEG, PNG ou WebP.";
          }

          final response = await NodeAuthService.uploadFile(
            '/uploads/image',
            token: token,
            filePath: imagePath,
            scope: 'dishes',
          );
          print('Upload response: $response');
          final data = response['data'];
          if (data is Map && data['url'] != null) {
            imageUrl = data['url'].toString();
          } else {
            // Si pas d'URL, vérifier s'il y a un message d'erreur
            final error = data['error'] ?? data['message'] ?? 'pas d\'URL retournée';
            return "Erreur : Upload image échoué - $error";
          }
        } catch (e) {
          print('Upload error: $e');
          return "Erreur : Upload image échoué - $e";
        }

        // Upload des images supplémentaires
        for (int i = 0; i < imagePaths.length; i++) {
          if (i == 0 && imageUrl.isNotEmpty) {
            allUrls.add(imageUrl);
            continue;
          }
          try {
            final response = await NodeAuthService.uploadFile(
              '/uploads/image',
              token: token,
              filePath: imagePaths[i],
              scope: 'dishes',
            );
            final data = response['data'];
            if (data is Map && data['url'] != null) {
              allUrls.add(data['url'].toString());
            }
          } catch (_) {}
        }
      } else if (imageUrl.isNotEmpty) {
        allUrls.add(imageUrl);
      }

      // Si de nouvelles images ont été uploadées, utiliser les nouvelles URLs
      // Sinon, conserver les images existantes
      final imagesStr = (imagePaths != null && imagePaths.isNotEmpty)
          ? allUrls.join(',')
          : (images ?? allUrls.join(','));

      // S'assurer que price est correctement formaté
      double finalPrice = price;
      if (price.toString().contains(',')) {
        finalPrice = double.parse(price.toString().replaceAll(',', '.'));
      }

      // --- Création / mise à jour du plat via l'API REST ---
      final body = <String, dynamic>{
        'userId': userID,
        'restaurantId': restauID,
        'categories': categories,
        'description': description,
        'option1': option1,
        'option2': option2,
        'option3': option3,
        'name': name,
        'rating': note,
        'orderCount': nb_orders,
        'image': imageUrl,
        'images': imagesStr,
        'price': finalPrice,
        'servings': nb_servings,
        'cityId': cityID,
        'status': status,
        'currency': currency,
      };

      Map<String, dynamic> response;
      if (dishID != null) {
        // Chercher l'UUID du plat à partir de son dishId numérique
        final existing = await NodeAuthService.getJson(
          '/dishes',
          token: token,
          queryParameters: {'pageSize': '100'},
        );
        final existingData = existing['data'];
        String? uuid;
        if (existingData is List) {
          for (final item in existingData) {
            if (item is Map && item['dishId'] == dishID) {
              uuid = item['id']?.toString();
              break;
            }
          }
        }
        if (uuid == null) {
          return "Erreur : plat introuvable pour la mise à jour.";
        }
        response = await NodeAuthService.patchJson(
          '/dishes/$uuid',
          token: token,
          body: body,
        );
      } else {
        response = await NodeAuthService.postJson(
          '/dishes',
          token: token,
          body: body,
        );
      }

      final data = response['data'];
      if (data is Map) {
        int updatedDishID = dishID ?? (data['dishId'] as int? ?? 0);

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
            image: imageUrl,
            images: imagesStr,
            userID: userID,
            price: finalPrice,
            nb_servings: nb_servings,
            restauID: restauID,
            status: status,
            currency: currency,
            cityID: cityID);

        if (dishID == null) {
          await DatabaseHelper.createDish(dish);
        } else {
          await DatabaseHelper.updateDish(dish);
        }

        notifyDataChanged();
        return "success";
      } else {
        return "Erreur : réponse inattendue du serveur.";
      }
    } catch (e) {
      return "Erreur : $e";
    }
  }

  /// Met à jour le statut d'un plat via l'API REST Node.js.
  static Future<String> updateDishStatus(int dishID, int status) async {
    try {
      final token = await SessionService.readNodeToken();
      if (token == null || token.isEmpty) {
        return "Erreur : Authentification requise.";
      }

      // Chercher l'UUID du plat
      final existing = await NodeAuthService.getJson(
        '/dishes',
        token: token,
        queryParameters: {'pageSize': '100'},
      );
      final existingData = existing['data'];
      String? uuid;
      if (existingData is List) {
        for (final item in existingData) {
          if (item is Map && item['dishId'] == dishID) {
            uuid = item['id']?.toString();
            break;
          }
        }
      }
      if (uuid == null) {
        return "Erreur : plat introuvable.";
      }

      await NodeAuthService.patchJson(
        '/dishes/$uuid',
        token: token,
        body: {'status': status},
      );

      await DatabaseHelper.updateDishStatus(dishID, status);
      notifyDataChanged();
      return "success";
    } catch (e) {
      return "Erreur : $e";
    }
  }

  /// Supprime un plat via l'API REST Node.js (soft delete).
  static Future<String> suppr1Dish(int dishID) async {
    try {
      final token = await SessionService.readNodeToken();
      if (token == null || token.isEmpty) {
        return "Erreur : Authentification requise.";
      }

      // Chercher l'UUID du plat
      final existing = await NodeAuthService.getJson(
        '/dishes',
        token: token,
        queryParameters: {'pageSize': '100'},
      );
      final existingData = existing['data'];
      String? uuid;
      if (existingData is List) {
        for (final item in existingData) {
          if (item is Map && item['dishId'] == dishID) {
            uuid = item['id']?.toString();
            break;
          }
        }
      }
      if (uuid == null) {
        return "Erreur : plat introuvable.";
      }

      await NodeAuthService.deleteJson(
        '/dishes/$uuid',
        token: token,
      );

      await DatabaseHelper.deleteDish(dishID);
      notifyDataChanged();
      return "success";
    } catch (e) {
      return "Erreur : $e";
    }
  }

  /// Charge tous les plats depuis l'API REST Node.js et les persiste en cache local.
  static Future<bool> getAllDishesDetails() async {
    try {
      final token = await SessionService.readNodeToken();
      final response = await NodeAuthService.getJson(
        '/dishes',
        token: token,
        queryParameters: {'pageSize': '100'},
      );

      final data = response['data'];
      if (data is List) {
        for (var dishData in data) {
          if (dishData is Map) {
            final map = Map<String, dynamic>.from(dishData);
            final dishMap = {
              'dishID': map['dishId'],
              'userID': map['userId'],
              'categories': map['categories'],
              'description': map['description'],
              'option1': map['option1'],
              'option2': map['option2'],
              'option3': map['option3'],
              'name': map['name'],
              'image': map['image'],
              'images': map['images'],
              'price': map['price'],
              'nb_orders': map['orderCount'],
              'nb_servings': map['servings'],
              'restauID': map['restaurantId'],
              'status': map['status'],
              'note': map['rating'],
              'currency': map['currency'],
              'country': map['country'],
              'cityID': map['cityId'],
            };
            Dish dish = Dish.fromMap(dishMap);
            await DatabaseHelper.createDish(dish);
          }
        }
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
    return true;
  }

  List<String> getImageUrls() {
    final urls = <String>[];
    if (image != null && image!.trim().isNotEmpty) urls.add(image!);
    if (images.isNotEmpty) {
      urls.addAll(images.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty));
    }
    return urls;
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

class DishOption {
  final String name;
  final List<String> choices;
  final double price;

  DishOption({
    required this.name,
    required this.choices,
    this.price = 0.0,
  });
}
