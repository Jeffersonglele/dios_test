import 'package:hive/hive.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import '../db/database_helper.dart';

part 'commande.g.dart';

@HiveType(typeId: 7)
class Commande extends HiveObject {
  @HiveField(0)
  final int commandeID;

  @HiveField(1)
  int userID;

  @HiveField(2)
  int restauID;

  @HiveField(3)
  int restaurateurID;

  @HiveField(4)
  int moyenPaiementID;

  @HiveField(5)
  double fraisLivraison;

  @HiveField(6)
  double reduction;

  @HiveField(7)
  DateTime dateCommande;

  @HiveField(8)
  String heure;

  @HiveField(9)
  int? addressID;

  @HiveField(10)
  double? note;

  Commande({
    required this.commandeID,
    required this.userID,
    required this.restauID,
    required this.restaurateurID,
    required this.moyenPaiementID,
    required this.fraisLivraison,
    required this.reduction,
    required this.dateCommande,
    required this.heure,
    this.addressID,
    this.note,
  });

  factory Commande.fromMap(Map<String, dynamic> map) {
    return Commande(
      commandeID: map['commandeID'],
      userID: map['userID'],
      restauID: map['restauID'],
      restaurateurID: map['restaurateurID'],
      moyenPaiementID: map['moyenPaiementID'],
      fraisLivraison: map['fraisLivraison']?.toDouble() ?? 0.0,
      reduction: map['reduction']?.toDouble() ?? 0.0,
      dateCommande: DateTime.parse(map['dateCommande']),
      heure: map['heure'],
      addressID: map['addressID'],
      note: map['note']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'commandeID': commandeID,
    'userID': userID,
    'restauID': restauID,
    'restaurateurID': restaurateurID,
    'moyenPaiementID': moyenPaiementID,
    'fraisLivraison': fraisLivraison,
    'reduction': reduction,
    'dateCommande': dateCommande.toIso8601String(),
    'heure': heure,
    'addressID': addressID,
    'note': note,
  };


  static Future<String> manageCommande({
    int? commandeID,
    required int userID,
    required int restauID,
    required int restaurateurID,
    required int moyenPaiementID,
    required double fraisLivraison,
    required double reduction,
    required DateTime dateCommande,
    required String heure,
    int? addressID,
    double? note,
  }) async {
    final functionName = commandeID == null ? 'add1Commande' : 'updateCommande'; // Tu peux créer updateCommande plus tard si besoin
    final cloudFunction = ParseCloudFunction(functionName);

    final params = {
      if (commandeID != null) 'commandeID': commandeID,
      'userID': userID,
      'restauID': restauID,
      'restaurateurID': restaurateurID,
      'moyenPaiementID': moyenPaiementID,
      'fraisLivraison': fraisLivraison,
      'reduction': reduction,
      'dateCommande': dateCommande.toIso8601String(),
      'heure': heure,
      if (addressID != null) 'addressID': addressID,
      if (note != null) 'note': note,
    };

    try {
      final response = await cloudFunction.execute(parameters: params);
      if (response.success && response.result != null) {
        final result = response.result as Map<String, dynamic>;
        final int id = commandeID ?? result['commandeID'];

        final commande = Commande(
          commandeID: id,
          userID: userID,
          restauID: restauID,
          restaurateurID: restaurateurID,
          moyenPaiementID: moyenPaiementID,
          fraisLivraison: fraisLivraison,
          reduction: reduction,
          dateCommande: dateCommande,
          heure: heure,
          addressID: addressID,
          note: note,
        );

        await DatabaseHelper.createCommande(commande);
        return "success";
      } else {
        return "Erreur cloud : ${response.error?.message}";
      }
    } catch (e) {
      return "Exception : $e";
    }
  }

  static Future<bool> getAllCommandes() async {
    final cloudFunction = ParseCloudFunction('getAllCommandes');

    try {
      final response = await cloudFunction.execute();

      if (response.success) {
        List<dynamic> dataList = response.result;
        List<Commande> commandes = dataList
            .map((map) => Commande.fromMap(map))
            .toList();

        final box = await Hive.openBox<Commande>('commande');
        await box.clear();

        for (var commande in commandes) {
          await DatabaseHelper.createCommande(commande);
        }

        return true;
      } else {
        print("Erreur: ${response.error?.message}");
        return false;
      }
    } catch (e) {
      print("Exception: $e");
      return false;
    }

  }

  static Future<List<Commande>> fetchCommandesFromDB() async {
    List<Commande> list = await DatabaseHelper.readAllCommandes();
    print("fetchCommandesFromDB → ${list.length} éléments");
    return list;
  }

}
