import 'package:hive/hive.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import '../core/commande_status.dart';
import '../db/database_helper.dart';
import '../services/node_order_service.dart';
import '../services/session_service.dart';
import 'ligne_commande.dart';

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

  // Backend UUID field (required for Node.js API calls)
  @HiveField(21)
  String? orderUuid;

  // Earnings calculated by Parse when the delivery is completed.
  double? delivererBasePay;
  double? delivererDistancePay;
  String? delivererEarningsStatus;

  /// Fournisseur de paiement renvoyé par le backend
  /// (awaiting_payment, confirmed_cash, wallet…) — voir paymentProviderLabel().
  String? paymentProvider;

  /// Code de remise (OTP, 4 caractères). Le backend ne doit le renvoyer
  /// qu'au CLIENT propriétaire de la commande.
  String? retrievalOtp;

  /// `true` une fois le code validé (remise au client / retrait confirmé).
  bool isOtpVerified;

  /// Date de livraison effective (fenêtre de litige de 60 minutes).
  DateTime? deliveredAt;

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
    this.orderUuid,
    this.delivererBasePay,
    this.delivererDistancePay,
    this.delivererEarningsStatus,
    this.paymentProvider,
    this.retrievalOtp,
    this.isOtpVerified = false,
    this.deliveredAt,
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
      orderUuid: map['orderUuid']?.toString() ?? map['uuid']?.toString() ?? map['id']?.toString(),
      dateCommande: DateTime.parse(map['dateCommande']),
      heure: map['heure'],
      addressID: map['addressID'],
      note: map['note']?.toDouble(),
      status: CommandeStatus.normalize(map['status']?.toString()),
      livreurID: map['livreurID'] is int
          ? map['livreurID']
          : int.tryParse(map['livreurID']?.toString() ?? ''),
      deliveryStatus: map['deliveryStatus'] == null ||
              map['deliveryStatus'].toString().trim().isEmpty
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
      delivererBasePay: (map['delivererBasePay'] as num?)?.toDouble(),
      delivererDistancePay: (map['delivererDistancePay'] as num?)?.toDouble(),
      delivererEarningsStatus: map['delivererEarningsStatus']?.toString(),
      paymentProvider: map['paymentProvider']?.toString(),
      retrievalOtp: map['retrievalOtp']?.toString(),
      isOtpVerified: map['isOtpVerified'] == true,
      deliveredAt: map['deliveredAt'] == null
          ? null
          : DateTime.tryParse(map['deliveredAt'].toString()),
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
        'orderUuid': orderUuid,
        'delivererBasePay': delivererBasePay,
        'delivererDistancePay': delivererDistancePay,
        'delivererEarningsStatus': delivererEarningsStatus,
        'paymentProvider': paymentProvider,
        'retrievalOtp': retrievalOtp,
        'isOtpVerified': isOtpVerified,
        'deliveredAt': deliveredAt?.toIso8601String(),
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
    final nodeToken = await SessionService.readNodeToken();
    if (nodeToken != null) {
      final session = await SessionService.readSession();
      final userOrders = await NodeOrderService.listMine(
        token: nodeToken,
        userId: session.userId,
        includeLines: true,
      );
      final isRestaurantOwner =
          session.role.isProfessional || session.restaurantId != null;
      final restaurantOrders = isRestaurantOwner
          ? await NodeOrderService.listForRestaurant(
              token: nodeToken,
              restaurateurId: session.userId,
              restaurantId: session.restaurantId,
              includeLines: true,
            )
          : const <Map<String, dynamic>>[];
      final isDeliverer = session.role.isDelivery;
      final delivererOrders = isDeliverer
          ? await NodeOrderService.listForDeliverer(
              token: nodeToken,
              delivererId: session.userId,
              includeLines: true,
            )
          : const <Map<String, dynamic>>[];
      final orders = NodeOrderService.mergeOrders(
        NodeOrderService.mergeOrders(userOrders, restaurantOrders),
        delivererOrders,
      );
      final box = await Hive.openBox<Commande>('commande');
      await box.clear();
      final ligneBox = await Hive.openBox<LigneCommande>('ligne_commande');
      await ligneBox.clear();
      for (final order in orders) {
        final commande = NodeOrderService.toLegacyCommande(order);
        await DatabaseHelper.createCommande(commande);

        // Synchroniser les lignes de commande depuis le backend Node.js
        final lines = order['lines'] as List<dynamic>?;
        if (lines != null) {
          for (final line in lines) {
            if (line is Map<String, dynamic>) {
              final ligne = LigneCommande(
                ligneID: line['lineId']?.toString() ?? line['id']?.toString() ?? '',
                commandeID: commande.commandeID.toString(),
                platID: int.tryParse(line['dishId']?.toString() ?? '') ?? 0,
                quantite: int.tryParse(line['quantity']?.toString() ?? '') ?? 1,
                prixUnitaire: double.tryParse(line['unitPrice']?.toString() ?? '') ?? 0.0,
                reduction: double.tryParse(line['reduction']?.toString() ?? '') ?? 0.0,
                nomPlat: line['dishName']?.toString(),
              );
              await DatabaseHelper.createLigneCommande(ligne);
            }
          }
        }
      }
      // Recharger les lignes depuis la base locale pour s'assurer qu'elles sont bien stockées
      await LigneCommande.getAllLignesCommande();
      return;
    }
    await getAllCommandes();
  }
}