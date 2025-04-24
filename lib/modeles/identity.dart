import 'package:hive/hive.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import '../db/database_helper.dart';

part 'identity.g.dart';

@HiveType(typeId: 5)
class Identity extends HiveObject {
  @HiveField(0)
  final int identityID;

  @HiveField(1)
  int? userID;

  @HiveField(2)
  String? piece_identite;

  @HiveField(3)
  String? photo;

  Identity({
    required this.identityID,
    this.userID,
    this.piece_identite,
    this.photo});

  Map<String, dynamic> toJson() {
    return {
      'identityID': identityID,
      'userID': userID,
      'piece_identite': piece_identite,
      'photo': photo,
    };
  }

  factory Identity.fromMap(Map<String, dynamic> map) {
    return Identity(
        identityID: int.tryParse(map['identityID']?.toString() ?? '0') ?? 0,
        userID: int.tryParse(map['userID']?.toString() ?? '0') ?? 0,
        photo: map['photo']?.toString() ?? '',
        piece_identite: map['piece_identite']?.toString() ?? ''
    );
  }

  static Future<dynamic> manageIdentity({
    int? identityID,
    required int userID,
    ParseFile? piece_identite,
    ParseFile? photo,
    required String photo_name,
    required String piece_name,
  }) async {
    String functionName = identityID == null ? 'addIdentity' : 'updateIdentity';
    var cloudFunction = ParseCloudFunction(functionName);

    Future<String?> uploadFileToGallery(ParseFile file, String nom) async {
      final response = await file.save();

      if (response.success && response.result != null) {
        final fileUrl = (response.result as ParseFile).url ?? "";

        final gallery = ParseObject('Gallery')
          ..set('file', file)
          ..set('nom', nom);

        final galleryResponse = await gallery.save();

        if (galleryResponse.success) {
          return fileUrl;
        } else {
          return null;
        }
      } else {
        return null;
      }
    }

    // ✅ Upload conditionnel des fichiers
    String? urlPhoto;
    if (photo != null) {
      urlPhoto = await uploadFileToGallery(photo, photo_name);
      if (urlPhoto == null) {
        return "Erreur : l'upload de la photo a échoué.";
      }
    }

    String? urlPiece;
    if (piece_identite != null) {
      urlPiece = await uploadFileToGallery(piece_identite, piece_name);
      if (urlPiece == null) {
        return "Erreur : l'upload de la pièce d'identité a échoué.";
      }
    }

    // Préparation des paramètres
    var params = <String, dynamic>{
      if (identityID != null) 'identityID': identityID,
      if (urlPiece != null) 'piece_identite': urlPiece,
      if (urlPhoto != null) 'photo': urlPhoto,
      'userID': userID,
    };

    try {
      final ParseResponse parseResponse = await cloudFunction.execute(parameters: params);

      if (parseResponse.success && parseResponse.result != null) {
        var response = parseResponse.result as Map<String, dynamic>;
        if (response['success'] == false) {
          return "Erreur : ${response['error']}";
        } else {
          int updatedIdentityID = identityID ?? response['identityID'];

          Identity identity = Identity(
            identityID: updatedIdentityID,
            userID: userID,
            photo: urlPhoto ?? '',
            piece_identite: urlPiece ?? '',
          );

          if (identityID == null) {
            await DatabaseHelper.createIdentity(identity);
          } else {
            await DatabaseHelper.updateIdentity(identity);
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

  /// 🔹 **Supprimer une Adresse sur Back4App et Hive**
  static Future<String> deleteIdentity(int identityID) async {
    var cloudFunction = ParseCloudFunction('deleteIdentity');
    var params = <String, dynamic>{'identityID': identityID};

    try {
      final ParseResponse parseResponse =
          await cloudFunction.execute(parameters: params);

      if (parseResponse.success && parseResponse.result != null) {
        var response = parseResponse.result as Map<String, dynamic>;

        if (response['success'] == true) {
          await DatabaseHelper.deleteIdentity(identityID);
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

  static Future<List<Identity>> fetchIdentitiesFromDB() async {
    List<Identity> identityList = await DatabaseHelper.readAllIdentities();
    print("fetchIdentitiesFromDB " + identityList.toString());
    return identityList;
  }

  /// 🔹 **Récupérer toutes les identities depuis Back4App et les enregistrer en local**
  static Future<bool> fetchAllIdentities() async {
    var cloudFunction = ParseCloudFunction('getAllIdentities');

    try {
      var response = await cloudFunction.execute();

      if (response.success) {
        List<dynamic> identityDataList = response.result;
        List<Identity> identities =
            identityDataList.map((data) => Identity.fromMap(data)).toList();

        // 🔹 Stocker toutes les identities localement dans Hive
        await DatabaseHelper.saveAllIdentities(identities);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  static Future<bool> getAllIdentitiesDetails() async {
    var cloudFunction = ParseCloudFunction('getAllIdentities');

    try {
      var response = await cloudFunction.execute();

      if (response.success) {
        List<dynamic> identityDataList = response.result;

        for (var identityData in identityDataList) {
          Identity identity = Identity.fromMap(identityData);

          // ✅ Attention : Hive accepte uniquement des clés de type String ou int
          await DatabaseHelper.createIdentity(identity);
        }
      } else {
        print('❌ Échec de récupération des identités : ${response.error?.message}');
        return false;
      }
    } catch (e) {
      print('❌ Erreur lors de l’appel à la fonction cloud : $e');
      return false;
    }

    return true;
  }

  static Identity? getIdentityByUserId(List<Identity> identities, int id) {
    try {
      return identities.firstWhere((identity) => identity.userID == id);
    } catch (e) {
      return null;
    }
  }

}
