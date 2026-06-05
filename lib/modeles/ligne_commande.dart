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

  LigneCommande({
    required this.ligneID,
    required this.commandeID,
    required this.platID,
    required this.quantite,
    required this.prixUnitaire,
    required this.reduction,
  });

  factory LigneCommande.fromMap(Map<String, dynamic> map) {
    return LigneCommande(
      ligneID: map['ligneID'],
      commandeID: map['commandeID'],
      platID: map['platID'],
      quantite: map['quantite'],
      prixUnitaire: map['prixUnitaire']?.toDouble() ?? 0.0,
      reduction: map['reduction']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'ligneID': ligneID,
    'commandeID': commandeID,
    'platID': platID,
    'quantite': quantite,
    'prixUnitaire': prixUnitaire,
    'reduction': reduction,
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
