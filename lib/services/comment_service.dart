import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import 'node_auth_service.dart';
import 'session_service.dart';

/// Avis client (restaurant = 1, plat = 2, livreur = 3).
class CommentData {
  final String id;
  final int userID;
  final int targetType;
  final int targetID;
  final int note;
  final String commentaire;
  final String username;
  final String userImage;
  final DateTime createdAt;
  final List<String> tags;

  CommentData({
    required this.id,
    required this.userID,
    required this.targetType,
    required this.targetID,
    required this.note,
    required this.commentaire,
    required this.username,
    required this.userImage,
    required this.createdAt,
    this.tags = const [],
  });

  /// Accepte le format du backend Node (/reviews) et l'ancien format Parse.
  factory CommentData.fromMap(Map<String, dynamic> map) {
    final rawTags = map['tags'];
    final tags = rawTags is List
        ? rawTags.map((e) => e.toString()).toList()
        : <String>[];
    int asInt(Object? v) => int.tryParse(v?.toString() ?? '') ?? 0;
    return CommentData(
      id: (map['id'] ?? map['objectId'] ?? '').toString(),
      userID: asInt(map['userId'] ?? map['userID']),
      targetType: asInt(map['targetType'] ?? map['target']),
      targetID: asInt(map['targetId'] ?? map['targetID']),
      note: asInt(map['rating'] ?? map['note']),
      commentaire:
          (map['comment'] ?? map['commentaire'] ?? map['description'] ?? '')
              .toString(),
      username: map['username']?.toString() ?? '',
      userImage: map['userImage']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
      tags: tags,
    );
  }
}

/// Avis clients : backend Node (/reviews), repli Parse pour les anciens
/// comptes sans session Node.
class CommentService {
  const CommentService._();

  static Map<String, String> _target(int targetType, int targetID) => {
        'targetType': '$targetType',
        'targetId': '$targetID',
      };

  /// Retourne "success" ou un message d'erreur lisible.
  /// [orderId] : commande livrée qui justifie l'avis (recommandé).
  static Future<String> addComment({
    required int userID,
    required int targetType,
    required int targetID,
    required int note,
    required String commentaire,
    required String username,
    String userImage = '',
    List<String> tags = const [],
    int? orderId,
  }) async {
    final token = await SessionService.readNodeToken();
    if (token != null && token.isNotEmpty) {
      try {
        await NodeAuthService.postJson(
          '/reviews',
          token: token,
          body: {
            'targetType': targetType,
            'targetId': targetID,
            'rating': note,
            'comment': commentaire,
            if (tags.isNotEmpty) 'tags': tags,
            if (orderId != null) 'orderId': orderId,
          },
        );
        return 'success';
      } on NodeAuthException catch (e) {
        return e.message;
      } catch (e) {
        return 'Avis non envoyé. Vérifiez votre connexion.';
      }
    }

    try {
      final response = await ParseCloudFunction('addComment').execute(
        parameters: {
          'userID': userID,
          'targetType': targetType,
          'targetID': targetID,
          'note': note,
          'commentaire': commentaire,
          'rating': note,
          'content': commentaire,
          'username': username,
          'userImage': userImage,
          if (tags.isNotEmpty) 'tags': tags,
        },
      );
      if (response.success && response.result != null) {
        final result = response.result as Map<String, dynamic>;
        if (result['success'] == true) return 'success';
        return result['error']?.toString() ?? 'Erreur inconnue';
      }
      return "Erreur cloud: ${response.error?.message}";
    } catch (e) {
      return "Exception: $e";
    }
  }

  static Future<List<CommentData>> getCommentsByTarget({
    required int targetType,
    required int targetID,
    int limit = 5,
    int skip = 0,
  }) async {
    if (await SessionService.hasNodeSession()) {
      try {
        final response = await NodeAuthService.getJson(
          '/reviews',
          queryParameters: {
            ..._target(targetType, targetID),
            'limit': '$limit',
            'skip': '$skip',
          },
        );
        final data = response['data'];
        if (data is List) {
          return data
              .whereType<Map>()
              .map((m) => CommentData.fromMap(Map<String, dynamic>.from(m)))
              .toList();
        }
      } catch (_) {}
      return [];
    }

    try {
      final response = await ParseCloudFunction('getCommentsByTarget').execute(
        parameters: {
          'targetType': targetType,
          'targetID': targetID,
          'limit': limit,
          'skip': skip,
        },
      );
      if (response.success && response.result != null) {
        final List<dynamic> dataList = response.result;
        return dataList
            .map((data) => CommentData.fromMap(data as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<int> getCommentCount({
    required int targetType,
    required int targetID,
  }) async {
    if (await SessionService.hasNodeSession()) {
      try {
        final response = await NodeAuthService.getJson(
          '/reviews/summary',
          queryParameters: _target(targetType, targetID),
        );
        final data = response['data'];
        if (data is Map) {
          return int.tryParse(data['count']?.toString() ?? '') ?? 0;
        }
      } catch (_) {}
      return 0;
    }

    try {
      final response = await ParseCloudFunction('getCommentCount').execute(
        parameters: {'targetType': targetType, 'targetID': targetID},
      );
      if (response.success && response.result != null) {
        final result = response.result as Map<String, dynamic>;
        return result['count'] ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  /// { note, count, characteristics: [{ tag, pct }] }
  static Future<Map<String, dynamic>> getTargetCharacteristics({
    required int targetType,
    required int targetID,
  }) async {
    if (await SessionService.hasNodeSession()) {
      try {
        final response = await NodeAuthService.getJson(
          '/reviews/summary',
          queryParameters: _target(targetType, targetID),
        );
        final data = response['data'];
        if (data is Map) return Map<String, dynamic>.from(data);
      } catch (_) {}
      return {'note': 0, 'count': 0, 'characteristics': []};
    }

    try {
      final response = await ParseCloudFunction('getTargetCharacteristics')
          .execute(parameters: {'targetType': targetType, 'targetID': targetID});
      if (response.success && response.result != null) {
        return response.result as Map<String, dynamic>;
      }
    } catch (_) {}
    return {'success': true, 'note': 0, 'characteristics': []};
  }
}
