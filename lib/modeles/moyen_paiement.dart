import 'package:hive/hive.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import '../db/database_helper.dart';

part 'moyen_paiement.g.dart';

@HiveType(typeId: 6)
class MoyenPaiement extends HiveObject {
  @HiveField(0)
  final int idMoyen;

  @HiveField(1)
  String nom;

  MoyenPaiement({
    required this.idMoyen,
    required this.nom,
  });

  factory MoyenPaiement.fromMap(Map<String, dynamic> map) {
    return MoyenPaiement(
      idMoyen: map['idMoyen'] ?? 0,
      nom: map['nom'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'idMoyen': idMoyen,
    'nom': nom,
  };

  static Future<String> manageMoyenPaiement({
    int? idMoyen,
    required String nom,
  }) async {
    String functionName = idMoyen == null ? 'addMoyenPaiement' : 'updateMoyenPaiement';
    final cloudFunction = ParseCloudFunction(functionName);

    final params = <String, dynamic>{
      if (idMoyen != null) 'idMoyen': idMoyen,
      'nom': nom,
    };

    try {
      final response = await cloudFunction.execute(parameters: params);

      if (response.success && response.result != null) {
        final result = response.result as Map<String, dynamic>;

        if (result['success'] == true) {
          final int id = idMoyen ?? result['idMoyen'];

          final moyen = MoyenPaiement(
            idMoyen: id,
            nom: nom,
          );

          await DatabaseHelper.createMoyenPaiement(moyen);
          return "success";
        } else {
          return "Erreur : ${result['error']}";
        }
      } else {
        return "Erreur cloud : ${response.error?.message}";
      }
    } catch (e) {
      return "Exception : $e";
    }
  }

  static Future<bool> getAllMoyensPaiement() async {
    final cloudFunction = ParseCloudFunction('getAllMoyensPaiement');

    try {
      final response = await cloudFunction.execute();

      if (response.success) {
        List<dynamic> dataList = response.result;
        List<MoyenPaiement> moyens = dataList
            .map((map) => MoyenPaiement.fromMap(map))
            .toList();

        final box = await Hive.openBox<MoyenPaiement>('moyen_paiement');
        await box.clear();

        for (var moyen in moyens) {
          await DatabaseHelper.createMoyenPaiement(moyen);
        }

        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  static Future<List<MoyenPaiement>> fetchMoyensPaiementFromDB() async {
    List<MoyenPaiement> list = await DatabaseHelper.readAllMoyensPaiement();
    return list;
  }


}
