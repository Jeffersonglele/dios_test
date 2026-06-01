import 'package:flutter/foundation.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../modeles/users.dart';

/// Seed des utilisateurs dans les DEUX tables :
/// 1. _User (Parse auth native) pour l'authentification
/// 2. Users (table custom) pour les données métier, avec mot de passe chiffré GPassword
///
/// Nécessite "Allow new users to sign up" activé dans Back4App.
class DatabaseSeeder {
  const DatabaseSeeder._();

  static Future<bool> shouldSeed() async {
    try {
      final query = QueryBuilder<ParseObject>(ParseObject('Users'));
      query.setLimit(1);
      final r = await query.query();
      return r.results == null || r.results!.isEmpty;
    } catch (_) {
      return true;
    }
  }

  static Future<void> seed() async {
    debugPrint('🌱 Seeding database...');

    for (final u in _users) {
      await _createUser(u);
    }

    debugPrint('🌱 Seed terminé.');
  }

  static Future<void> _createUser(_SeedUser u) async {
    final parseUser = ParseUser(u.username, u.password, u.email);

    // Essai 1 : signUp (nécessite "Allow new users to sign up" dans Back4App)
    var signUpResp = await parseUser.signUp();
    if (!signUpResp.success) {
      if (signUpResp.error?.code == 202) {
        // Déjà créé (via script REST ou manuellement)
        debugPrint('  ⚡ ${u.username} existe déjà dans _User');
      } else {
        debugPrint('  ⚠️ ${u.username} signUp impossible, essai login...');
        // Essai 2 : si l'utilisateur existe déjà (créé via REST/manuellement), on se connecte
        final loginResp = await parseUser.login();
        if (!loginResp.success) {
          debugPrint('  ❌ ${u.username} login aussi échoué. Vérifie Back4App.');
          return;
        }
        debugPrint('  🔑 ${u.username} connecté');
      }
    } else {
      debugPrint('  ✅ ${u.username} _User créé');
    }

    // Maintenant authentifié → on crée l'enregistrement dans la table custom Users
    await _createUsersClassRecord(u);
  }

  static Future<void> _createUsersClassRecord(_SeedUser u) async {
    try {
      final passwordCrypte = await Users.encryptPassword(u.password);

      final obj = ParseObject('Users')
        ..set('username', u.username)
        ..set('password', passwordCrypte)
        ..set('roleID', u.roleID)
        ..set('firstname', u.firstname)
        ..set('lastname', u.lastname)
        ..set('email', u.email)
        ..set('telephone', 0)
        ..set('country', u.country)
        ..set('status', 'Verified')
        ..set('identity', 'Verified');

      final resp = await obj.save();
      if (resp.success) {
        debugPrint('  ✅ ${u.username} Users table');
      } else {
        debugPrint('  ❌ ${u.username} Users: ${resp.error?.message}');
      }
    } catch (e) {
      debugPrint('  ❌ ${u.username} Users: $e');
    }
  }

  static const _users = [
    _SeedUser('admin', 'admin123', 1, 'Admin', 'Dios', 'admin@diosdelices.com', 'France'),
    _SeedUser('awa.cuisine', 'awa123', 4, 'Awa', 'Cuisine', 'awa@cuisine.com', "Côte d'Ivoire"),
    _SeedUser('lea.gourmande', 'lea123', 2, 'Léa', 'Gourmande', 'lea@gourmande.com', 'France'),
  ];
}

class _SeedUser {
  final String username, password, firstname, lastname, email, country;
  final int roleID;
  const _SeedUser(this.username, this.password, this.roleID,
      this.firstname, this.lastname, this.email, this.country);
}
