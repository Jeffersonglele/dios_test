// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dish.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DishAdapter extends TypeAdapter<Dish> {
  @override
  final int typeId = 3;

  @override
  Dish read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Dish(
      dishID: fields[0] as int,
      userID: fields[5] as int,
      categories: fields[2] as String?,
      description: fields[7] as String?,
      option1: fields[12] as String?,
      option2: fields[13] as String?,
      option3: fields[14] as String?,
      name: fields[1] as String?,
      note: fields[11] as double,
      nb_orders: fields[4] as int,
      image: fields[3] as String?,
      price: fields[6] as double?,
      nb_servings: fields[9] as int?,
      restauID: fields[10] as int,
      status: fields[8] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Dish obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.dishID)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.categories)
      ..writeByte(3)
      ..write(obj.image)
      ..writeByte(4)
      ..write(obj.nb_orders)
      ..writeByte(5)
      ..write(obj.userID)
      ..writeByte(6)
      ..write(obj.price)
      ..writeByte(7)
      ..write(obj.description)
      ..writeByte(8)
      ..write(obj.status)
      ..writeByte(9)
      ..write(obj.nb_servings)
      ..writeByte(10)
      ..write(obj.restauID)
      ..writeByte(11)
      ..write(obj.note)
      ..writeByte(12)
      ..write(obj.option1)
      ..writeByte(13)
      ..write(obj.option2)
      ..writeByte(14)
      ..write(obj.option3);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DishAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
