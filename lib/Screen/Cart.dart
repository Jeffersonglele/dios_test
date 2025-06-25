import 'dart:convert';
import 'package:count_stepper/count_stepper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../modeles/restaurant.dart';
import '../modeles/users.dart';
import '../modeles/address.dart' as delivery;
import '../providers/cart_provider.dart';
import '../providers/selected_delivery.dart';
import '../utils/toast.dart';
import 'package:http/http.dart' as http;
import 'order_tracking_page.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

class Cart extends ConsumerStatefulWidget {
  @override
  _CartState createState() => _CartState();
}

class _CartState extends ConsumerState<Cart> {
  @override
  void initState() {
    super.initState();
    loadData();
  }

  delivery.Address? selectedAddress;

  List<delivery.Address> addresses = [];
  List<Map<String, dynamic>> filteredAddresses = [];
  List<Users> users = [];

  int current_userID = 0;
  int current_user_role = 0;

  void loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int userID = prefs.getInt('loggedUserID') ?? 0;

    List<delivery.Address> addressesList = await delivery.Address.fetchAddressesFromDB();

    setState(() {
      addresses = addressesList;
      current_userID = userID;
    });
    await _filterAddresses();
  }

  Future<void> _filterAddresses() async {
    print("_filterAddresses");
    List<Map<String, dynamic>> user_adresses = [];

    for (var a in addresses) {
      if (a.objectID == current_userID &&
          (a.object == "Livraison" || a.object == "User")) {
        user_adresses.add(a.toJson());
        setState(() {
          filteredAddresses = user_adresses;
        });
      }
    }
  }

  Future<void> refreshAddresses() async {
    List<delivery.Address> addressesList =
        await delivery.Address.fetchAddressesFromDB();
    setState(() {
      addresses = addressesList;
    });
    await _filterAddresses();
  }

  double calculateDeliveryFee(delivery.Address? address) {
    if (address == null) return 0.0;

    // Exemple : tarif selon ville
    if (address.city?.toLowerCase() == "paris") {
      return 5.0;
    } else if (address.city?.toLowerCase() == "lyon") {
      return 3.5;
    } else {
      return 7.0; // par défaut
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartStateProvider);
    final cartNotifier = ref.read(cartStateProvider.notifier);

    final selectedOption = ref.watch(selectedDeliveryProvider);
    final deliveryNotifier = ref.read(selectedDeliveryProvider.notifier);

    final allowedOptions = ['En Livraison', 'À Emporter'];

    final safeSelectedOption = allowedOptions.contains(selectedOption)
        ? selectedOption
        : 'À Emporter';

    if (selectedAddress == null) {
      try {
        selectedAddress = addresses.firstWhere(
          (a) => a.object == "User" && a.objectID == current_userID,
        );
      } catch (_) {
        selectedAddress = null; // ou ne rien faire
      }
    }

    double calculateDeliveryFee(delivery.Address? address) {
      if (address == null) return 0.0;
      switch (address.city?.toLowerCase()) {
        case 'paris':
          return 5.0;
        case 'lyon':
          return 3.5;
        default:
          return 7.0;
      }
    }

    double deliveryFee = selectedOption == "En Livraison"
        ? calculateDeliveryFee(selectedAddress)
        : 0.0;

    double cartTotal = cartItems.fold(0.0, (sum, item) {
      double itemTotal = item['meal']['price'] * item['order']['quantity'];
      double optionPrice = item['optionPrice'] ?? 0;
      if (item['meal']['country'] != 'France') {
        itemTotal /= 655.957;
        optionPrice /= 655.957;
      }
      return sum + itemTotal + optionPrice;
    });

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
                                  if (item["meal"]["options"] != null &&
                                      item["meal"]["options"] is Map &&
                                      item["optionDetails"] != null &&
                                      item["optionDetails"] is Map)
                                    ...item["meal"]["options"].entries.map<Widget>((entry) {
                                      final rawValue = entry.value.toString();
                                      final optionIndex = entry.key;

                                      final optionInfo = item["optionDetails"][optionIndex];
                                      final title = optionInfo != null && optionInfo["title"] != null
                                          ? optionInfo["title"]
                                          : "Option ${optionIndex + 1}";

                                      final match = RegExp(r'^(.*?)\s*\(([\d.,]+)\s*(€|FCFA)?\)$')
                                          .firstMatch(rawValue);

                                      final name = match?.group(1)?.trim() ?? rawValue;
                                      final price = match?.group(2);
                                      final devise = match?.group(3) ??
                                          (item["meal"]["country"] == 'France' ? '€' : 'FCFA');

                                      return Text(
                                        "$title : $name${price != null ? ' +$price $devise' : ''}",
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Options de Livraison :",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        if (selectedOption == 'En Livraison') ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Frais de livraison",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Text("$deliveryFee €"),
                            ],
                          ),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            DropdownButton<String>(
                              value: safeSelectedOption,
                              items: [
                                DropdownMenuItem(
                                    value: 'En Livraison',
                                    child: Text('En Livraison')),
                                DropdownMenuItem(
                                    value: 'À Emporter',
                                    child: Text('À Emporter')),
                              ],
                              onChanged: (value) {
                                if (value != null)
                                  deliveryNotifier.state = value;
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    if (selectedOption == 'En Livraison') ...[
                      ElevatedButton.icon(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20)),
                            ),
                            builder: (_) => DeliveryAddressModal(
                              filteredAddresses: filteredAddresses,
                              userId: cartItems.first['user']['user_id'],
                              user_roleID: current_user_role,
                              onRefreshAddresses: refreshAddresses,
                              onAddressSelected: (selected) {
                                setState(() {
                                  selectedAddress = selected;
                                });
                              },
                            ),
                          );
                        },
                        icon: Icon(Icons.location_on),
                        label: Text("Choisir l'adresse de livraison"),
                      ),
                      if (selectedAddress != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            "Adresse sélectionnée : ${selectedAddress!.fullAddress}",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Frais de livraison :",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500)),
                          Text("${deliveryFee.toStringAsFixed(2)} €",
                              style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ],
                    Divider(),
                    SizedBox(height: 20),
                    selectedOption == 'En Livraison'
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Total avec livraison ",
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                (cartItems.isNotEmpty
                                        ? (cartTotal + deliveryFee)
                                            .toStringAsFixed(2)
                                        : "0.00") +
                                    (cartItems.first["meal"]["country"] ==
                                            'France'
                                        ? ' €'
                                        : ' FCFA'),
                                style:
                                TextStyle(fontSize: 20, color: Colors.red),
                              ),
                            ],
                          )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Total sans livraison ",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          (cartItems.isNotEmpty
                              ? (cartTotal)
                              .toStringAsFixed(2)
                              : "0.00") +
                              (cartItems.first["meal"]["country"] ==
                                  'France'
                                  ? ' €'
                                  : ' FCFA'),
                          style:
                          TextStyle(fontSize: 20, color: Colors.red),
                        ),
                      ],
                    ),
                    SizedBox(height: 40),
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
                            ? () async {
                          final totalAmount = cartItems.fold(
                            0.0,
                                (sum, item) {
                              double itemTotal = item['meal']['price'] * item['order']['quantity'];
                              double optionPrice = item['optionPrice'] ?? 0;
                              if (item['meal']['country'] != 'France') {
                                itemTotal /= 655.957;
                                optionPrice /= 655.957;
                              }
                              return sum + itemTotal + optionPrice;
                            },
                          ) + deliveryFee;

                          final paymentIntentResponse = await http.post(
                            Uri.parse('https://dios-delices-backend.vercel.app/api/create-payment-intent'),
                            body: jsonEncode({
                              'amount': (totalAmount * 100).round(), // cents
                              'currency': 'eur',
                            }),
                            headers: {'Content-Type': 'application/json'},
                          );

                          if (paymentIntentResponse.statusCode != 200) {
                            Toast(context, "Erreur de paiement", false);
                            return;
                          }

                          final paymentIntentData = jsonDecode(paymentIntentResponse.body);

                          await stripe.Stripe.instance.initPaymentSheet(
                            paymentSheetParameters: stripe.SetupPaymentSheetParameters(
                              paymentIntentClientSecret: paymentIntentData['clientSecret'],
                              merchantDisplayName: 'Dios Délices',
                            ),
                          );

                          await stripe.Stripe.instance.presentPaymentSheet();

                          final updatedIntent = await stripe.Stripe.instance.retrievePaymentIntent(
                            paymentIntentData['clientSecret'],
                          );

                          final pmId = updatedIntent.paymentMethodId;

                          if (pmId == null || pmId.isEmpty) {
                            print("❌ Erreur : moyen de paiement non trouvé dans le PaymentIntent mis à jour");
                            Toast(context, "Erreur : aucun moyen de paiement détecté.", false);
                            return;
                          }

                          final paymentMethodDetails = await fetchStripePaymentMethodDetails(pmId);


                          // ✅ ENREGISTRER moyen de paiement
                          final id_moyen_paiement = await createMoyenPaiement(
                            paymentMethodDetails,
                            cartItems.first['user']['user_id'],
                          );

                          if (id_moyen_paiement == null) {
                            Toast(context, "Erreur paiement: moyen de paiement non enregistré", false);
                            return;
                          }

                          final commandeId = await createOrder(
                            cartItems,
                            deliveryFee,
                            selectedOption == "En Livraison" ? selectedAddress?.addressID : null,
                            id_moyen_paiement,
                            ref,
                          );

                          if (commandeId == null) {
                            Toast(context, "Impossible de créer la commande.", false);
                            return;
                          }

                          await updateOrderStatus(commandeId, "Payée");

                          Toast(context, "Commande validée avec succès", true);
                          cartNotifier.clearCart();

                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => OrderConfirmationPage()),
                          );
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

  Future<Map<String, dynamic>> fetchStripePaymentMethodDetails(String pmId) async {
    final response = await http.get(
      Uri.parse('https://dios-delices-backend.vercel.app/api/get-payment-method-details?pm_id=$pmId'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Échec récupération payment method : ${response.body}");
    }
  }

  // Effectuer les paiements pour chaque devise
  Future<void> makePayment(BuildContext context, CartNotifier cartNotifier,
      double totalAmount, String commandeId) async {
    try {
      final List<dynamic> cartItems = cartNotifier.state;

      double totalInEur = cartItems.fold(0.0, (previousValue, item) {
        double itemTotal = item["meal"]["price"] * item["order"]["quantity"];

        // Conversion optionPrice si présente
        double optionPrice = item["optionPrice"] ?? 0;
        if (item["meal"]["country"] != "France") {
          itemTotal /= 655.957;
          optionPrice /= 655.957;
        }

        itemTotal += optionPrice;

        return previousValue + itemTotal;
      });

      int amountInCents = (totalInEur * 100).round();

      final response = await http.post(
        Uri.parse(
            'https://dios-delices-backend.vercel.app/api/create-payment-intent'),
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

      await stripe.Stripe.instance.presentPaymentSheet().then((_) async {
        print("✅ Paiement effectué avec succès !");

        try {
          await stripe.Stripe.instance.presentPaymentSheet();

          final updatedIntent = await stripe.Stripe.instance.retrievePaymentIntent(
            paymentIntentData['clientSecret'],
          );

          final pmId = updatedIntent.paymentMethodId;

          if (pmId == null) {
            Toast(context, "Erreur : moyen de paiement non trouvé", false);
            return;
          }

          await updateOrderStatus(commandeId, "Payée");
        } catch (e) {
          print("⛔ Abandon suite à échec updateOrderStatus : $e");
          Toast(context, "Erreur de mise à jour de la commande.", false);
          return; // ne pas continuer
        }

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
      });
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
        Uri.parse('https://dios-delices-backend.vercel.app/api/create-invoice'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'items': items}),
      );

      if (response.statusCode == 200) {
        print("Facture générée avec succès");
        bool emailSent = await _sendEmailToUser(
          valid: true,
          firstname: items.first['user']['email'],
          email: items.first['user']['email'],
          restaurantName: items.first['restaurant']['name'],
        );
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

  Future<String?> createMoyenPaiement(Map<String, dynamic> pm, int userId) async {

    final body = {
      "userID": userId,
      "stripe_pm_id": pm['id'],
      "brand": pm['card']['brand'],
      "last4": int.parse(pm['card']['last4']),
      "exp_month": pm['card']['exp_month'],
      "exp_year": pm['card']['exp_year'],
      "type": "card",
      "is_default": "true",
      "libelle": "${pm['card']['brand']} ****${pm['card']['last4']}"
    };

    print("body card " + body.toString());

    final response = await http.post(
      Uri.parse("https://dios-delices-backend.vercel.app/api/create-payment-method"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data["id_moyen_paiement"];
    } else {
      print("Erreur enregistrement moyen de paiement : ${response.body}");
      return null;
    }
  }

  Future<String?> createOrder(List<dynamic> cartItems, double deliveryFee, int? id_adresse_livraison, String? id_moyen_paiement, WidgetRef ref) async {
    List<Restaurant> restaurantsList =
        await Restaurant.fetchRestaurantsFromDB();
    final userId = cartItems.first['user']['user_id'];
    final restaurantId = cartItems.first['restaurant']['restau_id'];
    final current_restaurant =
        Restaurant.getRestaurantByRestaurantId(restaurantsList, restaurantId);

    final totalAmount = cartItems.fold(
      0.0,
          (sum, item) {
        double itemTotal = item['meal']['price'] * item['order']['quantity'];
        double optionPrice = item['optionPrice'] ?? 0;
        if (item['meal']['country'] != 'France') {
          itemTotal /= 655.957;
          optionPrice /= 655.957;
        }
        return sum + itemTotal + optionPrice;
      },
    ) + deliveryFee; // ✅ Ajout des frais de livraison

    final items = cartItems.map((item) {
      return {
        "id_plat": item["meal"]["mealID"],
        "quantite": item["order"]["quantity"],
        "prix": item["meal"]["price"],
        "frais_livraison": deliveryFee,
        if (id_moyen_paiement != null) "moyen_paiement_id": id_moyen_paiement,
        if (id_adresse_livraison != null) "id_adresse_livraison": id_adresse_livraison,
        "options": (item["optionDetails"] ?? {}).map(
          (key, value) => MapEntry(
            key.toString(),
            {
              "name": value["name"].toString(),
              "price": (value["price"] as num).toDouble(),
            },
          ),
        ),
      };
    }).toList();

    final body = {
      "userId": userId,
      "restaurantId": restaurantId,
      "id_restaurateur": current_restaurant?.userID,
      "frais_livraison": deliveryFee,
      "totalAmount": totalAmount,
      "id_moyen_paiement": id_moyen_paiement,
      "items": items,
      if (id_adresse_livraison != null) "id_adresse_livraison": id_adresse_livraison,
    };

    print("body " + body.toString());


    final response = await http.post(
      Uri.parse("https://dios-delices-backend.vercel.app/api/create-order"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['commandeId'];
    } else {
      print("Erreur lors de la création de commande : ${response.body}");
      return null;
    }
  }

  Future<void> updateOrderStatus(String commandeId, String status) async {
    final response = await http.put(
      Uri.parse(
          "https://dios-delices-backend.vercel.app/api/update-order-status?id=$commandeId"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"status": status}),
    );

    if (response.statusCode == 200) {
      print("✅ Statut de la commande mis à jour");
    } else {
      print("❌ Erreur mise à jour statut : ${response.body}");
      throw Exception("Échec mise à jour statut commande");
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

class DeliveryAddressModal extends StatefulWidget {
  final List<Map<String, dynamic>> filteredAddresses;
  final int userId;
  final int user_roleID;
  final Function(delivery.Address selectedAddress) onAddressSelected;
  final Future<void> Function() onRefreshAddresses;

  const DeliveryAddressModal({
    required this.filteredAddresses,
    required this.userId,
    required this.user_roleID,
    required this.onAddressSelected,
    required this.onRefreshAddresses,
  });

  @override
  _DeliveryAddressModalState createState() => _DeliveryAddressModalState();
}

class _DeliveryAddressModalState extends State<DeliveryAddressModal> {
  delivery.Address? selectedAddress;
  final TextEditingController newAddressController = TextEditingController();
  final TextEditingController streetnumberController = TextEditingController();
  final TextEditingController streetController = TextEditingController();
  final TextEditingController postalCodeController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController countryController = TextEditingController();

  int? selectedAddressId;

  bool showAddressForm = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> addNewAddress() async {
    final street_number = streetnumberController.text.trim();
    final street = streetController.text.trim();
    final postal = postalCodeController.text.trim();
    final city = cityController.text.trim();
    final country = countryController.text.trim();

    if ([street_number, street, postal, city, country].any((e) => e.isEmpty))
      return;

    final fullAddress = "$street, $postal $city, $country";

    // 🔹 Convertir l'adresse en coordonnées GPS
    try {
      List<geocoding.Location> locations =
          await geocoding.locationFromAddress("$fullAddress, $city, $country");

      if (locations.isEmpty) {
        Toast(context, "Adresse introuvable. Veuillez vérifier l'exactitude.",
            false);
        return;
      }

      double lat = locations.first.latitude;
      double long = locations.first.longitude;

      print("Latitude: $lat, Longitude: $long");

      // 📌 Envoyer l'adresse avec les coordonnées GPS
      dynamic validationResult = await delivery.Address.manageAddress(
        city: city,
        state: country,
        fullAddress: fullAddress,
        numero: int.tryParse(street_number),
        lat: lat.toString(),
        object: "Livraison",
        objectID: widget.userId,
        long: long.toString(),
        user_roleID: widget.user_roleID,
      );

      print("validationResult " + validationResult.toString());
      if (validationResult == "EXISTING_ADDRESS") {
        Toast(context, "Adresse déjà enregistrée.", true);
        return;
      }

      if (validationResult is int) {
        final newAddress = {
          "object": "Livraison",
          "objectID": validationResult,
          "city": city,
          "state": country,
          "fullAddress": fullAddress,
          "lat": lat,
          "long": long,
        };

        selectedAddressId = validationResult;
        selectedAddress = delivery.Address.fromMap(newAddress);

        setState(() {
          streetController.clear();
          postalCodeController.clear();
          cityController.clear();
          countryController.clear();
          showAddressForm = !showAddressForm;
        });

        await widget.onRefreshAddresses();
        Toast(context, "Adresse enregistrée avec succès !", true);
        Navigator.pop(context);
      } else {
        Toast(context, validationResult, false);
      }
    } catch (e) {
      print("Erreur de géocodage : $e");
      Toast(context, "Adresse invalide ou non localisable.", false);
      return;
    }
  }

  Future<void> deleteAddress(int addressId, String object) async {
    print("deleting");
    if (object == "Livraison") {
      dynamic deleteResult = await delivery.Address.deleteAddress(
        addressID: addressId,
        object: object,
        objectID: widget.userId,
      );

      print("deleteResult " + deleteResult);

      if (deleteResult == "success") {
        await widget.onRefreshAddresses();
        Toast(context, "Adresse supprimée avec succès !", true);

        setState(() {
          // Supprimer uniquement si tous les filtres sont bien respectés
          widget.filteredAddresses.removeWhere((addr) =>
              addr['addressID'] == addressId &&
              addr['object'] == "User" &&
              addr['objectID'] == widget.userId);

          if (selectedAddressId == addressId) {
            selectedAddressId = null;
            selectedAddress = null;
          }
          Navigator.pop(context);
        });
      } else {
        Toast(context, "Erreur suppression adresse", false);
      }
    } else {
      Toast(context, "Vous ne pouvez pas supprimer votre adresse principale",
          false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Vos Adresses", style: TextStyle(fontWeight: FontWeight.bold)),
          ...widget.filteredAddresses.map((addr) {
            return ListTile(
              title: Text(addr['fullAddress']),
              leading: Radio<int>(
                value: addr['objectID'],
                groupValue: selectedAddressId,
                onChanged: (int? value) {
                  setState(() {
                    selectedAddressId = value;
                    selectedAddress = delivery.Address.fromMap(addr);
                  });
                },
              ),
              trailing: IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    final id = addr['addressID'];
                    print("addressID " + id.toString());
                    if (id != null && id is int) {
                      deleteAddress(id, addr['object']);
                    } else {
                      print(
                          "❌ Adresse invalide ou ID manquant : ${addr.toString()}");
                      Toast(context, "ID d'adresse invalide", false);
                    }
                  }),
            );
          }).toList(),
          TextButton.icon(
            icon: Icon(Icons.add),
            label: Text("Ajouter une nouvelle adresse"),
            onPressed: () {
              setState(() {
                showAddressForm = !showAddressForm;
              });
            },
          ),
          if (showAddressForm) ...[
            TextField(
              controller: streetnumberController,
              decoration: InputDecoration(labelText: "Numéro"),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
            ),
            TextField(
              controller: streetController,
              decoration: InputDecoration(labelText: "Rue"),
            ),
            TextField(
              controller: postalCodeController,
              decoration: InputDecoration(labelText: "Code postal"),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
            ),
            TextField(
              controller: cityController,
              decoration: InputDecoration(labelText: "Ville"),
            ),
            TextField(
              controller: countryController,
              decoration: InputDecoration(labelText: "Pays"),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: addNewAddress,
              child: Text("Enregistrer l'adresse"),
            ),
          ],
          ElevatedButton(
            onPressed: () {
              if (selectedAddress != null) {
                widget.onAddressSelected(selectedAddress!);
                Navigator.pop(context);
              }
            },
            child: Text("Valider"),
          ),
        ],
      ),
    );
  }
}
