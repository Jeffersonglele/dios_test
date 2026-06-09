import 'package:hive/hive.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import '../db/database_helper.dart';

part 'pro_document.g.dart';

@HiveType(typeId: 15)
class ProDocument extends HiveObject {
  @HiveField(0)
  final int documentID;

  @HiveField(1)
  int userID;

  @HiveField(2)
  int restaurantID;

  @HiveField(3)
  String siretUrl;

  @HiveField(4)
  String kbisUrl;

  @HiveField(5)
  String pieceIdentiteUrl;

  @HiveField(6)
  String status;

  @HiveField(7)
  String remark;

  @HiveField(8)
  String description;

  ProDocument({
    required this.documentID,
    required this.userID,
    required this.restaurantID,
    this.siretUrl = '',
    this.kbisUrl = '',
    this.pieceIdentiteUrl = '',
    this.status = 'pending',
    this.remark = '',
    this.description = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'documentID': documentID,
      'userID': userID,
      'restaurantID': restaurantID,
      'siretUrl': siretUrl,
      'kbisUrl': kbisUrl,
      'pieceIdentiteUrl': pieceIdentiteUrl,
      'status': status,
      'remark': remark,
      'description': description,
    };
  }

  factory ProDocument.fromMap(Map<String, dynamic> map) {
    return ProDocument(
      documentID: int.tryParse(map['documentID']?.toString() ?? '0') ?? 0,
      userID: int.tryParse(map['userID']?.toString() ?? '0') ?? 0,
      restaurantID: int.tryParse(map['restaurantID']?.toString() ?? '0') ?? 0,
      siretUrl: map['siretUrl']?.toString() ?? '',
      kbisUrl: map['kbisUrl']?.toString() ?? '',
      pieceIdentiteUrl: map['pieceIdentiteUrl']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      remark: map['remark']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
    );
  }

  static Future<String> submitDocuments({
    int? documentID,
    required int userID,
    required int restaurantID,
    ParseFile? siret,
    ParseFile? kbis,
    ParseFile? pieceIdentite,
    String? description,
  }) async {
    String functionName = documentID == null
        ? 'submitRestaurantProDocuments'
        : 'updateRestaurantProDocuments';
    var cloudFunction = ParseCloudFunction(functionName);

    Future<String?> uploadFile(ParseFile file) async {
      final response = await file.save();
      if (response.success && response.result != null) {
        return (response.result as ParseFile).url ?? '';
      }
      return null;
    }

    String? siretUrl;
    if (siret != null) {
      siretUrl = await uploadFile(siret);
      if (siretUrl == null) {
        return "Erreur : l'upload du SIRET a échoué.";
      }
    }

    String? kbisUrl;
    if (kbis != null) {
      kbisUrl = await uploadFile(kbis);
      if (kbisUrl == null) {
        return "Erreur : l'upload du KBIS a échoué.";
      }
    }

    String? pieceIdentiteUrl;
    if (pieceIdentite != null) {
      pieceIdentiteUrl = await uploadFile(pieceIdentite);
      if (pieceIdentiteUrl == null) {
        return "Erreur : l'upload de la pièce d'identité a échoué.";
      }
    }

    var params = <String, dynamic>{
      if (documentID != null) 'documentID': documentID,
      'userID': userID,
      'restaurantID': restaurantID,
      if (siretUrl != null) 'siretUrl': siretUrl,
      if (kbisUrl != null) 'kbisUrl': kbisUrl,
      if (pieceIdentiteUrl != null) 'pieceIdentiteUrl': pieceIdentiteUrl,
      if (description != null && description.isNotEmpty) 'description': description,
    };

    try {
      final ParseResponse parseResponse =
          await cloudFunction.execute(parameters: params);

      if (parseResponse.success && parseResponse.result != null) {
        var response = parseResponse.result as Map<String, dynamic>;
        if (response['success'] == false) {
          return "Erreur : ${response['error']}";
        } else {
          int updatedDocumentID = documentID ?? response['documentID'];

          ProDocument doc = ProDocument(
            documentID: updatedDocumentID,
            userID: userID,
            restaurantID: restaurantID,
            siretUrl: siretUrl ?? '',
            kbisUrl: kbisUrl ?? '',
            pieceIdentiteUrl: pieceIdentiteUrl ?? '',
          );

          if (documentID == null) {
            await DatabaseHelper.createProDocument(doc);
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

  static Future<bool> getAllProDocuments() async {
    var cloudFunction = ParseCloudFunction('getAllProDocuments');

    try {
      var response = await cloudFunction.execute();

      if (response.success) {
        List<dynamic> dataList = response.result;
        for (var data in dataList) {
          ProDocument doc = ProDocument.fromMap(data);
          await DatabaseHelper.createProDocument(doc);
        }
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  static Future<List<ProDocument>> fetchProDocumentsFromDB() async {
    return await DatabaseHelper.readAllProDocuments();
  }
}
