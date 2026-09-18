import 'package:hive/hive.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import '../db/database_helper.dart';

part 'ligne_commande.g.dart';

@HiveType(typeId: 12)
class LigneCommande extends HiveObject {
  @HiveField(0)
  final String ligneID;

  @HiveField(1)
  String commandeID;

  @HiveField(2)
  int platID;

  @HiveField(3)
  int quantite;

  @HiveField(4)
  double prixUnitaire;

  @HiveField(5)
  double reduction;

  /// Nom figé au moment de la commande pour ne pas dépendre du cache des plats.
  @HiveField(6)
  String? nomPlat;

  LigneCommande({
    required this.ligneID,
    required this.commandeID,
    required this.platID,
    required this.quantite,
    required this.prixUnitaire,
    required this.reduction,
    this.nomPlat,
  });

  factory LigneCommande.fromMap(Map<String, dynamic> map) {
    int readInt(List<String> keys, [int fallback = 0]) {
      int? firstValue;
      for (final key in keys) {
        final value = map[key];
        if (value is num) {
          final parsed = value.toInt();
          firstValue ??= parsed;
          if (parsed != 0) return parsed;
          continue;
        }
        final parsed = int.tryParse(value?.toString() ?? '');
        if (parsed != null) {
          firstValue ??= parsed;
          if (parsed != 0) return parsed;
        }
      }
      return firstValue ?? fallback;
    }

    double readDouble(List<String> keys, [double fallback = 0]) {
      double? firstValue;
      for (final key in keys) {
        final value = map[key];
        if (value is num) {
          final parsed = value.toDouble();
          firstValue ??= parsed;
          if (parsed != 0) return parsed;
          continue;
        }
        final parsed = double.tryParse(
            value?.toString().replaceAll(',', '.') ?? '');
        if (parsed != null) {
          firstValue ??= parsed;
          if (parsed != 0) return parsed;
        }
      }
      return firstValue ?? fallback;
    }

    String readString(List<String> keys) {
      for (final key in keys) {
        final value = map[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    return LigneCommande(
      ligneID: readString(['ligneID', 'id_ligne_commande']),
      commandeID: readString(['commandeID', 'id_commande']),
      platID: readInt(['platID', 'id_plat', 'dishId', 'dishID']),
      quantite: readInt(['quantite', 'quantity'], 1),
      prixUnitaire: readDouble(
          ['prixUnitaire', 'prix_unitaire', 'price', 'unitPrice']),
      reduction: readDouble(['reduction', 'discount']),
      nomPlat: readString(['nomPlat', 'nom_plat', 'dishName', 'name'])
          .nullIfEmpty,
    );
  }

  Map<String, dynamic> toJson() => {
    'ligneID': ligneID,
    'commandeID': commandeID,
    'platID': platID,
    'quantite': quantite,
    'prixUnitaire': prixUnitaire,
    'reduction': reduction,
    if (nomPlat != null && nomPlat!.trim().isNotEmpty) 'nomPlat': nomPlat,
  };

  static Future<String> manageLigneCommande({
    String? ligneID,
    required String commandeID,
    required int platID,
    required int quantite,
    required double prixUnitaire,
    required double reduction,
  }) async {
    final functionName = ligneID == null ? 'addLigneCommande' : 'updateLigneCommande'; // À créer si nécessaire
    final cloudFunction = ParseCloudFunction(functionName);

    final params = {
      if (ligneID != null) 'ligneID': ligneID,
      'commandeID': commandeID,
      'platID': platID,
      'quantite': quantite,
      'prixUnitaire': prixUnitaire,
      'reduction': reduction,
    };

    try {
      final response = await cloudFunction.execute(parameters: params);
      if (response.success && response.result != null) {
        final result = response.result as Map<String, dynamic>;
        final String id = ligneID ?? result['ligneID'];

        final ligne = LigneCommande(
          ligneID: id,
          commandeID: commandeID,
          platID: platID,
          quantite: quantite,
          prixUnitaire: prixUnitaire,
          reduction: reduction,
        );

        await DatabaseHelper.createLigneCommande(ligne);
        return "success";
      } else {
        return "Erreur cloud : ${response.error?.message}";
      }
    } catch (e) {
      return "Exception : $e";
    }
  }

  static Future<bool> getAllLignesCommande() async {
    final cloudFunction = ParseCloudFunction('getAllLignesCommande');

    try {
      final response = await cloudFunction.execute();

      if (response.success) {
        List<dynamic> dataList = response.result;
        List<LigneCommande> lignes = dataList
            .map((map) => LigneCommande.fromMap(map))
            .toList();

        final box = await Hive.openBox<LigneCommande>('ligne_commande');
        await box.clear();

        for (var ligne in lignes) {
          await DatabaseHelper.createLigneCommande(ligne);
        }

        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  static Future<List<LigneCommande>> fetchLignesCommandeFromDB() async {
    final box = await Hive.openBox<LigneCommande>('ligne_commande');
    List<LigneCommande> list = box.values.toList();
    return list;
  }

  static Future<List<LigneCommande>> fetchLignesCommandeByCommandeID(int commandeID) async {
    List<LigneCommande> list = await DatabaseHelper.readLignesCommande(commandeID);
    return list;
  }

}

extension on String {
  String? get nullIfEmpty => trim().isEmpty ? null : this;
}
