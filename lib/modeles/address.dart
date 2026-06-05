import 'package:hive/hive.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import '../db/database_helper.dart';

part 'address.g.dart';

@HiveType(typeId: 4)
class Address extends HiveObject {
  @HiveField(0)
  String? object;

  @HiveField(2)
  int? numero;

  @HiveField(3)
  String? city;

  @HiveField(4)
  String? state;

  @HiveField(5)
  String? fullAddress;

  @HiveField(6)
  String? lat;

  @HiveField(7)
  String? long;

  @HiveField(8)
  int? addressID;

  @HiveField(9)
  int? objectID;

  Address({
    this.object,
    this.numero,
    this.city,
    this.state,
    this.fullAddress,
    this.lat,
    this.long,
    this.objectID,
    this.addressID,
  });

  Map<String, dynamic> toJson() {
    return {
      'object': object,
      'objectID': objectID,
      'addressID': addressID,
      'numero': numero,
      'city': city,
      'state': state,
      'fullAddress': fullAddress,
      'lat': lat,
      'long': long,
    };
  }

  factory Address.fromMap(Map<String, dynamic> map) {
    return Address(
      addressID: int.tryParse(map['addressID']?.toString() ?? '0') ?? 0,
      object: map['object']?.toString() ?? '',
      objectID: int.tryParse(map['objectID']?.toString() ?? '0') ?? 0,
      numero: int.tryParse(map['numero']?.toString() ?? '0') ?? 0,
      city: map['city']?.toString() ?? '',
      state: map['state']?.toString() ?? '',
      fullAddress: map['fullAddress']?.toString() ?? '',
      lat: map['lat']?.toString() ?? '',
      long: map['long']?.toString() ?? '',
    );
  }

  static Future<dynamic> manageAddress({
    int? addressID,
    required objectID,
    required user_roleID,
    required object,
    int? numero,
    required String city,
    required String state,
    required String fullAddress,
    String? lat,
    String? long,
  }) async {
    // Choix de la Cloud Function (ajout ou mise à jour)
    String functionName = addressID == null ? 'addAddress' : 'updateAddress';
    var cloudFunction = ParseCloudFunction(functionName);

    var params = <String, dynamic>{
      if (addressID != null) 'addressID': addressID,
      'city': city,
      'numero': numero ?? 0,
      'objectID': objectID,
      'user_roleID': user_roleID,
      'object': object,
      'state': state,
      'fullAddress': fullAddress,
      'lat': lat,
      'long': long,
    };


    try {
      final ParseResponse parseResponse = await cloudFunction.execute(parameters: params);

      if (parseResponse.success && parseResponse.result != null) {
        var response = parseResponse.result as Map<String, dynamic>;

        if (response['success'] == false) {
          if(response['exist'] == true){
            if (response['exist'] == true) {
              return "EXISTING_ADDRESS";
            }
          }
          return "Erreur : ${response['error']}";
        } else {
          int newAddressID = addressID ?? response['addressID'];

          Address newAddress = Address(
            addressID: newAddressID,
            object: object,
            objectID: objectID,
            city: city,
            state: state,
            fullAddress: fullAddress,
            lat: lat,
            long: long,
          );

          // 🔹 Enregistrer localement dans Hive
          await DatabaseHelper.addAddress(newAddress);

          return newAddressID;
        }
      } else {
        return "Erreur Cloud Function : ${parseResponse.error?.message}";
      }
    } catch (e) {
      return "Exception Cloud Function : $e";
    }
  }

  /// 🔹 **Supprimer une Adresse sur Back4App et Hive**
  static Future<String> deleteAddress({required int addressID, required String object, required int objectID, }) async {
    var cloudFunction = ParseCloudFunction('deleteAddress');
    var params = <String, dynamic>{
      'addressID': addressID,
      'object': object,
      'objectID': objectID
    };

    try {
      final ParseResponse parseResponse = await cloudFunction.execute(parameters: params);

      if (parseResponse.success && parseResponse.result != null) {
        var response = parseResponse.result as Map<String, dynamic>;

        if (response['success'] == true) {
          await DatabaseHelper.deleteAddress(addressID);
          return "success";
        } else {
          return "Erreur : ${response['error']}";
        }
      } else {
        return "Erreur Cloud Function : ${parseResponse.error?.message}";
      }
    } catch (e) {
      return "Exception Cloud Function : $e";
    }
  }

  /// 🔹 **Récupérer toutes les adresses depuis Back4App et les enregistrer en local**
  static Future<bool> getAllAdressesDetails() async {
    var cloudFunction = ParseCloudFunction('getAllAdresses');

    try {
      var response = await cloudFunction.execute();

      if (response.success) {
        List<dynamic> addressDataList = response.result;
        for (var addressData in addressDataList) {
          Address address = Address.fromMap(addressData);
          await DatabaseHelper.createAddress(address);
        }
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
    return true;
  }

  static Future<List<Address>> fetchAddressesFromDB() async {
    List<Address> addressList = await DatabaseHelper.readAllAddresses();
    return addressList;
  }

  static Address? getAddressByObject(List<Address> listAddresses, String object, int objectID) {
    try {
      return listAddresses.firstWhere((address) => address.object == object && address.objectID == objectID);
    } catch (e) {
      return null;
    }
  }
}
