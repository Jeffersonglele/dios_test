import 'dart:convert';
import 'package:count_stepper/count_stepper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import '../modeles/restaurant.dart';
import '../modeles/users.dart';
import '../providers/cart_provider.dart';
import '../providers/selected_delivery.dart';
import '../utils/toast.dart';
import 'package:http/http.dart' as http;

import 'order_tracking_page.dart';

class Cart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartStateProvider);
    final cartNotifier = ref.read(cartStateProvider.notifier);

    // Récupérer et gérer l'option sélectionnée via Riverpod
    final selectedOption = "En Livraison";
    //final selectedOption = ref.watch(selectedDeliveryProvider);
    final deliveryNotifier = ref.read(selectedDeliveryProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text('Votre Panier')),
      body: cartItems.isEmpty
          ? Center(
              child: Text(
                "Votre panier est vide",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Détails de la Commande",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    ListView.builder(
                      scrollDirection: Axis.vertical,
                      shrinkWrap: true,
                      itemCount: cartItems.length,
                      itemBuilder: (context, index) {
                        final item = cartItems[index];
                        return Dismissible(
                          key: Key(item['meal']['meal_name']),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            alignment: Alignment.centerRight,
                            child: Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) {
                            cartNotifier.removeFromCart(index);
                            Toast(
                              context,
                              "${item['meal']['meal_name']} supprimé du panier",
                              true,
                            );
                          },
                          child: Card(
                            color: Color.fromARGB(255, 240, 238, 238),
                            margin: EdgeInsets.symmetric(vertical: 10),
                            child: ListTile(
                              leading: Image.network(
                                item["meal"]["image"],
                                fit: BoxFit.cover,
                                width: 50,
                                height: 50,
                              ),
                              title: Text(item["meal"]["meal_name"]),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${item["meal"]["price"].toStringAsFixed(2)} ${item["meal"]["country"] == 'France' ? '€' : 'FCFA'}",
                                  ),
                                  if (item["meal"]["options"] != null && item["meal"]["options"] is Map)
                                    ...item["meal"]["options"].entries.map<Widget>((entry) {
                                      final rawValue = entry.value.toString(); // <- très important
                                      print("Cart option rawValue: $rawValue");

                                      final match = RegExp(r'^(.*?)\s*\(([\d.,]+)\s*(€|FCFA)?\)$').firstMatch(rawValue);

                                      final name = match?.group(1)?.trim() ?? rawValue;
                                      final price = match?.group(2);
                                      final devise = match?.group(3) ?? (item["meal"]["country"] == 'France' ? '€' : 'FCFA');

                                      return Text(
                                        "Option ${int.tryParse(entry.key.toString()) != null ? int.parse(entry.key.toString()) + 1 : entry.key} : $name"
                                            "${price != null ? ' +$price $devise' : ''}",
                                        style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                                      );
                                    }).toList(),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: CountStepper(
                                      iconColor: Colors.black,
                                      defaultValue: item["order"]["quantity"],
                                      max: item["meal"]["number_of_servings"],
                                      min: 1,
                                      onPressed: (value) {
                                        cartNotifier.updateQuantity(
                                            index, value);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          "Options de Livraison : ",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Spacer(),
                        DropdownButton<String>(
                          value: selectedOption,
                          items: [
                            DropdownMenuItem(
                              value: 'En Livraison',
                              child: Text('En Livraison'),
                            ),
                            DropdownMenuItem(
                              value: 'À Emporter',
                              child: Text('À Emporter'),
                            ),
                          ],
                          onChanged: (value) {
                            deliveryNotifier.state = value!;
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Total : ",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          cartItems.isNotEmpty
                              ? cartItems
                              .fold(
                            0.0,
                                (previousValue, item) =>
                            previousValue +
                                (item['meal']['price'] * item['order']['quantity']) +
                                (item['optionPrice'] ?? 0), // Ne pas multiplier
                          )
                              .toStringAsFixed(2) +
                              (cartItems.first["meal"]["country"] == 'France' ? ' €' : ' FCFA')
                              : "0.00",
                          style: TextStyle(fontSize: 20, color: Colors.red),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          textStyle: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        onPressed: cartItems.isNotEmpty
                            ? () {
                                final totalAmount = cartItems.fold(
                                  0.0,
                                  (sum, item) =>
                                      sum +
                                      (item['meal']['price'] *
                                          item['order']['quantity']),
                                );
                                makePayment(context, cartNotifier, totalAmount);
                              }
                            : null,
                        child: const Text('Procéder au paiement'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // Effectuer les paiements pour chaque devise
  Future<void> makePayment(BuildContext context, CartNotifier cartNotifier,
      double totalAmount) async {
    try {
      final List<dynamic> cartItems = cartNotifier.state;

      double totalInEur = cartItems.fold(0.0, (previousValue, item) {
        double itemTotal = item["meal"]["price"] * item["order"]["quantity"];
        if (item["meal"]["country"] != "France") {
          itemTotal /= 655.957; // Convertir FCFA en EUR
        }
        return previousValue + itemTotal;
      });

      int amountInCents = (totalInEur * 100).toInt();

      final response = await http.post(
        Uri.parse('http://localhost:3000/create-payment-intent'),
        body: jsonEncode({
          'amount': amountInCents,
          'currency': 'eur',
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Erreur API paiement : ${response.body}');
      }

      final paymentIntentData = jsonDecode(response.body);

      await stripe.Stripe.instance.initPaymentSheet(
        paymentSheetParameters: stripe.SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentData['clientSecret'],
          merchantDisplayName: 'Votre Boutique',
        ),
      );

      await stripe.Stripe.instance.presentPaymentSheet();

      print("after payment");

      print("cartItems.first['user']['email'] " +
          cartItems.first['user']['email']);

      // Appeler l'API pour générer la facture
      await generateInvoice(
        items: cartItems.map((item) {
          return {
            'email': item['user']['email'],
            'description': item['meal']['meal_name'],
            'price': (item['meal']['price'] * item['order']['quantity']) +
                (item['optionPrice'] ?? 0),
          };
        }).toList(),
      );

      cartNotifier.clearCart();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => OrderConfirmationPage()),
      );
    } catch (e) {
      print('Erreur lors du paiement : $e');
      Toast(context, "Paiement échoué. Veuillez réessayer.", false);
    }
  }

  Future<void> generateInvoice({
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("http://localhost:3000/create-invoice"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'items': items,
        }),
      );

      if (response.statusCode == 200) {
        print("Facture générée avec succès");
        bool emailSent = await _sendEmailToUser(
            valid: true,
            firstname: items.first['user']['email'],
            email: items.first['user']['email'],
            restaurantName: items.first['restaurant']['name']);
        if (emailSent) {
          print("Email envoyé avec succès à ${items.first['user']['email']}");
        } else {
          print("Erreur lors de l'envoi de l'email");
        }
      } else {
        throw Exception(
            "Erreur lors de la génération de la facture : ${response.body}");
      }
    } catch (e) {
      print("Erreur : $e");
    }
  }

  Future<bool> _sendEmailToUser({
    required String email,
    required bool valid,
    required String firstname,
    required String restaurantName,
  }) async {
    String username = 'blandinedupont087@gmail.com';
    String password = 'dtmd pleh ufau vjqd';

    final smtpServer = gmail(username, password);

    String subject = valid
        ? '🎉 Votre commande est validée !'
        : '❌ Erreur lors de votre commande';

    String messageText = valid
        ? 'Bonjour ${firstname},\n\nVotre commande chez "${restaurantName}" a été validée. '
            'Une facture a été générée et envoyée par email.\n\nCordialement,\nL’équipe Dios Délices'
        : 'Bonjour ${firstname},\n\nMalheureusement, votre commande chez "${restaurantName}" n’a pas pu être validée. '
            'Pour plus d’informations, veuillez nous contacter.\n\nCordialement,\nL’équipe Dios Délices';

    final message = Message()
      ..from = Address(username, 'Dios Délices')
      ..recipients.add(email)
      ..subject = subject
      ..text = messageText;

    try {
      await send(message, smtpServer);
      return true;
    } catch (e) {
      print('Erreur lors de l\'envoi de l\'email : $e');
      return false;
    }
  }
}

class OrderConfirmationPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Commande Confirmée')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Votre commande a été passée avec succès !",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.green, // Couleur du cercle
                shape: BoxShape.circle,
              ),
              padding: EdgeInsets.all(8),
              child: Icon(
                Icons.check, // Chevron de succès
                color: Colors.white, // Couleur du chevron
                size: 20, // Taille du chevron
              ),
            ),
            SizedBox(
              width: 10,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                textStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => OrderTrackingPage()),
                );
              },
              child: const Text('Suivre ma commande'),
            ),
          ],
        ),
      ),
    );
  }
}
