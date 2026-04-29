import 'dart:convert';

import 'package:http/http.dart' as http;

class CommandeApi {
  const CommandeApi._();

  static Future<void> updateOrderStatus(String commandeId, String status) async {
    final response = await http.put(
      Uri.parse(
        "https://dios-delices-backend.vercel.app/api/update-order-status?id=$commandeId",
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"status": status}),
    );

    if (response.statusCode != 200) {
      throw Exception("Echec mise a jour statut commande");
    }
  }
}
