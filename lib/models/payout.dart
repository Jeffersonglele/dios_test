import 'package:hive/hive.dart';

part 'payout.g.dart';

@HiveType(typeId: 26)
class Payout extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int paiementID;

  @HiveField(2)
  final int restaurantID;

  @HiveField(3)
  final int restaurateurID;

  @HiveField(4)
  final String restaurantName;

  @HiveField(5)
  final DateTime weekStart;

  @HiveField(6)
  final DateTime weekEnd;

  @HiveField(7)
  final int totalOrders;

  @HiveField(8)
  final double totalSubtotal;

  @HiveField(9)
  final double totalDeliveryFees;

  @HiveField(10)
  final double commissionRate;

  @HiveField(11)
  final double totalCommission;

  @HiveField(12)
  final double netAmount;

  @HiveField(13)
  final String payoutMethod; // mobile_money | bank

  @HiveField(14)
  final String mobileMoneyPhone;

  @HiveField(15)
  final String iban;

  @HiveField(16)
  final String status; // pending | processing | completed | failed

  @HiveField(17)
  final String? payoutRef;

  @HiveField(18)
  final String? errorMessage;

  @HiveField(19)
  final DateTime createdAt;

  @HiveField(20)
  final DateTime? paidAt;

  @HiveField(21)
  final String? commissionInvoiceUrl;

  @HiveField(22)
  final int cityID;

  Payout({
    required this.id,
    required this.paiementID,
    required this.restaurantID,
    required this.restaurateurID,
    required this.restaurantName,
    required this.weekStart,
    required this.weekEnd,
    required this.totalOrders,
    required this.totalSubtotal,
    required this.totalDeliveryFees,
    required this.commissionRate,
    required this.totalCommission,
    required this.netAmount,
    required this.payoutMethod,
    required this.mobileMoneyPhone,
    required this.iban,
    required this.status,
    this.payoutRef,
    this.errorMessage,
    required this.createdAt,
    this.paidAt,
    this.commissionInvoiceUrl,
    required this.cityID,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'paiementID': paiementID,
      'restaurantID': restaurantID,
      'restaurateurID': restaurateurID,
      'restaurantName': restaurantName,
      'weekStart': weekStart.toIso8601String(),
      'weekEnd': weekEnd.toIso8601String(),
      'totalOrders': totalOrders,
      'totalSubtotal': totalSubtotal,
      'totalDeliveryFees': totalDeliveryFees,
      'commissionRate': commissionRate,
      'totalCommission': totalCommission,
      'netAmount': netAmount,
      'payoutMethod': payoutMethod,
      'mobileMoneyPhone': mobileMoneyPhone,
      'iban': iban,
      'status': status,
      'payoutRef': payoutRef,
      'errorMessage': errorMessage,
      'createdAt': createdAt.toIso8601String(),
      'paidAt': paidAt?.toIso8601String(),
      'commissionInvoiceUrl': commissionInvoiceUrl,
      'cityID': cityID,
    };
  }

  factory Payout.fromMap(Map<String, dynamic> map) {
    return Payout(
      id: map['id']?.toString() ?? '',
      paiementID: int.tryParse(map['paiementID']?.toString() ?? '0') ?? 0,
      restaurantID: int.tryParse(map['restaurantID']?.toString() ?? '0') ?? 0,
      restaurateurID: int.tryParse(map['restaurateurID']?.toString() ?? '0') ?? 0,
      restaurantName: map['restaurantName']?.toString() ?? '',
      weekStart: map['weekStart'] != null
          ? (map['weekStart'] is String
              ? DateTime.tryParse(map['weekStart']) ?? DateTime.now()
              : (map['weekStart']['iso'] != null
                  ? DateTime.tryParse(map['weekStart']['iso']) ?? DateTime.now()
                  : DateTime.now()))
          : DateTime.now(),
      weekEnd: map['weekEnd'] != null
          ? (map['weekEnd'] is String
              ? DateTime.tryParse(map['weekEnd']) ?? DateTime.now()
              : (map['weekEnd']['iso'] != null
                  ? DateTime.tryParse(map['weekEnd']['iso']) ?? DateTime.now()
                  : DateTime.now()))
          : DateTime.now(),
      totalOrders: map['totalOrders'] as int? ?? 0,
      totalSubtotal: (map['totalSubtotal'] as num?)?.toDouble() ?? 0,
      totalDeliveryFees: (map['totalDeliveryFees'] as num?)?.toDouble() ?? 0,
      commissionRate: (map['commissionRate'] as num?)?.toDouble() ?? 15,
      totalCommission: (map['totalCommission'] as num?)?.toDouble() ?? 0,
      netAmount: (map['netAmount'] as num?)?.toDouble() ?? 0,
      payoutMethod: map['payoutMethod']?.toString() ?? 'mobile_money',
      mobileMoneyPhone: map['mobileMoneyPhone']?.toString() ?? '',
      iban: map['iban']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      payoutRef: map['payoutRef']?.toString(),
      errorMessage: map['errorMessage']?.toString(),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is String
              ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
              : (map['createdAt']['iso'] != null
                  ? DateTime.tryParse(map['createdAt']['iso']) ?? DateTime.now()
                  : DateTime.now()))
          : DateTime.now(),
      paidAt: map['paidAt'] != null
          ? (map['paidAt'] is String
              ? DateTime.tryParse(map['paidAt'])
              : (map['paidAt']['iso'] != null
                  ? DateTime.tryParse(map['paidAt']['iso'])
                  : null))
          : null,
      commissionInvoiceUrl: map['commissionInvoiceUrl']?.toString(),
      cityID: int.tryParse(map['cityID']?.toString() ?? '1') ?? 1,
    );
  }
}

@HiveType(typeId: 27)
class DriverPayout extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int paiementID;

  @HiveField(2)
  final int livreurID;

  @HiveField(3)
  final String livreurName;

  @HiveField(4)
  final DateTime weekStart;

  @HiveField(5)
  final DateTime weekEnd;

  @HiveField(6)
  final int totalDeliveries;

  @HiveField(7)
  final double totalBasePay;

  @HiveField(8)
  final double totalDistancePay;

  @HiveField(9)
  final double totalTips;

  @HiveField(10)
  final double netAmount;

  @HiveField(11)
  final String status; // pending | processing | completed | failed

  @HiveField(12)
  final String payoutMethod;

  @HiveField(13)
  final String mobileMoneyPhone;

  @HiveField(14)
  final String? payoutRef;

  @HiveField(15)
  final String? errorMessage;

  @HiveField(16)
  final DateTime createdAt;

  @HiveField(17)
  final DateTime? paidAt;

  DriverPayout({
    required this.id,
    required this.paiementID,
    required this.livreurID,
    required this.livreurName,
    required this.weekStart,
    required this.weekEnd,
    required this.totalDeliveries,
    required this.totalBasePay,
    required this.totalDistancePay,
    required this.totalTips,
    required this.netAmount,
    required this.status,
    required this.payoutMethod,
    required this.mobileMoneyPhone,
    this.payoutRef,
    this.errorMessage,
    required this.createdAt,
    this.paidAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'paiementID': paiementID,
      'livreurID': livreurID,
      'livreurName': livreurName,
      'weekStart': weekStart.toIso8601String(),
      'weekEnd': weekEnd.toIso8601String(),
      'totalDeliveries': totalDeliveries,
      'totalBasePay': totalBasePay,
      'totalDistancePay': totalDistancePay,
      'totalTips': totalTips,
      'netAmount': netAmount,
      'status': status,
      'payoutMethod': payoutMethod,
      'mobileMoneyPhone': mobileMoneyPhone,
      'payoutRef': payoutRef,
      'errorMessage': errorMessage,
      'createdAt': createdAt.toIso8601String(),
      'paidAt': paidAt?.toIso8601String(),
    };
  }

  factory DriverPayout.fromMap(Map<String, dynamic> map) {
    return DriverPayout(
      id: map['id']?.toString() ?? '',
      paiementID: int.tryParse(map['paiementID']?.toString() ?? '0') ?? 0,
      livreurID: int.tryParse(map['livreurID']?.toString() ?? '0') ?? 0,
      livreurName: map['livreurName']?.toString() ?? '',
      weekStart: map['weekStart'] != null
          ? (map['weekStart'] is String
              ? DateTime.tryParse(map['weekStart']) ?? DateTime.now()
              : (map['weekStart']['iso'] != null
                  ? DateTime.tryParse(map['weekStart']['iso']) ?? DateTime.now()
                  : DateTime.now()))
          : DateTime.now(),
      weekEnd: map['weekEnd'] != null
          ? (map['weekEnd'] is String
              ? DateTime.tryParse(map['weekEnd']) ?? DateTime.now()
              : (map['weekEnd']['iso'] != null
                  ? DateTime.tryParse(map['weekEnd']['iso']) ?? DateTime.now()
                  : DateTime.now()))
          : DateTime.now(),
      totalDeliveries: map['totalDeliveries'] as int? ?? 0,
      totalBasePay: (map['totalBasePay'] as num?)?.toDouble() ?? 0,
      totalDistancePay: (map['totalDistancePay'] as num?)?.toDouble() ?? 0,
      totalTips: (map['totalTips'] as num?)?.toDouble() ?? 0,
      netAmount: (map['netAmount'] as num?)?.toDouble() ?? 0,
      status: map['status']?.toString() ?? 'pending',
      payoutMethod: map['payoutMethod']?.toString() ?? 'mobile_money',
      mobileMoneyPhone: map['mobileMoneyPhone']?.toString() ?? '',
      payoutRef: map['payoutRef']?.toString(),
      errorMessage: map['errorMessage']?.toString(),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is String
              ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
              : (map['createdAt']['iso'] != null
                  ? DateTime.tryParse(map['createdAt']['iso']) ?? DateTime.now()
                  : DateTime.now()))
          : DateTime.now(),
      paidAt: map['paidAt'] != null
          ? (map['paidAt'] is String
              ? DateTime.tryParse(map['paidAt'])
              : (map['paidAt']['iso'] != null
                  ? DateTime.tryParse(map['paidAt']['iso'])
                  : null))
          : null,
    );
  }
}