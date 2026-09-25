// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exchange_rate.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExchangeRateAdapter extends TypeAdapter<ExchangeRate> {
  @override
  final int typeId = 24;

  @override
  ExchangeRate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExchangeRate(
      fromCurrency: fields[0] as String,
      toCurrency: fields[1] as String,
      rate: fields[2] as double,
      source: fields[3] as String,
      effectiveDate: fields[4] as DateTime,
      setBy: fields[5] as String,
      isFallback: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ExchangeRate obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.fromCurrency)
      ..writeByte(1)
      ..write(obj.toCurrency)
      ..writeByte(2)
      ..write(obj.rate)
      ..writeByte(3)
      ..write(obj.source)
      ..writeByte(4)
      ..write(obj.effectiveDate)
      ..writeByte(5)
      ..write(obj.setBy)
      ..writeByte(6)
      ..write(obj.isFallback);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExchangeRateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DriverRatingAdapter extends TypeAdapter<DriverRating> {
  @override
  final int typeId = 25;

  @override
  DriverRating read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DriverRating(
      id: fields[0] as String,
      orderId: fields[1] as int,
      driverId: fields[2] as int,
      clientId: fields[3] as int,
      score: fields[4] as int,
      comment: fields[5] as String?,
      createdAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, DriverRating obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.orderId)
      ..writeByte(2)
      ..write(obj.driverId)
      ..writeByte(3)
      ..write(obj.clientId)
      ..writeByte(4)
      ..write(obj.score)
      ..writeByte(5)
      ..write(obj.comment)
      ..writeByte(6)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DriverRatingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
