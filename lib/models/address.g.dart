// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'address.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AddressAdapter extends TypeAdapter<Address> {
  @override
  final int typeId = 4;

  @override
  Address read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Address(
      object: fields[0] as String?,
      numero: fields[2] as int?,
      city: fields[3] as String?,
      state: fields[4] as String?,
      fullAddress: fields[5] as String?,
      lat: fields[6] as String?,
      long: fields[7] as String?,
      objectID: fields[9] as int?,
      addressID: fields[8] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Address obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.object)
      ..writeByte(2)
      ..write(obj.numero)
      ..writeByte(3)
      ..write(obj.city)
      ..writeByte(4)
      ..write(obj.state)
      ..writeByte(5)
      ..write(obj.fullAddress)
      ..writeByte(6)
      ..write(obj.lat)
      ..writeByte(7)
      ..write(obj.long)
      ..writeByte(8)
      ..write(obj.addressID)
      ..writeByte(9)
      ..write(obj.objectID);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddressAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
