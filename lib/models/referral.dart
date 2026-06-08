class Referral {
  final int referralID;
  final int userID;
  final int referredUserID;
  final String code;
  final double discountPercent;
  final DateTime? createdAt;
  final bool used;

  Referral({
    required this.referralID,
    required this.userID,
    required this.referredUserID,
    required this.code,
    this.discountPercent = 10.0,
    this.createdAt,
    this.used = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'referralID': referralID,
      'userID': userID,
      'referredUserID': referredUserID,
      'code': code,
      'discountPercent': discountPercent,
      'createdAt': createdAt?.toIso8601String(),
      'used': used,
    };
  }

  factory Referral.fromMap(Map<String, dynamic> map) {
    return Referral(
      referralID: int.tryParse(map['referralID']?.toString() ?? '0') ?? 0,
      userID: int.tryParse(map['userID']?.toString() ?? '0') ?? 0,
      referredUserID:
          int.tryParse(map['referredUserID']?.toString() ?? '0') ?? 0,
      code: map['code']?.toString() ?? '',
      discountPercent:
          double.tryParse(map['discountPercent']?.toString() ?? '10') ?? 10.0,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'])
          : null,
      used: map['used'] == true || map['used']?.toString() == 'true',
    );
  }
}
