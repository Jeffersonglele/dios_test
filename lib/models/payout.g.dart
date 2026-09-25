// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payout.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PayoutAdapter extends TypeAdapter<Payout> {
  @override
  final int typeId = 26;

  @override
  Payout read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Payout(
      id: fields[0] as String,
      paiementID: fields[1] as int,
      restaurantID: fields[2] as int,
      restaurateurID: fields[3] as int,
      restaurantName: fields[4] as String,
      weekStart: fields[5] as DateTime,
      weekEnd: fields[6] as DateTime,
      totalOrders: fields[7] as int,
      totalSubtotal: fields[8] as double,
      totalDeliveryFees: fields[9] as double,
      commissionRate: fields[10] as double,
      totalCommission: fields[11] as double,
      netAmount: fields[12] as double,
      payoutMethod: fields[13] as String,
      mobileMoneyPhone: fields[14] as String,
      iban: fields[15] as String,
      status: fields[16] as String,
      payoutRef: fields[17] as String?,
      errorMessage: fields[18] as String?,
      createdAt: fields[19] as DateTime,
      paidAt: fields[20] as DateTime?,
      commissionInvoiceUrl: fields[21] as String?,
      cityID: fields[22] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Payout obj) {
    writer
      ..writeByte(23)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.paiementID)
      ..writeByte(2)
      ..write(obj.restaurantID)
      ..writeByte(3)
      ..write(obj.restaurateurID)
      ..writeByte(4)
      ..write(obj.restaurantName)
      ..writeByte(5)
      ..write(obj.weekStart)
      ..writeByte(6)
      ..write(obj.weekEnd)
      ..writeByte(7)
      ..write(obj.totalOrders)
      ..writeByte(8)
      ..write(obj.totalSubtotal)
      ..writeByte(9)
      ..write(obj.totalDeliveryFees)
      ..writeByte(10)
      ..write(obj.commissionRate)
      ..writeByte(11)
      ..write(obj.totalCommission)
      ..writeByte(12)
      ..write(obj.netAmount)
      ..writeByte(13)
      ..write(obj.payoutMethod)
      ..writeByte(14)
      ..write(obj.mobileMoneyPhone)
      ..writeByte(15)
      ..write(obj.iban)
      ..writeByte(16)
      ..write(obj.status)
      ..writeByte(17)
      ..write(obj.payoutRef)
      ..writeByte(18)
      ..write(obj.errorMessage)
      ..writeByte(19)
      ..write(obj.createdAt)
      ..writeByte(20)
      ..write(obj.paidAt)
      ..writeByte(21)
      ..write(obj.commissionInvoiceUrl)
      ..writeByte(22)
      ..write(obj.cityID);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PayoutAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DriverPayoutAdapter extends TypeAdapter<DriverPayout> {
  @override
  final int typeId = 27;

  @override
  DriverPayout read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DriverPayout(
      id: fields[0] as String,
      paiementID: fields[1] as int,
      livreurID: fields[2] as int,
      livreurName: fields[3] as String,
      weekStart: fields[4] as DateTime,
      weekEnd: fields[5] as DateTime,
      totalDeliveries: fields[6] as int,
      totalBasePay: fields[7] as double,
      totalDistancePay: fields[8] as double,
      totalTips: fields[9] as double,
      netAmount: fields[10] as double,
      status: fields[11] as String,
      payoutMethod: fields[12] as String,
      mobileMoneyPhone: fields[13] as String,
      payoutRef: fields[14] as String?,
      errorMessage: fields[15] as String?,
      createdAt: fields[16] as DateTime,
      paidAt: fields[17] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, DriverPayout obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.paiementID)
      ..writeByte(2)
      ..write(obj.livreurID)
      ..writeByte(3)
      ..write(obj.livreurName)
      ..writeByte(4)
      ..write(obj.weekStart)
      ..writeByte(5)
      ..write(obj.weekEnd)
      ..writeByte(6)
      ..write(obj.totalDeliveries)
      ..writeByte(7)
      ..write(obj.totalBasePay)
      ..writeByte(8)
      ..write(obj.totalDistancePay)
      ..writeByte(9)
      ..write(obj.totalTips)
      ..writeByte(10)
      ..write(obj.netAmount)
      ..writeByte(11)
      ..write(obj.status)
      ..writeByte(12)
      ..write(obj.payoutMethod)
      ..writeByte(13)
      ..write(obj.mobileMoneyPhone)
      ..writeByte(14)
      ..write(obj.payoutRef)
      ..writeByte(15)
      ..write(obj.errorMessage)
      ..writeByte(16)
      ..write(obj.createdAt)
      ..writeByte(17)
      ..write(obj.paidAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DriverPayoutAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
