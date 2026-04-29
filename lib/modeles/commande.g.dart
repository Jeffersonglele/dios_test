// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'commande.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CommandeAdapter extends TypeAdapter<Commande> {
  @override
  final int typeId = 7;

  @override
  Commande read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Commande(
      commandeID: fields[0] as int,
      userID: fields[1] as int,
      restauID: fields[2] as int,
      restaurateurID: fields[3] as int,
      moyenPaiementID: fields[4] as int,
      fraisLivraison: fields[5] as double,
      reduction: fields[6] as double,
      dateCommande: fields[7] as DateTime,
      heure: fields[8] as String,
      addressID: fields[9] as int?,
      note: fields[10] as double?,
      status: fields[11] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Commande obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.commandeID)
      ..writeByte(1)
      ..write(obj.userID)
      ..writeByte(2)
      ..write(obj.restauID)
      ..writeByte(3)
      ..write(obj.restaurateurID)
      ..writeByte(4)
      ..write(obj.moyenPaiementID)
      ..writeByte(5)
      ..write(obj.fraisLivraison)
      ..writeByte(6)
      ..write(obj.reduction)
      ..writeByte(7)
      ..write(obj.dateCommande)
      ..writeByte(8)
      ..write(obj.heure)
      ..writeByte(9)
      ..write(obj.addressID)
      ..writeByte(10)
      ..write(obj.note)
      ..writeByte(11)
      ..write(obj.status);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommandeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
