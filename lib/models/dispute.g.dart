// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dispute.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DisputeAdapter extends TypeAdapter<Dispute> {
  @override
  final int typeId = 20;

  @override
  Dispute read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Dispute(
      id: fields[0] as String,
      orderId: fields[1] as int,
      openedBy: fields[2] as String,
      type: fields[3] as String,
      description: fields[4] as String,
      photoUrls: (fields[5] as List).cast<String>(),
      status: fields[6] as String,
      resolvedBy: fields[7] as String?,
      resolutionNotes: fields[8] as String?,
      refundAmount: fields[9] as double,
      createdAt: fields[10] as DateTime,
      resolvedAt: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Dispute obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.orderId)
      ..writeByte(2)
      ..write(obj.openedBy)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.photoUrls)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.resolvedBy)
      ..writeByte(8)
      ..write(obj.resolutionNotes)
      ..writeByte(9)
      ..write(obj.refundAmount)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.resolvedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DisputeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UserDisputeScoreAdapter extends TypeAdapter<UserDisputeScore> {
  @override
  final int typeId = 21;

  @override
  UserDisputeScore read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserDisputeScore(
      userId: fields[0] as String,
      disputes30d: fields[1] as int,
      disputes90d: fields[2] as int,
      lastUpdated: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, UserDisputeScore obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.disputes30d)
      ..writeByte(2)
      ..write(obj.disputes90d)
      ..writeByte(3)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserDisputeScoreAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
