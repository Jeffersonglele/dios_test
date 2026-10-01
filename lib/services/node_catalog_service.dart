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
            .map((row) => Dish.fromMap(_dishMap(Map<String, dynamic>.from(row))))
            .toList()
        : <Dish>[];

    return NodeRestaurantMenu(
      restaurant: Restaurant.fromMap(_restaurantMap(restaurantData)),
      dishes: dishes,
    );
  }

  static Map<String, dynamic> _restaurantMap(Map<String, dynamic> row) {
    final dateCreation = row['dateCreation'];
    return {
      'restaurantID': row['restaurantId'],
      'userID': row['userId'],
      'categories': row['categories'],
      'description': row['description'],
      'adress': row['address'],
      'name': row['name'],
      'note': row['rating'],
      'nb_orders': row['orderCount'],
      'image': row['image'],
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
    return {
      'dishID': row['dishId'],
      'userID': row['userId'],
      'categories': row['categories'],
      'description': row['description'],
      'option1': row['option1'],
      'option2': row['option2'],
      'option3': row['option3'],
      'name': row['name'],
      'image': row['image'],
      'images': row['images'],
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
}
