// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'identity.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IdentityAdapter extends TypeAdapter<Identity> {
  @override
  final int typeId = 5;

  @override
  Identity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Identity(
      identityID: fields[0] as int,
      userID: fields[1] as int?,
      piece_identite: fields[2] as String?,
      photo: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Identity obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.identityID)
      ..writeByte(1)
      ..write(obj.userID)
      ..writeByte(2)
      ..write(obj.piece_identite)
      ..writeByte(3)
      ..write(obj.photo);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdentityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
