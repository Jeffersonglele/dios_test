import 'package:hive/hive.dart';

import '../db/database_helper.dart';
import '../services/node_auth_service.dart';
import '../services/session_service.dart';

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
      documentID: int.tryParse(map['documentID']?.toString() ?? map['documentId']?.toString() ?? '0') ?? 0,
      userID: int.tryParse(map['userID']?.toString() ?? map['userId']?.toString() ?? '0') ?? 0,
      restaurantID: int.tryParse(map['restaurantID']?.toString() ?? map['restaurantId']?.toString() ?? '0') ?? 0,
      siretUrl: map['siretUrl']?.toString() ?? '',
      kbisUrl: map['kbisUrl']?.toString() ?? '',
      pieceIdentiteUrl: map['pieceIdentiteUrl']?.toString() ?? map['identityDocumentUrl']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      remark: map['remark']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
    );
  }

  /// Upload a single file to the Node.js backend, returns the URL.
  static Future<String?> _uploadFile(String filePath, String token) async {
    try {
      final response = await NodeAuthService.uploadFile(
        '/uploads/image',
        token: token,
        filePath: filePath,
        scope: 'pro-documents',
      );
      final data = response['data'];
      if (data is Map) {
        return data['url']?.toString();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<String> submitDocuments({
    int? documentID,
    required int userID,
    required int restaurantID,
    String? siretPath,
    String? kbisPath,
    String? pieceIdentitePath,
    String? description,
  }) async {
    final token = await SessionService.readNodeToken();
    if (token == null) return "Erreur : session expirée, veuillez vous reconnecter.";

    // Upload files if provided
    String? siretUrl;
    if (siretPath != null) {
      siretUrl = await _uploadFile(siretPath, token);
      if (siretUrl == null) return "Erreur : l'upload du SIRET a échoué.";
    }

    String? kbisUrl;
    if (kbisPath != null) {
      kbisUrl = await _uploadFile(kbisPath, token);
      if (kbisUrl == null) return "Erreur : l'upload du KBIS a échoué.";
    }

    String? pieceIdentiteUrl;
    if (pieceIdentitePath != null) {
      pieceIdentiteUrl = await _uploadFile(pieceIdentitePath, token);
      if (pieceIdentiteUrl == null) return "Erreur : l'upload de la pièce d'identité a échoué.";
    }

    final body = <String, dynamic>{
      'userId': userID,
      'restaurantId': restaurantID,
      if (siretUrl != null) 'siretUrl': siretUrl,
      if (kbisUrl != null) 'kbisUrl': kbisUrl,
      if (pieceIdentiteUrl != null) 'identityDocumentUrl': pieceIdentiteUrl,
      if (description != null && description.isNotEmpty) 'description': description,
      'status': 'pending',
    };

    try {
      final Map<String, dynamic> response;
      if (documentID == null) {
        // Create
        response = await NodeAuthService.postJson(
          '/verification/pro-documents',
          token: token,
          body: body,
        );
      } else {
        // Update
        response = await NodeAuthService.patchJson(
          '/verification/pro-documents/$documentID',
          token: token,
          body: body,
        );
      }

      final data = response['data'];
      if (data is Map<String, dynamic>) {
        int updatedDocumentID = documentID ??
            (int.tryParse(data['documentId']?.toString() ?? '0') ?? 0);

        ProDocument doc = ProDocument(
          documentID: updatedDocumentID,
          userID: userID,
          restaurantID: restaurantID,
          siretUrl: siretUrl ?? '',
          kbisUrl: kbisUrl ?? '',
          pieceIdentiteUrl: pieceIdentiteUrl ?? '',
          description: description ?? '',
        );

        if (documentID == null) {
          await DatabaseHelper.createProDocument(doc);
        }

        return "success";
      } else {
        return "Erreur : réponse inattendue du serveur.";
      }
    } catch (e) {
      return "Exception lors de l'envoi des documents : $e";
    }
  }

  static Future<bool> getAllProDocuments() async {
    final token = await SessionService.readNodeToken();
    if (token == null) return false;

    try {
      final response = await NodeAuthService.getJson(
        '/verification/pro-documents',
        token: token,
      );

      final dataList = response['data'];
      if (dataList is List) {
        for (var data in dataList) {
          ProDocument doc = ProDocument.fromMap(data as Map<String, dynamic>);
          await DatabaseHelper.createProDocument(doc);
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<List<ProDocument>> fetchProDocumentsFromDB() async {
    return await DatabaseHelper.readAllProDocuments();
  }
}

