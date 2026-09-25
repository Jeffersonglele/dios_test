import 'package:hive/hive.dart';

part 'driver_rating.g.dart';

@HiveType(typeId: 25)
class DriverRating extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int orderId;

  @HiveField(2)
  final int driverId;

  @HiveField(3)
  final int clientId;

  @HiveField(4)
  final int score; // 1-5

  @HiveField(5)
  final String? comment;

  @HiveField(6)
  final DateTime createdAt;

  DriverRating({
    required this.id,
    required this.orderId,
    required this.driverId,
    required this.clientId,
    required this.score,
    this.comment,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'driverId': driverId,
      'clientId': clientId,
      'score': score,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DriverRating.fromMap(Map<String, dynamic> map) {
    return DriverRating(
      id: map['id']?.toString() ?? '',
      orderId: int.tryParse(map['orderId']?.toString() ?? '0') ?? 0,
      driverId: int.tryParse(map['driverId']?.toString() ?? '0') ?? 0,
      clientId: int.tryParse(map['clientId']?.toString() ?? '0') ?? 0,
      score: map['score'] as int? ?? 0,
      comment: map['comment']?.toString(),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is String
              ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
              : (map['createdAt']['iso'] != null
                  ? DateTime.tryParse(map['createdAt']['iso']) ?? DateTime.now()
                  : DateTime.now()))
          : DateTime.now(),
    );
  }
}