// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pro_document.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProDocumentAdapter extends TypeAdapter<ProDocument> {
  @override
  final int typeId = 15;

  @override
  ProDocument read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProDocument(
      documentID: fields[0] as int,
      userID: fields[1] as int,
      restaurantID: fields[2] as int,
      siretUrl: fields[3] as String,
      kbisUrl: fields[4] as String,
      pieceIdentiteUrl: fields[5] as String,
      status: fields[6] as String,
      remark: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ProDocument obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.documentID)
      ..writeByte(1)
      ..write(obj.userID)
      ..writeByte(2)
      ..write(obj.restaurantID)
      ..writeByte(3)
      ..write(obj.siretUrl)
      ..writeByte(4)
      ..write(obj.kbisUrl)
      ..writeByte(5)
      ..write(obj.pieceIdentiteUrl)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.remark);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProDocumentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
