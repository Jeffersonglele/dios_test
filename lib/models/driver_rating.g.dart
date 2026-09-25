// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'driver_rating.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

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
