import 'package:dios_delices/models/ligne_commande.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepte les champs historiques et ignore un champ canonique nul', () {
    final ligne = LigneCommande.fromMap({
      'ligneID': '12',
      'commandeID': '4',
      'platID': 0,
      'id_plat': 27,
      'quantite': 2,
      'prixUnitaire': 0,
      'prix_unitaire': 3500,
      'nom_plat': 'Poulet braisé',
    });

    expect(ligne.platID, 27);
    expect(ligne.prixUnitaire, 3500);
    expect(ligne.nomPlat, 'Poulet braisé');
  });
}
