import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../modeles/address.dart';

final addressProvider =
    StateNotifierProvider<AddressNotifier, List<Address>>((ref) {
  return AddressNotifier();
});

class AddressNotifier extends StateNotifier<List<Address>> {
  AddressNotifier() : super([]);

  /// 🔹 Charger les adresses depuis Hive
  Future<void> loadAddresses() async {
    final addresses = await DatabaseHelper.getAllAddresses();
    state = addresses;
  }

  /// 🔹 Ajouter une nouvelle adresse sur Hive et Back4App
  Future<void> addAddress(Address address) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int userRole = prefs.getInt('currentUser_role') ?? 0;

    var result = await Address.manageAddress(
      city: address.city!,
      numero: address.numero,
      state: address.state!,
      fullAddress: address.fullAddress!,
      lat: address.lat,
      long: address.long,
      objectID: address.objectID,
      user_roleID: userRole,
      object: address.object,
    );

    if (result is int) {
      address.objectID = result;
      state = [...state, address];
    }
  }
}
