// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moyen_paiement.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MoyenPaiementAdapter extends TypeAdapter<MoyenPaiement> {
  @override
  final int typeId = 6;

  @override
  MoyenPaiement read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MoyenPaiement(
      idMoyen: fields[0] as int,
      nom: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, MoyenPaiement obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.idMoyen)
      ..writeByte(1)
      ..write(obj.nom);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoyenPaiementAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
