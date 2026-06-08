import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

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

  factory CommentData.fromMap(Map<String, dynamic> map) {
    final rawTags = map['tags'];
    List<String> tags = [];
    if (rawTags is List) {
      tags = rawTags.map((e) => e.toString()).toList();
    }
    return CommentData(
      id: map['objectId']?.toString() ?? '',
      userID: int.tryParse(map['userID']?.toString() ?? '0') ?? 0,
      targetType: int.tryParse(map['targetType']?.toString() ?? '0') ?? 0,
      targetID: int.tryParse(map['targetID']?.toString() ?? '0') ?? 0,
      note: int.tryParse(map['note']?.toString() ?? '0') ?? 0,
      commentaire: map['commentaire']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      userImage: map['userImage']?.toString() ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      tags: tags,
    );
  }
}

class CommentService {
  const CommentService._();

  static Future<String> addComment({
    required int userID,
    required int targetType,
    required int targetID,
    required int note,
    required String commentaire,
    required String username,
    String userImage = '',
    List<String> tags = const [],
  }) async {
    final cloudFunction = ParseCloudFunction('addComment');
    final params = {
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
    };

    try {
      final response = await cloudFunction.execute(parameters: params);
      if (response.success && response.result != null) {
        final result = response.result as Map<String, dynamic>;
        if (result['success'] == true) {
          return "success";
        }
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
    final cloudFunction = ParseCloudFunction('getCommentsByTarget');
    final params = {
      'targetType': targetType,
      'targetID': targetID,
      'limit': limit,
      'skip': skip,
    };

    try {
      final response = await cloudFunction.execute(parameters: params);
      if (response.success && response.result != null) {
        final List<dynamic> dataList = response.result;
        return dataList
            .map((data) => CommentData.fromMap(data as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
    }
    return [];
  }

  static Future<int> getCommentCount({
    required int targetType,
    required int targetID,
  }) async {
    final cloudFunction = ParseCloudFunction('getCommentCount');
    try {
      final response = await cloudFunction.execute(parameters: {
        'targetType': targetType,
        'targetID': targetID,
      });
      if (response.success && response.result != null) {
        final result = response.result as Map<String, dynamic>;
        return result['count'] ?? 0;
      }
    } catch (e) {
    }
    return 0;
  }

  static Future<Map<String, dynamic>> getTargetCharacteristics({
    required int targetType,
    required int targetID,
  }) async {
    final cloudFunction = ParseCloudFunction('getTargetCharacteristics');
    try {
      final response = await cloudFunction.execute(parameters: {
        'targetType': targetType,
        'targetID': targetID,
      });
      if (response.success && response.result != null) {
        return response.result as Map<String, dynamic>;
      }
    } catch (e) {
    }
    return {'success': true, 'note': 0, 'characteristics': []};
  }
}
