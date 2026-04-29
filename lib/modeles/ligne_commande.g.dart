// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ligne_commande.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LigneCommandeAdapter extends TypeAdapter<LigneCommande> {
  @override
  final int typeId = 12;

  @override
  LigneCommande read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LigneCommande(
      ligneID: fields[0] as String,
      commandeID: fields[1] as String,
      platID: fields[2] as int,
      quantite: fields[3] as int,
      prixUnitaire: fields[4] as double,
      reduction: fields[5] as double,
    );
  }

  @override
  void write(BinaryWriter writer, LigneCommande obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.ligneID)
      ..writeByte(1)
      ..write(obj.commandeID)
      ..writeByte(2)
      ..write(obj.platID)
      ..writeByte(3)
      ..write(obj.quantite)
      ..writeByte(4)
      ..write(obj.prixUnitaire)
      ..writeByte(5)
      ..write(obj.reduction);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LigneCommandeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
