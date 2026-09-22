import 'package:hive/hive.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import '../core/commande_status.dart';
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

  @HiveField(11)
  String status;

  @HiveField(12)
  int? livreurID;

  @HiveField(13)
  String? deliveryStatus;

  @HiveField(14)
  double? livreurLat;

  @HiveField(15)
  double? livreurLng;

  @HiveField(16)
  int cityID;

  // New fields for delivery history
  @HiveField(17)
  double? distance; // in km

  @HiveField(18)
  double? pourboire; // tip

  // Payment/transfer fields
  @HiveField(19)
  String? paymentStatus; // pending, paid, etc.

  @HiveField(20)
  DateTime? paymentDate;

  double totalAmount;
  String? deliveryMode;
  String? promoCode;
  double? subtotalAmount;
  String? country;

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
    this.status = CommandeStatus.pending,
    this.livreurID,
    this.deliveryStatus,
    this.livreurLat,
    this.livreurLng,
    this.totalAmount = 0,
    this.deliveryMode,
    this.promoCode,
    this.subtotalAmount,
    this.cityID = 1,
    this.country,
    this.distance,
    this.pourboire,
    this.paymentStatus,
    this.paymentDate,
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
      status: CommandeStatus.normalize(map['status']?.toString()),
      livreurID: map['livreurID'] is int
          ? map['livreurID']
          : int.tryParse(map['livreurID']?.toString() ?? ''),
      deliveryStatus: map['livreurID'] == null
          ? null
          : DeliveryStatus.normalize(map['deliveryStatus']?.toString()),
      livreurLat: double.tryParse(map['livreurLat']?.toString() ?? ''),
      livreurLng: double.tryParse(map['livreurLng']?.toString() ?? ''),
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      deliveryMode: map['deliveryMode']?.toString(),
      promoCode: map['promoCode']?.toString(),
      subtotalAmount:
          (map['subtotalAmount'] ?? map['totalAmount'] ?? 0)?.toDouble(),
      country: map['country']?.toString(),
      cityID: int.tryParse(map['cityID']?.toString() ?? '1') ?? 1,
      distance: (map['distance'] as num?)?.toDouble(),
      pourboire: (map['pourboire'] as num?)?.toDouble(),
      paymentStatus: map['paymentStatus']?.toString(),
      paymentDate: map['paymentDate'] != null
          ? DateTime.parse(map['paymentDate'])
          : null,
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
        'status': status,
        'livreurID': livreurID,
        'deliveryStatus': deliveryStatus,
        'livreurLat': livreurLat,
        'livreurLng': livreurLng,
        'totalAmount': totalAmount,
        'deliveryMode': deliveryMode,
        'promoCode': promoCode,
        'subtotalAmount': subtotalAmount,
        'country': country,
        'cityID': cityID,
        'distance': distance,
        'pourboire': pourboire,
        'paymentStatus': paymentStatus,
        'paymentDate': paymentDate?.toIso8601String(),
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
    String status = CommandeStatus.pending,
    int cityID = 1,
  }) async {
    final functionName = commandeID == null ? 'add1Commande' : 'updateCommande';
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
      'status': status,
      'cityID': cityID,
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
          status: status,
          cityID: cityID,
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
        List<Commande> commandes =
            dataList.map((map) => Commande.fromMap(map)).toList();

        final box = await Hive.openBox<Commande>('commande');
        await box.clear();

        for (var commande in commandes) {
          await DatabaseHelper.createCommande(commande);
        }

        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  static Future<List<Commande>> fetchCommandesFromDB() async {
    List<Commande> list = await DatabaseHelper.readAllCommandes();
    return list;
  }

  static Future<void> refreshLocalCommandes() async {
    await getAllCommandes();
  }
}
