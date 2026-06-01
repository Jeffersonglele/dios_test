import '../modeles/address.dart';
import '../modeles/commande.dart';
import '../modeles/dish.dart';
import '../modeles/identity.dart';
import '../modeles/ligne_commande.dart';
import '../modeles/moyen_paiement.dart';
import '../modeles/restaurant.dart';
import '../modeles/users.dart';

class AppBootstrapService {
  const AppBootstrapService._();

  static Future<void> syncInitialData() async {
    await Users.getAllUsersDetails();
    await Restaurant.getAllRestaurantsDetails();
    await Dish.getAllDishesDetails();
    await Address.getAllAdressesDetails();
  }
}
