// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'users.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UsersAdapter extends TypeAdapter<Users> {
  @override
  final int typeId = 0;

  @override
  Users read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Users(
      userID: fields[0] as int,
      roleID: fields[4] as int,
      email: fields[8] as String,
      firstname: fields[1] as String,
      lastname: fields[2] as String,
      username: fields[3] as String,
      password: fields[5] as String,
      last_login: fields[6] as DateTime?,
      image: fields[7] as String,
      telephone: fields[9] as int,
      country: fields[10] as String,
      status: fields[11] as String,
      identity: fields[12] as String,
      addressID: fields[13] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Users obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.userID)
      ..writeByte(1)
      ..write(obj.firstname)
      ..writeByte(2)
      ..write(obj.lastname)
      ..writeByte(3)
      ..write(obj.username)
      ..writeByte(4)
      ..write(obj.roleID)
      ..writeByte(5)
      ..write(obj.password)
      ..writeByte(6)
      ..write(obj.last_login)
      ..writeByte(7)
      ..write(obj.image)
      ..writeByte(8)
      ..write(obj.email)
      ..writeByte(9)
      ..write(obj.telephone)
      ..writeByte(10)
      ..write(obj.country)
      ..writeByte(11)
      ..write(obj.status)
      ..writeByte(12)
      ..write(obj.identity)
      ..writeByte(13)
      ..write(obj.addressID);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UsersAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
