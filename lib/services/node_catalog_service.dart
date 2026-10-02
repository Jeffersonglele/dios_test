import '../config/app_config.dart';
import '../models/dish.dart';
import '../models/restaurant.dart';
import 'node_auth_service.dart';

class NodeRestaurantMenu {
  const NodeRestaurantMenu({required this.restaurant, required this.dishes});

  final Restaurant restaurant;
  final List<Dish> dishes;
}

class NodeCatalogService {
  const NodeCatalogService._();

  static String? resolveMediaUrl(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final base = AppConfig.nodeBackendUrl.replaceFirst(RegExp(r'/+$'), '');
    if (raw.startsWith('/')) return '$base$raw';
    return '$base/$raw';
  }

  static Future<Restaurant> loadRestaurant({
    required int restaurantId,
    String? token,
  }) async {
    final response = await NodeAuthService.getJson(
      '/restaurants/$restaurantId',
      token: token,
    );
    final data = response['data'];
    if (data is! Map) {
      throw const NodeAuthException('Restaurant invalide.');
    }
    return Restaurant.fromMap(
      _restaurantMap(Map<String, dynamic>.from(data)),
    );
  }

  static Future<List<Dish>> loadDishes({
    String? token,
    int? restaurantId,
    int? status,
  }) async {
    final query = <String, String>{'pageSize': '100'};
    if (restaurantId != null) query['restaurantId'] = '$restaurantId';
    if (status != null) query['status'] = '$status';
    final response = await NodeAuthService.getJson(
      '/dishes',
      token: token,
      queryParameters: query,
    );
    final data = response['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((row) => Dish.fromMap(_dishMap(Map<String, dynamic>.from(row))))
        .toList();
  }

  static Future<NodeRestaurantMenu> loadRestaurantMenu({
    required int restaurantId,
    String? token,
  }) async {
    final response = await NodeAuthService.getJson(
      '/restaurants/$restaurantId/menu',
      token: token,
      queryParameters: const {'pageSize': '100'},
    );
    final data = response['data'];
    if (data is! Map) {
      throw const NodeAuthException('Menu du restaurant invalide.');
    }

    final restaurantData = Map<String, dynamic>.from(data['restaurant'] as Map);
    final dishData = data['dishes'];
    final dishes = dishData is List
        ? dishData
            .whereType<Map>()
            .map(
                (row) => Dish.fromMap(_dishMap(Map<String, dynamic>.from(row))))
            .toList()
        : <Dish>[];

    return NodeRestaurantMenu(
      restaurant: Restaurant.fromMap(_restaurantMap(restaurantData)),
      dishes: dishes,
    );
  }

  static Map<String, dynamic> _restaurantMap(Map<String, dynamic> row) {
    final dateCreation = row['dateCreation'];
    final imageUrl = resolveMediaUrl(row['image'] ?? row['fileUrl'] ?? '');
    return {
      'restaurantID': row['restaurantId'],
      'userID': row['userId'],
      'categories': row['categories'],
      'description': row['description'],
      'adress': row['address'],
      'name': row['name'],
      'note': row['rating'],
      'nb_orders': row['orderCount'],
      'image': imageUrl ?? '',
      'valid': row['valid'],
      'date_creation': dateCreation == null ? null : {'iso': dateCreation},
      'openingHours': row['openingHours'],
      'deliveryFee': row['deliveryFee'],
      'isOpen': row['isOpen'],
      'professionalType': row['professionalType'],
      'trainingCompleted': row['trainingCompleted'],
      'reviewRemark': row['reviewRemark'],
      'currency': row['currency'],
      'openingDays': row['openingDays'],
      'minOrderAmount': row['minOrderAmount'],
      'deliveryRadius': row['deliveryRadius'],
      'closedDates': row['closedDates'],
      'recoveryMode': row['recoveryMode'],
      'country': row['country'],
      'cityID': row['cityId'],
      'paymentMethod': row['paymentMethod'],
      'mobileMoneyPhone': row['mobileMoneyPhone'],
      'iban': row['iban'],
      'bankName': row['bankName'],
      'accountHolder': row['accountHolder'],
      'rccm': row['rccm'],
      'isPro': row['isPro'],
      'latitude': row['latitude'],
      'longitude': row['longitude'],
    };
  }

  static Map<String, dynamic> _dishMap(Map<String, dynamic> row) {
    final imageUrl = resolveMediaUrl(row['image'] ?? row['fileUrl'] ?? '');
    final rawImages = row['images'];
    List<String>? resolvedImages;
    if (rawImages is List) {
      resolvedImages = rawImages
          .map((e) => resolveMediaUrl(e) ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (rawImages is String && rawImages.isNotEmpty) {
      final parts = rawImages.split(RegExp(r'[,;|]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      resolvedImages = parts
          .map((e) => resolveMediaUrl(e) ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return {
      'dishID': row['dishId'],
      'userID': row['userId'],
      'categories': row['categories'],
      'description': row['description'],
      'option1': row['option1'],
      'option2': row['option2'],
      'option3': row['option3'],
      'name': row['name'],
      'image': imageUrl ?? '',
      'images': resolvedImages != null ? resolvedImages.join(',') : (row['images']?.toString() ?? ''),
      'price': row['price'],
      'nb_orders': row['orderCount'],
      'nb_servings': row['servings'],
      'restauID': row['restaurantId'],
      'status': row['status'],
      'note': row['rating'],
      'currency': row['currency'],
      'country': row['country'],
      'cityID': row['cityId'],
    };
  }

  static Future<Map<String, dynamic>> manageRestaurantLegacy({
    required String token,
    int? restaurantID,
    required int userID,
    required int valid,
    required int nb_orders,
    required double note,
    required String categories,
    required String description,
    required String location,
    required String name,
    String? imageUrl,
    String openingHours = '09:00 - 20:00',
    double deliveryFee = 0.0,
    int isOpen = 1,
    String professionalType = 'amateur',
    bool trainingCompleted = false,
    bool isPro = false,
    String currency = '',
    String country = '',
    String openingDays = 'Lun,Mar,Mer,Jeu,Ven,Sam',
    String recoveryMode = 'delivery',
    int cityID = 1,
    String paymentMethod = '',
    String mobileMoneyPhone = '',
    String iban = '',
    String bankName = '',
    String accountHolder = '',
    String rccm = '',
    double minOrderAmount = 0,
    double deliveryRadius = 10,
    String closedDates = '',
    String openingHoursByDay = '',
  }) async {
    final body = <String, dynamic>{
      if (restaurantID != null) 'restaurantID': restaurantID,
      'userID': userID,
      'valid': valid,
      'nb_orders': nb_orders,
      'note': note,
      'categories': categories,
      'description': description,
      'adress': location,
      'name': name,
      if (imageUrl != null) 'image': imageUrl,
      'openingHours': openingHours,
      'deliveryFee': deliveryFee,
      'isOpen': isOpen,
      'professionalType': professionalType,
      'trainingCompleted': trainingCompleted,
      'isPro': isPro,
      'currency': currency,
      'country': country,
      'openingDays': openingDays,
      'recoveryMode': recoveryMode,
      'cityID': cityID,
      'paymentMethod': paymentMethod,
      'mobileMoneyPhone': mobileMoneyPhone,
      'iban': iban,
      'bankName': bankName,
      'accountHolder': accountHolder,
      'rccm': rccm,
      'minOrderAmount': minOrderAmount,
      'deliveryRadius': deliveryRadius,
      'closedDates': closedDates,
      'openingHoursByDay': openingHoursByDay,
    };
    final res = restaurantID != null
        ? await NodeAuthService.patchJson(
            '/restaurants/legacy/$restaurantID',
            token: token,
            body: body,
          )
        : await NodeAuthService.postJson(
            '/restaurants/legacy',
            token: token,
            body: body,
          );
    final data = res['data'] as Map<String, dynamic>;
    final meta = res['meta'] as Map<String, dynamic>?;
    final legacyId = data['restaurantId'] as int?;
    final fallbackId =
        legacyId ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return {
      'restaurantID': fallbackId,
      'legacyIdProvided': legacyId != null,
      'mode': meta?['mode'] ?? (restaurantID != null ? 'updated' : 'created'),
      'data': data,
    };
  }
}