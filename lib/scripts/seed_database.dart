import 'dart:convert';
import 'dart:io';

/// Script de seed standalone — NE JAMAIS inclure dans l'app.
///
/// Usage:
///   export BACK4APP_MASTER_KEY="V7q8jX..."
///   dart run lib/scripts/seed_database.dart
///
/// Ce script :
///   1. Crée les classes Parse manquantes
///   2. Crée les comptes utilisateurs (_User + Users)
///   3. Supprime tous les anciens utilisateurs seed si demandé

const appId = '9qBeGGwSGOQ1iWOJ1UNUXt40NhgwwgbHJYGpV1zg';
const serverUrl = 'https://parseapi.back4app.com';

void main() async {
  final masterKey = Platform.environment['BACK4APP_MASTER_KEY'];
  if (masterKey == null || masterKey.isEmpty) {
    stderr.writeln('❌ BACK4APP_MASTER_KEY non définie.');
    stderr.writeln('   export BACK4APP_MASTER_KEY="ta_master_key"');
    exit(1);
  }

  final client = HttpClient();

  await _deleteSeedUsers(client, masterKey);

  final classes = [
    {'name': 'Users', 'fields': {'username': 'String', 'password': 'String', 'roleID': 'Number', 'firstname': 'String', 'lastname': 'String', 'email': 'String', 'telephone': 'Number', 'country': 'String', 'status': 'String', 'identity': 'String', 'addressID': 'Number', 'isOnline': 'Boolean'}},
    {'name': 'Restaurant', 'fields': {'restaurantID': 'Number', 'userID': 'Number', 'name': 'String', 'description': 'String', 'location': 'String', 'categories': 'String', 'note': 'Number', 'nb_orders': 'Number', 'image': 'String', 'valid': 'Number', 'isOpen': 'Number', 'openingHours': 'String', 'deliveryFee': 'Number', 'date_creation': 'Date'}},
    {'name': 'Dish', 'fields': {'dishID': 'Number', 'restauID': 'Number', 'name': 'String', 'description': 'String', 'price': 'Number', 'categories': 'String', 'nb_servings': 'Number', 'nb_orders': 'Number', 'status': 'Number', 'image': 'String'}},
    {'name': 'Commande', 'fields': {'commandeID': 'Number', 'userID': 'Number', 'restauID': 'Number', 'restaurateurID': 'Number', 'livreurID': 'Number', 'status': 'String', 'deliveryStatus': 'String', 'totalAmount': 'Number', 'fraisLivraison': 'Number', 'reduction': 'Number', 'currency': 'String', 'dateCommande': 'Date', 'heure': 'String', 'livreurLat': 'Number', 'livreurLng': 'Number', 'code_promo': 'String', 'id_adresse_livraison': 'Number', 'moyenPaiementID': 'Number'}},
    {'name': 'LigneCommande', 'fields': {'commandeID': 'String', 'platID': 'Number', 'quantite': 'Number', 'prixUnitaire': 'Number', 'reduction': 'Number', 'fraisLivraison': 'Number', 'moyen_paiement_id': 'Number', 'id_adresse_livraison': 'Number'}},
    {'name': 'Address', 'fields': {'addressID': 'Number', 'object': 'String', 'objectID': 'Number', 'city': 'String', 'state': 'String', 'fullAddress': 'String', 'numero': 'Number', 'lat': 'String', 'long': 'String', 'user_roleID': 'Number'}},
    {'name': 'Identity', 'fields': {'identityID': 'Number', 'userID': 'Number', 'type': 'String', 'numero': 'String', 'image': 'String', 'status': 'String'}},
    {'name': 'MoyenPaiement', 'fields': {'userID': 'Number', 'type': 'String', 'details': 'String'}},
    {'name': 'Message', 'fields': {'fromUserID': 'String', 'toUserID': 'String', 'text': 'String', 'fromUsername': 'String'}},
    {'name': 'Comment', 'fields': {'userID': 'Number', 'targetType': 'Number', 'targetID': 'Number', 'note': 'Number', 'commentaire': 'String', 'username': 'String', 'userImage': 'String'}},
    {'name': 'PromoCode', 'fields': {'code': 'String', 'description': 'String', 'discountPercent': 'Number', 'discountFixed': 'Number', 'minOrder': 'Number', 'active': 'Boolean', 'validFrom': 'Date', 'validUntil': 'Date'}},
    {'name': 'VerificationCode', 'fields': {'email': 'String', 'code': 'String', 'expiresAt': 'Date'}},
  ];

  for (final c in classes) {
    try {
      final uri = Uri.parse('$serverUrl/schemas/${c['name']}');
      final request = await client.putUrl(uri);
      request.headers.set('X-Parse-Application-Id', appId);
      request.headers.set('X-Parse-Master-Key', masterKey);
      request.headers.set('Content-Type', 'application/json');
      final body = jsonEncode({
        'className': c['name'],
        'fields': c['fields'],
      });
      request.write(body);
      final response = await request.close();
      final respBody = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200 || response.statusCode == 201) {
      } else if (respBody.contains('already exists') || response.statusCode == 409) {
      } else {
      }
    } catch (e) {
    }
  }

  final users = [
    {'username': 'admin', 'password': 'admin123', 'roleID': 1, 'firstname': 'Admin', 'lastname': 'Dios', 'email': 'admin@diosdelices.com', 'country': 'France'},
    {'username': 'awa.cuisine', 'password': 'awa123', 'roleID': 4, 'firstname': 'Awa', 'lastname': 'Cuisine', 'email': 'awa@cuisine.com', 'country': "Côte d'Ivoire"},
    {'username': 'lea.gourmande', 'password': 'lea123', 'roleID': 2, 'firstname': 'Léa', 'lastname': 'Gourmande', 'email': 'lea@gourmande.com', 'country': 'France'},
  ];

  for (final u in users) {
    await _createUser(client, masterKey, u);
  }

  client.close();
}

Future<void> _deleteSeedUsers(HttpClient client, String masterKey) async {
  // Supprime tous les utilisateurs seed existants
  await _deleteUser(client, masterKey, 'admin');
  await _deleteUser(client, masterKey, 'awa.cuisine');
  await _deleteUser(client, masterKey, 'lea.gourmande');
}

Future<void> _deleteUser(HttpClient client, String masterKey, String username) async {
  try {
    final uri = Uri.parse('$serverUrl/login?username=$username&password=dummy');
    final req = await client.getUrl(uri);
    req.headers.set('X-Parse-Application-Id', appId);
    req.headers.set('X-Parse-Master-Key', masterKey);
    final resp = await req.close();
    if (resp.statusCode == 200) {
      final data = jsonDecode(await resp.transform(utf8.decoder).join());
      final objectId = data['objectId'];
      if (objectId != null) {
        final delUri = Uri.parse('$serverUrl/users/$objectId');
        final delReq = await client.deleteUrl(delUri);
        delReq.headers.set('X-Parse-Application-Id', appId);
        delReq.headers.set('X-Parse-Master-Key', masterKey);
        await delReq.close();
      }
    }
  } catch (_) {}
}

Future<bool> _createUser(HttpClient client, String masterKey, Map<String, dynamic> u) async {
  try {
    // Étape 1 : créer ParseUser (_User)
    final userBody = jsonEncode({
      'username': u['username'],
      'password': u['password'],
      'email': u['email'],
    });
    final userUri = Uri.parse('$serverUrl/users');
    var request = await client.postUrl(userUri);
    request.headers.set('X-Parse-Application-Id', appId);
    request.headers.set('X-Parse-Master-Key', masterKey);
    request.headers.set('Content-Type', 'application/json');
    request.write(userBody);
    var response = await request.close();
    var respBody = await response.transform(utf8.decoder).join();

    if (response.statusCode != 201) {
      // Peut-être déjà existant ? On tente de récupérer l'objectId
      if (response.statusCode == 202 || response.statusCode == 409) {
      } else {
        return false;
      }
    }

    // Étape 2 : créer l'enregistrement Users (table custom)
    final now = DateTime.now().toIso8601String();
    final usersBody = jsonEncode({
      'username': u['username'],
      'password': u['password'],  // L'app compare aussi le plaintext
      'roleID': u['roleID'],
      'firstname': u['firstname'],
      'lastname': u['lastname'],
      'email': u['email'],
      'telephone': 0,
      'country': u['country'],
      'status': 'Verified',
      'identity': 'Verified',
      'addressID': 0,
      'last_login': {'__type': 'Date', 'iso': now},
    });

    final usersUri = Uri.parse('$serverUrl/classes/Users');
    request = await client.postUrl(usersUri);
    request.headers.set('X-Parse-Application-Id', appId);
    request.headers.set('X-Parse-Master-Key', masterKey);
    request.headers.set('Content-Type', 'application/json');
    request.write(usersBody);
    response = await request.close();
    respBody = await response.transform(utf8.decoder).join();

    if (response.statusCode == 201) {
      return true;
    } else {
      return false;
    }
  } catch (e) {
    return false;
  }
}
