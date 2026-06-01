import 'package:dios_delices/core/app_role.dart';
import 'package:dios_delices/core/commande_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRole', () {
    test('fromId returns correct role', () {
      expect(AppRole.fromId(1), AppRole.admin);
      expect(AppRole.fromId(2), AppRole.individual);
      expect(AppRole.fromId(3), AppRole.microRestaurant);
      expect(AppRole.fromId(4), AppRole.superAdmin);
      expect(AppRole.fromId(5), AppRole.livreur);
      expect(AppRole.fromId(0), AppRole.unknown);
      expect(AppRole.fromId(99), AppRole.unknown);
      expect(AppRole.fromId(null), AppRole.unknown);
    });

    test('isAdmin detects admin roles', () {
      expect(AppRole.admin.isAdmin, true);
      expect(AppRole.superAdmin.isAdmin, true);
      expect(AppRole.individual.isAdmin, false);
      expect(AppRole.microRestaurant.isAdmin, false);
      expect(AppRole.livreur.isAdmin, false);
    });

    test('isProfessional detects restaurateur', () {
      expect(AppRole.microRestaurant.isProfessional, true);
      expect(AppRole.admin.isProfessional, false);
      expect(AppRole.individual.isProfessional, false);
    });

    test('role IDs match enum id', () {
      expect(AppRole.admin.id, 1);
      expect(AppRole.individual.id, 2);
      expect(AppRole.microRestaurant.id, 3);
      expect(AppRole.superAdmin.id, 4);
      expect(AppRole.livreur.id, 5);
      expect(AppRole.unknown.id, 0);
    });
  });

  group('CommandeStatus', () {
    test('normalize maps to standard statuses', () {
      expect(CommandeStatus.normalize('En attente'), CommandeStatus.pending);
      expect(CommandeStatus.normalize('Payée'), 'Payée');
      expect(CommandeStatus.normalize('Confirmée'), CommandeStatus.confirmed);
      expect(CommandeStatus.normalize('Annulée'), CommandeStatus.cancelled);
      expect(CommandeStatus.normalize('Livrée'), 'Livrée');
      expect(CommandeStatus.normalize(''), CommandeStatus.pending);
      expect(CommandeStatus.normalize(null), CommandeStatus.pending);
    });

    test('isPending detects pending', () {
      expect(CommandeStatus.isPending('En attente'), true);
      expect(CommandeStatus.isPending('Payée'), false);
      expect(CommandeStatus.isPending('Confirmée'), false);
    });
  });
}
