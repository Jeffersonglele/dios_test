// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurant.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RestaurantAdapter extends TypeAdapter<Restaurant> {
  @override
  final int typeId = 1;

  @override
  Restaurant read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Restaurant(
      restaurantID: fields[0] as int,
      userID: fields[1] as int,
      categories: fields[2] as String,
      description: fields[3] as String,
      adress: fields[4] as String,
      name: fields[5] as String,
      note: fields[6] as double,
      nb_orders: fields[10] as int,
      image: fields[7] as String?,
      valid: fields[9] as int,
      date_creation: fields[8] as DateTime?,
      openingHours: fields[11] as String? ?? '09:00 - 20:00',
      deliveryFee: fields[12] as double? ?? 0.0,
      isOpen: fields[13] as int? ?? 1,
    );
  }

  @override
  void write(BinaryWriter writer, Restaurant obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.restaurantID)
      ..writeByte(1)
      ..write(obj.userID)
      ..writeByte(2)
      ..write(obj.categories)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.adress)
      ..writeByte(5)
      ..write(obj.name)
      ..writeByte(6)
      ..write(obj.note)
      ..writeByte(7)
      ..write(obj.image)
      ..writeByte(8)
      ..write(obj.date_creation)
      ..writeByte(9)
      ..write(obj.valid)
      ..writeByte(10)
      ..write(obj.nb_orders)
      ..writeByte(11)
      ..write(obj.openingHours)
      ..writeByte(12)
      ..write(obj.deliveryFee)
      ..writeByte(13)
      ..write(obj.isOpen);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestaurantAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
