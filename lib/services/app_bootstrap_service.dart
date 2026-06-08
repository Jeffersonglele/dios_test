import '../models/address.dart';
import '../models/commande.dart';
import '../models/dish.dart';
import '../models/identity.dart';
import '../models/ligne_commande.dart';
import '../models/moyen_paiement.dart';
import '../models/restaurant.dart';
import '../models/users.dart';

class AppBootstrapService {
  const AppBootstrapService._();

  static Future<void> syncInitialData() async {
    await Users.getAllUsersDetails();
    await Restaurant.getAllRestaurantsDetails();
    await Dish.getAllDishesDetails();
    await Address.getAllAdressesDetails();
  }
}
