import 'dart:convert';
import 'package:count_stepper/count_stepper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../modeles/commande.dart';
import '../modeles/restaurant.dart';
import '../modeles/users.dart';
import '../modeles/address.dart' as delivery;
import '../services/notification_service.dart';
import '../providers/cart_provider.dart';
import '../providers/selected_delivery.dart';
import '../services/commande_api.dart';
import '../services/promo_service.dart';
import '../services/session_service.dart';
import '../config/app_config.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/toast.dart';
import 'package:http/http.dart' as http;
import 'order_tracking_page.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

class Cart extends ConsumerStatefulWidget {
  @override
  _CartState createState() => _CartState();
}

class _CartState extends ConsumerState<Cart> {
  final TextEditingController _promoCodeController = TextEditingController();

  PromoApplication? _appliedPromo;
  bool _isSubmittingPayment = false;
  bool _payOnline = false;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    _promoCodeController.dispose();
    super.dispose();
  }

  delivery.Address? selectedAddress;

  List<delivery.Address> addresses = [];
  List<Map<String, dynamic>> filteredAddresses = [];
  List<Users> users = [];

  int current_userID = 0;
  int current_user_role = 0;

  void loadData() async {
    final session = await SessionService.readSession();
    List<delivery.Address> addressesList = await delivery.Address.fetchAddressesFromDB();

    setState(() {
      addresses = addressesList;
      current_userID = session.userId;
      current_user_role = session.role.id;
    });
    await _filterAddresses();
  }

  Future<void> _filterAddresses() async {
    final List<Map<String, dynamic>> userAddresses = [];

    for (var a in addresses) {
      if (a.objectID == current_userID &&
          (a.object == "Livraison" || a.object == "User")) {
        userAddresses.add(a.toJson());
      }
    }

    setState(() {
      filteredAddresses = userAddresses;
    });
  }

  Future<void> refreshAddresses() async {
    List<delivery.Address> addressesList =
        await delivery.Address.fetchAddressesFromDB();
    setState(() {
      addresses = addressesList;
    });
    await _filterAddresses();
  }

  double calculateDeliveryFee(List<Map<String, dynamic>> cartItems) {
    if (cartItems.isEmpty) {
      return 0.0;
    }

    final restaurant = cartItems.first['restaurant'] as Map<String, dynamic>?;
    final fee = restaurant?['delivery_fee'];
    if (fee is num) {
      return fee.toDouble();
    }

    return double.tryParse(fee?.toString() ?? '0') ?? 0.0;
  }

  String _countryFromCart(List<Map<String, dynamic>> cartItems) {
    if (cartItems.isEmpty) {
      return 'France';
    }
    return cartItems.first['meal']['country']?.toString() ?? 'France';
  }

  String _currencyCodeFromCountry(String country) {
    return country == 'France' ? 'eur' : 'xof';
  }

  String _currencySymbolFromCountry(String country) {
    return country == 'France' ? '€' : 'FCFA';
  }

  double _lineTotal(Map<String, dynamic> item) {
    final unitPrice = (item['meal']['price'] as num?)?.toDouble() ?? 0.0;
    final quantity = (item['order']['quantity'] as num?)?.toInt() ?? 0;
    final optionPrice = (item['optionPrice'] as num?)?.toDouble() ?? 0.0;
    return (unitPrice + optionPrice) * quantity;
  }

  double _calculateSubtotal(List<Map<String, dynamic>> cartItems) {
    return cartItems.fold<double>(0.0, (sum, item) => sum + _lineTotal(item));
  }

  String _formatAmount(double amount, String currencyCode, String currencySymbol) {
    if (currencyCode == 'eur') {
      return "${amount.toStringAsFixed(2)} $currencySymbol";
    }
    return "${amount.round()} $currencySymbol";
  }

  Future<void> _applyPromoCode({
    required List<Map<String, dynamic>> cartItems,
    required double deliveryFee,
  }) async {
    final subtotal = _calculateSubtotal(cartItems);
    final promo = await PromoService.applyCode(
      rawCode: _promoCodeController.text,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
    );

    if (promo == null) {
      setState(() {
        _appliedPromo = null;
      });
      Toast(context, "Code promo invalide.", false);
      return;
    }

    setState(() {
      _appliedPromo = promo;
    });
    Toast(context, "Code promo appliqué : ${promo.description}", true);
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

    final country = _countryFromCart(cartItems);
    final currencyCode = _currencyCodeFromCountry(country);
    final currencySymbol = _currencySymbolFromCountry(country);

    double deliveryFee = selectedOption == "En Livraison"
        ? calculateDeliveryFee(cartItems)
        : 0.0;

    final cartTotal = _calculateSubtotal(cartItems);
    final reductionAmount = _appliedPromo?.discountAmount ?? 0.0;
    final payableTotal = (cartTotal + deliveryFee - reductionAmount).clamp(
      0.0,
      double.infinity,
    );

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
                                    _formatAmount(
                                      (item["meal"]["price"] as num).toDouble(),
                                      currencyCode,
                                      currencySymbol,
                                    ),
                                  ),
                                  if (item["meal"]["options"] != null &&
                                      item["meal"]["options"] is Map &&
                                      item["optionDetails"] != null &&
                                      item["optionDetails"] is Map)
                                    ...item["meal"]["options"].entries.map<Widget>((entry) {

                                      final optionIndex = entry.key;
                                      final optionInfo = item["optionDetails"][optionIndex];
                                      final title = optionInfo != null && optionInfo["title"] != null
                                          ? optionInfo["title"]
                                          : "Option 1";
                                      final name = optionInfo != null && optionInfo["name"] != null
                                          ? optionInfo["name"]
                                          : entry.value.toString();
                                      final price = optionInfo != null && optionInfo["price"] != null
                                          ? optionInfo["price"]
                                          : 0.0;
                                      print("price ddd " + price.toString());

                                      final devise = currencySymbol;
                                      return Text(
                                        "$title : $name${(price != null && price > 0) ? ' +${price.toStringAsFixed(2)} $devise' : ''}",
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
                              Text(
                                _formatAmount(
                                  deliveryFee,
                                  currencyCode,
                                  currencySymbol,
                                ),
                              ),
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
                          Text(
                              _formatAmount(
                                deliveryFee,
                                currencyCode,
                                currencySymbol,
                              ),
                              style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ],
                    Divider(),
                    SizedBox(height: 12),
                    Text(
                      "Code promo",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _promoCodeController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: "Ex: BIENVENUE10",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: cartItems.isEmpty
                              ? null
                              : () async => _applyPromoCode(
                                    cartItems: cartItems,
                                    deliveryFee: deliveryFee,
                                  ),
                          child: Text("Appliquer"),
                        ),
                      ],
                    ),
                    if (_appliedPromo != null) ...[
                      SizedBox(height: 8),
                      Text(
                        "${_appliedPromo!.code} : ${_appliedPromo!.description}",
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Sous-total",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _formatAmount(cartTotal, currencyCode, currencySymbol),
                          style: TextStyle(fontSize: 20, color: Colors.red),
                        ),
                      ],
                    ),
                    if (_appliedPromo != null) ...[
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Réduction",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            "- ${_formatAmount(reductionAmount, currencyCode, currencySymbol)}",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedOption == 'En Livraison'
                              ? "Total avec livraison"
                              : "Total sans livraison",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _formatAmount(
                            payableTotal,
                            currencyCode,
                            currencySymbol,
                          ),
                          style: TextStyle(fontSize: 20, color: Colors.red),
                        ),
                      ],
                    ),
                    SizedBox(height: 30),
                    if (cartItems.isNotEmpty) ...[
                      Center(child: Text('Mode de paiement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ChoiceChip(
                            label: Text('À la livraison'),
                            selected: !_payOnline,
                            onSelected: (v) => setState(() => _payOnline = false),
                            selectedColor: Colors.green.shade50,
                          ),
                          SizedBox(width: 10),
                          ChoiceChip(
                            label: Text('Fedapay'),
                            selected: _payOnline,
                            onSelected: (v) => setState(() => _payOnline = true),
                            selectedColor: Colors.blue.shade50,
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: 16),
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _payOnline ? Colors.blue : Colors.green,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: cartItems.isNotEmpty && !_isSubmittingPayment
                            ? () => _payOnline ? _handleFedapayPayment() : _handleOrder()
                            : null,
                        child: Text(_isSubmittingPayment
                            ? 'Traitement...'
                            : _payOnline ? 'Payer avec Fedapay' : 'Commander'),
                      ),
                    ),
          ],
                ),
              ),
            ),
    );
  }

  Future<void> _handleOrder() async {
    final selectedOption = ref.read(selectedDeliveryProvider);
    if (selectedOption == "En Livraison" && selectedAddress == null) {
      Toast(context, "Choisissez une adresse de livraison.", false);
      return;
    }

    final cartItems = ref.read(cartStateProvider);
    final cartNotifier = ref.read(cartStateProvider.notifier);
    final items = List<Map<String, dynamic>>.from(cartItems);
    final country = _countryFromCart(items);
    final cc = _currencyCodeFromCountry(country);
    final fee = selectedOption == "En Livraison"
        ? calculateDeliveryFee(List<Map<String, dynamic>>.from(cartItems))
        : 0.0;
    final discount = _appliedPromo?.discountAmount ?? 0.0;

    setState(() => _isSubmittingPayment = true);

    try {
      final commandeId = await createOrder(
        cartItems,
        fee,
        selectedOption == "En Livraison" ? selectedAddress?.addressID : null,
        null,
        ref,
        currencyCode: cc,
        reduction: discount,
        promoCode: _appliedPromo?.code,
      );

      if (commandeId != null) {
        Toast(context, "Commande confirmée !", true);

        final restaurantId = cartItems.first['restaurant']['restau_id'];
        final restaurantsList = await Restaurant.fetchRestaurantsFromDB();
        final currentRestaurant = Restaurant.getRestaurantByRestaurantId(restaurantsList, restaurantId);
        if (currentRestaurant != null) {
          final total = _calculateSubtotal(List<Map<String, dynamic>>.from(cartItems)) + fee - discount;
          NotificationService.sendOrderNotificationToRestaurateur(
            restaurateurId: currentRestaurant.userID,
            restaurantName: currentRestaurant.name,
            orderDetails: "Commande #$commandeId",
            totalAmount: total.clamp(0.0, double.infinity),
            orderId: int.tryParse(commandeId),
          );
        }

        cartNotifier.clearCart();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OrderConfirmationPage(commandeId: commandeId),
            ),
          );
        }
      } else {
        Toast(context, "Impossible de créer la commande.", false);
      }
    } catch (e) {
      Toast(context, "Erreur. Réessayez.", false);
    } finally {
      if (mounted) setState(() => _isSubmittingPayment = false);
    }
  }

  Future<void> _handleFedapayPayment() async {
    final selectedOption = ref.read(selectedDeliveryProvider);
    if (selectedOption == "En Livraison" && selectedAddress == null) {
      Toast(context, "Choisissez une adresse de livraison.", false);
      return;
    }

    final cartItems = ref.read(cartStateProvider);
    final cartNotifier = ref.read(cartStateProvider.notifier);
    final items = List<Map<String, dynamic>>.from(cartItems);
    final country = _countryFromCart(items);
    final cc = _currencyCodeFromCountry(country);
    final fee = selectedOption == "En Livraison" ? calculateDeliveryFee(items) : 0.0;
    final discount = _appliedPromo?.discountAmount ?? 0.0;
    final total = (_calculateSubtotal(items) + fee - discount).clamp(0.0, double.infinity);
    final currencyIso = cc == 'XOF' ? 'XOF' : 'EUR';

    setState(() => _isSubmittingPayment = true);

    try {
      final commandeId = await createOrder(
        cartItems, fee,
        selectedOption == "En Livraison" ? selectedAddress?.addressID : null,
        null, ref, currencyCode: cc, reduction: discount, promoCode: _appliedPromo?.code,
      );

      if (commandeId == null) {
        Toast(context, "Impossible de créer la commande.", false);
        return;
      }

      final session = await SessionService.readSession();
      final usersList = await Users.fetchUsersFromDB();
      final currentUser = Users.getUsersByUserId(usersList, session.userId);

      final requestBody = {
        'amount': total,
        'currency': currencyIso,
        'commandeID': int.tryParse(commandeId),
        'customerName': '${currentUser?.firstname ?? ""} ${currentUser?.lastname ?? ""}',
        'customerEmail': currentUser?.email ?? '',
        'country': country,
      };

      final response = await http.post(
        Uri.parse('${AppConfig.vercelBackendUrl}/api/fedapay-initiate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final paymentUrl = data['paymentUrl'] as String?;

        if (paymentUrl != null && paymentUrl.isNotEmpty) {
          final uri = Uri.parse(paymentUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }

          final restaurantId = cartItems.first['restaurant']['restau_id'];
          final restaurantsList = await Restaurant.fetchRestaurantsFromDB();
          final currentRestaurant = Restaurant.getRestaurantByRestaurantId(restaurantsList, restaurantId);
          if (currentRestaurant != null) {
            NotificationService.sendOrderNotificationToRestaurateur(
              restaurateurId: currentRestaurant.userID,
              restaurantName: currentRestaurant.name,
              orderDetails: "Commande #$commandeId",
              totalAmount: total,
              orderId: int.tryParse(commandeId),
            );
          }

          cartNotifier.clearCart();
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => OrderConfirmationPage(commandeId: commandeId),
              ),
            );
          }
        } else {
          Toast(context, "Erreur: URL de paiement introuvable.", false);
        }
      } else {
        Toast(context, "Erreur paiement Fedapay. Réessayez.", false);
      }
    } catch (e) {
      Toast(context, "Erreur paiement. Réessayez.", false);
    } finally {
      if (mounted) setState(() => _isSubmittingPayment = false);
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

  Future<String?> createOrder(
    List<dynamic> cartItems,
    double deliveryFee,
    int? id_adresse_livraison,
    String? id_moyen_paiement,
    WidgetRef ref, {
    required String currencyCode,
    required double reduction,
    String? promoCode,
  }) async {
    List<Restaurant> restaurantsList =
        await Restaurant.fetchRestaurantsFromDB();
    final restaurantId = cartItems.first['restaurant']['restau_id'];
    final current_restaurant =
        Restaurant.getRestaurantByRestaurantId(restaurantsList, restaurantId);

    final subtotal = _calculateSubtotal(List<Map<String, dynamic>>.from(cartItems));
    final totalAmount = (subtotal + deliveryFee - reduction).clamp(
      0.0,
      double.infinity,
    );

    final items = cartItems.map((item) {
      return {
        "id_plat": item["meal"]["mealID"],
        "quantite": item["order"]["quantity"],
        "prix": item["meal"]["price"],
        "reduction": reduction,
          "fraisLivraison": deliveryFee,
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

    final params = <String, dynamic>{
      "userID": current_userID,
      "restaurantId": restaurantId,
      "id_restaurateur": current_restaurant?.userID,
      "currency": currencyCode,
      "fraisLivraison": deliveryFee,
      "reduction": reduction,
      "totalAmount": totalAmount,
      "items": items,
      if (id_moyen_paiement != null) "moyenPaiementID": id_moyen_paiement,
      if (promoCode != null) "promo_code": promoCode,
      if (id_adresse_livraison != null) "id_adresse_livraison": id_adresse_livraison,
    };

    print("params " + params.toString());

    final cloudFunction = ParseCloudFunction('createOrder');
    final response = await cloudFunction.execute(parameters: params);

    if (response.success && response.result != null) {
      final data = response.result as Map<String, dynamic>;
      if (data['success'] == true) {
        await Commande.refreshLocalCommandes();
        return data['commandeID'];
      } else {
        print("Erreur création commande : ${data['error']}");
        return null;
      }
    } else {
      print("Erreur lors de la création de commande : ${response.error?.message}");
      return null;
    }
  }

  Future<void> updateOrderStatus(String commandeId, String status) async {
    await CommandeApi.updateOrderStatus(commandeId, status);
  }
}

class OrderConfirmationPage extends StatelessWidget {
  final String commandeId;

  const OrderConfirmationPage({super.key, required this.commandeId});

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
                  MaterialPageRoute(
                    builder: (context) => OrderTrackingPage(
                      highlightedCommandeId: commandeId,
                    ),
                  ),
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
