import 'package:hive/hive.dart';

part 'dispute.g.dart';

@HiveType(typeId: 20)
class Dispute extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int orderId;

  @HiveField(2)
  final String openedBy;

  @HiveField(3)
  final String type; // missing_item | not_delivered | bad_quality | other

  @HiveField(4)
  final String description;

  @HiveField(5)
  final List<String> photoUrls;

  @HiveField(6)
  final String status; // open | resolved_client | resolved_restaurant | resolved_driver | rejected

  @HiveField(7)
  final String? resolvedBy;

  @HiveField(8)
  final String? resolutionNotes;

  @HiveField(9)
  final double refundAmount;

  @HiveField(10)
  final DateTime createdAt;

  @HiveField(11)
  final DateTime? resolvedAt;

  Dispute({
    required this.id,
    required this.orderId,
    required this.openedBy,
    required this.type,
    required this.description,
    required this.photoUrls,
    required this.status,
    this.resolvedBy,
    this.resolutionNotes,
    this.refundAmount = 0,
    required this.createdAt,
    this.resolvedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'openedBy': openedBy,
      'type': type,
      'description': description,
      'photoUrls': photoUrls,
      'status': status,
      'resolvedBy': resolvedBy,
      'resolutionNotes': resolutionNotes,
      'refundAmount': refundAmount,
      'createdAt': createdAt.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
    };
  }

  factory Dispute.fromMap(Map<String, dynamic> map) {
    return Dispute(
      id: map['id']?.toString() ?? '',
      orderId: int.tryParse(map['orderId']?.toString() ?? '0') ?? 0,
      openedBy: map['openedBy']?.toString() ?? '',
      type: map['type']?.toString() ?? 'other',
      description: map['description']?.toString() ?? '',
      photoUrls: (map['photoUrls'] as List?)?.map((e) => e.toString()).toList() ?? [],
      status: map['status']?.toString() ?? 'open',
      resolvedBy: map['resolvedBy']?.toString(),
      resolutionNotes: map['resolutionNotes']?.toString(),
      refundAmount: (map['refundAmount'] as num?)?.toDouble() ?? 0,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is String
              ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
              : (map['createdAt']['iso'] != null
                  ? DateTime.tryParse(map['createdAt']['iso']) ?? DateTime.now()
                  : DateTime.now()))
          : DateTime.now(),
      resolvedAt: map['resolvedAt'] != null
          ? (map['resolvedAt'] is String
              ? DateTime.tryParse(map['resolvedAt'])
              : (map['resolvedAt']['iso'] != null
                  ? DateTime.tryParse(map['resolvedAt']['iso'])
                  : null))
          : null,
    );
  }
}

@HiveType(typeId: 21)
class UserDisputeScore extends HiveObject {
  @HiveField(0)
  final String userId;

  @HiveField(1)
  int disputes30d;

  @HiveField(2)
  int disputes90d;

  @HiveField(3)
  final DateTime lastUpdated;

  UserDisputeScore({
    required this.userId,
    this.disputes30d = 0,
    this.disputes90d = 0,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'disputes30d': disputes30d,
      'disputes90d': disputes90d,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory UserDisputeScore.fromMap(Map<String, dynamic> map) {
    return UserDisputeScore(
      userId: map['userId']?.toString() ?? '',
      disputes30d: map['disputes30d'] as int? ?? 0,
      disputes90d: map['disputes90d'] as int? ?? 0,
      lastUpdated: map['lastUpdated'] != null
          ? (map['lastUpdated'] is String
              ? DateTime.tryParse(map['lastUpdated']) ?? DateTime.now()
              : (map['lastUpdated']['iso'] != null
                  ? DateTime.tryParse(map['lastUpdated']['iso']) ?? DateTime.now()
                  : DateTime.now()))
          : DateTime.now(),
    );
  }
}