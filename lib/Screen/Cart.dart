import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

import '../config/app_config.dart';
import '../modeles/address.dart' as delivery;
import '../modeles/commande.dart';
import '../modeles/restaurant.dart';
import '../modeles/users.dart';
import '../providers/cart_provider.dart';
import '../providers/selected_delivery.dart';
import '../services/commande_api.dart';
import '../services/notification_service.dart';
import '../services/promo_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../utils/toast.dart';
import '../widgets/animations.dart';
import 'order_tracking_page.dart';

class Cart extends ConsumerStatefulWidget {
  const Cart({super.key});

  @override
  ConsumerState<Cart> createState() => _CartState();
}

class _CartState extends ConsumerState<Cart> {
  final TextEditingController _promoController = TextEditingController();

  PromoApplication? _appliedPromo;
  bool _isSubmittingPayment = false;
  bool _payOnline = false;

  delivery.Address? selectedAddress;
  List<delivery.Address> addresses = [];
  List<Map<String, dynamic>> filteredAddresses = [];

  int current_userID = 0;
  int current_user_role = 0;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    final session = await SessionService.readSession();
    final addressesList = await delivery.Address.fetchAddressesFromDB();
    setState(() {
      addresses = addressesList;
      current_userID = session.userId;
      current_user_role = session.role.id;
    });
    await _filterAddresses();
  }

  Future<void> _filterAddresses() async {
    final userAddresses = <Map<String, dynamic>>[];
    for (var a in addresses) {
      if (a.objectID == current_userID &&
          (a.object == "Livraison" || a.object == "User")) {
        userAddresses.add(a.toJson());
      }
    }
    setState(() => filteredAddresses = userAddresses);
  }

  Future<void> refreshAddresses() async {
    final list = await delivery.Address.fetchAddressesFromDB();
    setState(() => addresses = list);
    await _filterAddresses();
  }

  double calculateDeliveryFee(List<Map<String, dynamic>> cartItems) {
    if (cartItems.isEmpty) return 0.0;
    final restaurant = cartItems.first['restaurant'] as Map<String, dynamic>?;
    final fee = restaurant?['delivery_fee'];
    if (fee is num) return fee.toDouble();
    return double.tryParse(fee?.toString() ?? '0') ?? 0.0;
  }

  String _countryFromCart(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return 'France';
    return items.first['meal']['country']?.toString() ?? 'France';
  }

  String _currencyCode(String country) =>
      country == 'France' ? 'eur' : 'xof';
  String _currencySymbol(String country) =>
      country == 'France' ? '€' : 'FCFA';

  double _lineTotal(Map<String, dynamic> item) {
    final unitPrice = (item['meal']['price'] as num?)?.toDouble() ?? 0.0;
    final quantity = (item['order']['quantity'] as num?)?.toInt() ?? 0;
    final optionPrice = (item['optionPrice'] as num?)?.toDouble() ?? 0.0;
    return (unitPrice + optionPrice) * quantity;
  }

  double _subtotal(List<Map<String, dynamic>> items) =>
      items.fold(0.0, (sum, i) => sum + _lineTotal(i));

  String _formatAmount(double amount, String code, String symbol) {
    if (code == 'eur') return '${amount.toStringAsFixed(2)} $symbol';
    return '${amount.round()} $symbol';
  }

  Future<void> _applyPromo({
    required List<Map<String, dynamic>> cartItems,
    required double deliveryFee,
  }) async {
    final subtotal = _subtotal(cartItems);
    final promo = await PromoService.applyCode(
      rawCode: _promoController.text,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
    );
    if (promo == null) {
      setState(() => _appliedPromo = null);
      Toast(context, "Code promo invalide.", false);
      return;
    }
    setState(() => _appliedPromo = promo);
    Toast(context, "Code promo appliqué : ${promo.description}", true);
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartStateProvider);
    final cartNotifier = ref.read(cartStateProvider.notifier);
    final selectedOption = ref.watch(selectedDeliveryProvider);
    final deliveryNotifier = ref.read(selectedDeliveryProvider.notifier);

    final allowedOptions = ['En Livraison', 'À Emporter'];
    final safeOption = allowedOptions.contains(selectedOption)
        ? selectedOption
        : 'À Emporter';

    // Adresse utilisateur par défaut
    if (selectedAddress == null) {
      try {
        selectedAddress = addresses.firstWhere(
          (a) => a.object == "User" && a.objectID == current_userID,
        );
      } catch (_) {}
    }

    final country = _countryFromCart(cartItems);
    final cc = _currencyCode(country);
    final cs = _currencySymbol(country);
    final deliveryFee =
        safeOption == "En Livraison" ? calculateDeliveryFee(cartItems) : 0.0;
    final cartTotal = _subtotal(cartItems);
    final reduction = _appliedPromo?.discountAmount ?? 0.0;
    final payableTotal =
        (cartTotal + deliveryFee - reduction).clamp(0.0, double.infinity);

    if (cartItems.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(title: const Text('Votre Panier')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_basket_outlined,
                  size: 80, color: AppColors.border),
              const SizedBox(height: 20),
              Text('Votre panier est vide',
                  style: AppTypography.titleMedium()),
              const SizedBox(height: 8),
              Text('Ajoutez des plats faits maison !',
                  style: AppTypography.bodyMedium()),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('Votre Panier',
            style: AppTypography.titleLarge().copyWith(fontSize: 20)),
      ),
      body: Column(
        children: [
          // Liste des items
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Items
                  ...List.generate(cartItems.length, (index) {
                    final item = cartItems[index];
                    return _CartItemCard(
                      item: item,
                      currencyCode: cc,
                      currencySymbol: cs,
                      onDelete: () {
                        cartNotifier.removeFromCart(index);
                        Toast(context,
                            "${item['meal']['meal_name']} supprimé", true);
                      },
                      onQuantityChanged: (qty) =>
                          cartNotifier.updateQuantity(index, qty),
                    );
                  }),
                  const SizedBox(height: 20),

                  // ── Livraison ───────────────────────
                  _SectionTitle('Livraison'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(
                                color: AppColors.border, width: 0.5),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: safeOption,
                              isDense: true,
                              isExpanded: true,
                              items: allowedOptions
                                  .map((o) => DropdownMenuItem(
                                      value: o, child: Text(o)))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) deliveryNotifier.state = v;
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (safeOption == 'En Livraison') ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddressPicker(),
                        icon: const Icon(Icons.location_on_outlined, size: 18),
                        label: Text(selectedAddress != null
                            ? 'Changer l\'adresse'
                            : 'Choisir l\'adresse'),
                      ),
                    ),
                    if (selectedAddress != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: AppColors.success, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedAddress!.fullAddress ?? '',
                                style: AppTypography.labelMedium(
                                    color: AppColors.ink),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],

                  // ── Code promo ──────────────────────
                  const SizedBox(height: 24),
                  _SectionTitle('Code promo'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _promoController,
                          textCapitalization: TextCapitalization.characters,
                          style: AppTypography.bodyLarge(),
                          decoration: InputDecoration(
                            hintText: 'Ex: BIENVENUE10',
                            prefixIcon: const Icon(Icons.local_offer_outlined,
                                size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: cartItems.isEmpty
                              ? null
                              : () => _applyPromo(
                                  cartItems: cartItems,
                                  deliveryFee: deliveryFee),
                          child: const Text('Appliquer'),
                        ),
                      ),
                    ],
                  ),
                  if (_appliedPromo != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: AppColors.success, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '${_appliedPromo!.code} : ${_appliedPromo!.description}',
                            style: AppTypography.labelMedium(
                                color: AppColors.success),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Résumé ──────────────────────────
                  const SizedBox(height: 24),
                  _SectionTitle('Résumé'),
                  const SizedBox(height: 14),
                  _SummaryRow('Sous-total', _formatAmount(cartTotal, cc, cs)),
                  if (safeOption == 'En Livraison')
                    _SummaryRow(
                        'Frais de livraison', _formatAmount(deliveryFee, cc, cs)),
                  if (_appliedPromo != null)
                    _SummaryRow(
                      'Réduction',
                      '- ${_formatAmount(reduction, cc, cs)}',
                      valueColor: AppColors.success,
                    ),
                  const Divider(height: 20),
                  _SummaryRow(
                    'Total',
                    _formatAmount(payableTotal, cc, cs),
                    isBold: true,
                    valueColor: AppColors.brand,
                  ),

                  // ── Paiement ────────────────────────
                  const SizedBox(height: 24),
                  _SectionTitle('Mode de paiement'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _payOnline = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: !_payOnline
                                  ? AppColors.brandSurface
                                  : AppColors.card,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.lg),
                              border: Border.all(
                                color: !_payOnline
                                    ? AppColors.brand
                                    : AppColors.border,
                                width: !_payOnline ? 1.5 : 0.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.payments_outlined,
                                    color: !_payOnline
                                        ? AppColors.brand
                                        : AppColors.inkMuted),
                                const SizedBox(height: 4),
                                Text('À la livraison',
                                    style: AppTypography.labelMedium(
                                        color: !_payOnline
                                            ? AppColors.brand
                                            : AppColors.inkMuted)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _payOnline = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: _payOnline
                                  ? AppColors.brandSurface
                                  : AppColors.card,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.lg),
                              border: Border.all(
                                color: _payOnline
                                    ? AppColors.brand
                                    : AppColors.border,
                                width: _payOnline ? 1.5 : 0.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.credit_card_outlined,
                                    color: _payOnline
                                        ? AppColors.brand
                                        : AppColors.inkMuted),
                                const SizedBox(height: 4),
                                Text('Fedapay',
                                    style: AppTypography.labelMedium(
                                        color: _payOnline
                                            ? AppColors.brand
                                            : AppColors.inkMuted)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      // ── Bouton Commander sticky ─────────────────────
      bottomNavigationBar: cartItems.isNotEmpty
          ? Container(
              padding:
                  const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed:
                        cartItems.isNotEmpty && !_isSubmittingPayment
                            ? () => _payOnline
                                ? _handleFedapayPayment()
                                : _handleOrder()
                            : null,
                    child: Text(
                      _isSubmittingPayment
                          ? 'Traitement...'
                          : 'Commander · $_currencySymbol($country) ${_formatAmount(payableTotal, cc, cs)}',
                      style: AppTypography.labelLarge(color: Colors.white),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  void _showAddressPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => DeliveryAddressModal(
        filteredAddresses: filteredAddresses,
        userId: current_userID,
        user_roleID: current_user_role,
        onRefreshAddresses: refreshAddresses,
        onAddressSelected: (selected) =>
            setState(() => selectedAddress = selected),
      ),
    );
  }

  // ── Logique métier (inchangée) ──────────────────────────
  Future<void> _handleOrder() async {
    final option = ref.read(selectedDeliveryProvider);
    if (option == "En Livraison" && selectedAddress == null) {
      Toast(context, "Choisissez une adresse.", false);
      return;
    }
    final cartItems = ref.read(cartStateProvider);
    final cartNotifier = ref.read(cartStateProvider.notifier);
    final items = List<Map<String, dynamic>>.from(cartItems);
    final country = _countryFromCart(items);
    final cc = _currencyCode(country);
    final fee = option == "En Livraison" ? calculateDeliveryFee(items) : 0.0;
    final discount = _appliedPromo?.discountAmount ?? 0.0;

    setState(() => _isSubmittingPayment = true);
    try {
      final commandeId = await createOrder(
        cartItems, fee,
        option == "En Livraison" ? selectedAddress?.addressID : null,
        null, ref,
        currencyCode: cc, reduction: discount,
        promoCode: _appliedPromo?.code,
      );
      if (commandeId != null) {
        Toast(context, "Commande confirmée !", true);
        final restaurantId = cartItems.first['restaurant']['restau_id'];
        final restaurantsList = await Restaurant.fetchRestaurantsFromDB();
        final currentRestaurant = Restaurant.getRestaurantByRestaurantId(
            restaurantsList, restaurantId);
        if (currentRestaurant != null) {
          final total = _subtotal(items) + fee - discount;
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
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) =>
                  OrderConfirmationPage(commandeId: commandeId)));
        }
      } else {
        Toast(context, "Impossible de créer la commande.", false);
      }
    } catch (_) {
      Toast(context, "Erreur. Réessayez.", false);
    } finally {
      if (mounted) setState(() => _isSubmittingPayment = false);
    }
  }

  Future<void> _handleFedapayPayment() async {
    final option = ref.read(selectedDeliveryProvider);
    if (option == "En Livraison" && selectedAddress == null) {
      Toast(context, "Choisissez une adresse.", false);
      return;
    }
    final cartItems = ref.read(cartStateProvider);
    final cartNotifier = ref.read(cartStateProvider.notifier);
    final items = List<Map<String, dynamic>>.from(cartItems);
    final country = _countryFromCart(items);
    final cc = _currencyCode(country);
    final fee = option == "En Livraison" ? calculateDeliveryFee(items) : 0.0;
    final discount = _appliedPromo?.discountAmount ?? 0.0;
    final total = (_subtotal(items) + fee - discount).clamp(0.0, double.infinity);
    final currencyIso = cc == 'XOF' ? 'XOF' : 'EUR';

    setState(() => _isSubmittingPayment = true);
    try {
      final commandeId = await createOrder(
        cartItems, fee,
        option == "En Livraison" ? selectedAddress?.addressID : null,
        null, ref, currencyCode: cc, reduction: discount,
        promoCode: _appliedPromo?.code,
      );
      if (commandeId == null) {
        Toast(context, "Impossible de créer la commande.", false);
        return;
      }
      final session = await SessionService.readSession();
      final usersList = await Users.fetchUsersFromDB();
      final currentUser = Users.getUsersByUserId(usersList, session.userId);

      final body = {
        'amount': total, 'currency': currencyIso,
        'commandeID': int.tryParse(commandeId),
        'customerName': '${currentUser?.firstname ?? ""} ${currentUser?.lastname ?? ""}',
        'customerEmail': currentUser?.email ?? '', 'country': country,
      };
      final response = await http.post(
        Uri.parse('${AppConfig.vercelBackendUrl}/api/fedapay-initiate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
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
          final currentRestaurant =
              Restaurant.getRestaurantByRestaurantId(restaurantsList, restaurantId);
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
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) =>
                    OrderConfirmationPage(commandeId: commandeId)));
          }
        } else {
          Toast(context, "Erreur: URL de paiement introuvable.", false);
        }
      } else {
        Toast(context, "Erreur paiement Fedapay.", false);
      }
    } catch (_) {
      Toast(context, "Erreur paiement.", false);
    } finally {
      if (mounted) setState(() => _isSubmittingPayment = false);
    }
  }

  Future<String?> createOrder(
    List<dynamic> cartItems,
    double deliveryFee,
    int? idAdresse,
    String? idPaiement,
    WidgetRef ref, {
    required String currencyCode,
    required double reduction,
    String? promoCode,
  }) async {
    final restaurantsList = await Restaurant.fetchRestaurantsFromDB();
    final restaurantId = cartItems.first['restaurant']['restau_id'];
    final currentRestaurant =
        Restaurant.getRestaurantByRestaurantId(restaurantsList, restaurantId);

    final subtotal =
        _subtotal(List<Map<String, dynamic>>.from(cartItems));
    final totalAmount =
        (subtotal + deliveryFee - reduction).clamp(0.0, double.infinity);

    final items = cartItems.map((item) => {
      "id_plat": item["meal"]["mealID"],
      "quantite": item["order"]["quantity"],
      "prix": item["meal"]["price"],
      "reduction": reduction,
      "fraisLivraison": deliveryFee,
      if (idPaiement != null) "moyen_paiement_id": idPaiement,
      if (idAdresse != null) "id_adresse_livraison": idAdresse,
      "options": (item["optionDetails"] ?? {}).map(
        (k, v) => MapEntry(k.toString(), {
          "name": v["name"].toString(),
          "price": (v["price"] as num).toDouble(),
        }),
      ),
    }).toList();

    final params = <String, dynamic>{
      "userID": current_userID,
      "restaurantId": restaurantId,
      "id_restaurateur": currentRestaurant?.userID,
      "currency": currencyCode,
      "fraisLivraison": deliveryFee,
      "reduction": reduction,
      "totalAmount": totalAmount,
      "items": items,
      if (idPaiement != null) "moyenPaiementID": idPaiement,
      if (promoCode != null) "promo_code": promoCode,
      if (idAdresse != null) "id_adresse_livraison": idAdresse,
    };

    final cloudFunction = ParseCloudFunction('createOrder');
    final response = await cloudFunction.execute(parameters: params);
    if (response.success && response.result != null) {
      final data = response.result as Map<String, dynamic>;
      if (data['success'] == true) {
        await Commande.refreshLocalCommandes();
        return data['commandeID'];
      }
    }
    return null;
  }
}

// ── Composants UI Panier ───────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTypography.titleMedium().copyWith(fontSize: 17));
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value,
      {this.isBold = false, this.valueColor});
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isBold
                ? AppTypography.titleMedium().copyWith(fontSize: 16)
                : AppTypography.bodyLarge(color: AppColors.inkMuted),
          ),
          Text(
            value,
            style: (isBold
                    ? AppTypography.titleMedium().copyWith(fontSize: 16)
                    : AppTypography.bodyLarge())
                .copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.item,
    required this.currencyCode,
    required this.currencySymbol,
    required this.onDelete,
    required this.onQuantityChanged,
  });

  final Map<String, dynamic> item;
  final String currencyCode;
  final String currencySymbol;
  final VoidCallback onDelete;
  final ValueChanged<int> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final meal = item["meal"] as Map<String, dynamic>;
    final quantity = (item["order"]["quantity"] as num).toInt();
    final unitPrice = (meal["price"] as num).toDouble();
    final optionPrice = (item["optionPrice"] as num?)?.toDouble() ?? 0.0;
    final lineTotal = (unitPrice + optionPrice) * quantity;
    final maxQty = (meal["number_of_servings"] as num?)?.toInt() ?? 99;

    String format(double v) {
      if (currencyCode == 'eur') return '${v.toStringAsFixed(2)} $currencySymbol';
      return '${v.round()} $currencySymbol';
    }

    return Dismissible(
      key: Key('cart_${item.hashCode}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.errorLight,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Photo
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Image.network(
                  meal["image"] ?? '',
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 72,
                    height: 72,
                    color: AppColors.surfaceWarm,
                    child: const Icon(Icons.restaurant,
                        color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal["meal_name"] ?? '',
                      style: AppTypography.titleMedium().copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      format(lineTotal),
                      style: AppTypography.bodyLarge(),
                    ),
                    if (item["optionDetails"] != null &&
                        item["optionDetails"] is Map)
                      ...(item["optionDetails"] as Map)
                          .entries
                          .map<Widget>((e) {
                        final info = e.value as Map<String, dynamic>;
                        return Text(
                          '${info["title"] ?? ""}: ${info["name"] ?? ""}',
                          style: AppTypography.labelMedium(
                              color: AppColors.inkSubtle),
                        );
                      }),
                  ],
                ),
              ),
              // Contrôle quantité
              Column(
                children: [
                  _QtyButton(
                    icon: Icons.add_rounded,
                    onTap: quantity < maxQty
                        ? () => onQuantityChanged(quantity + 1)
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '$quantity',
                      style: AppTypography.titleMedium().copyWith(fontSize: 16),
                    ),
                  ),
                  _QtyButton(
                    icon: Icons.remove_rounded,
                    onTap: quantity > 1
                        ? () => onQuantityChanged(quantity - 1)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 28,
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.brandSurface : AppColors.surfaceWarm,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon,
            size: 18,
            color: onTap != null ? AppColors.brand : AppColors.border),
      ),
    );
  }
}

// ── Confirmation ────────────────────────────────────────

class OrderConfirmationPage extends StatelessWidget {
  final String commandeId;
  const OrderConfirmationPage({super.key, required this.commandeId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: OrderConfettiCelebration(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AnimatedSuccessCheck(),
                  const SizedBox(height: 28),
                Text('Commande confirmée !',
                    style: AppTypography.headlineMedium(),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(
                  'Votre commande #$commandeId a été passée avec succès.',
                  style: AppTypography.bodyLarge(color: AppColors.inkMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderTrackingPage(
                            highlightedCommandeId: commandeId),
                      ),
                    ),
                    child: const Text('Suivre ma commande'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ));
  }
}

// ── Modal adresse ───────────────────────────────────────

class DeliveryAddressModal extends StatefulWidget {
  final List<Map<String, dynamic>> filteredAddresses;
  final int userId;
  final int user_roleID;
  final Function(delivery.Address) onAddressSelected;
  final Future<void> Function() onRefreshAddresses;

  const DeliveryAddressModal({
    super.key,
    required this.filteredAddresses,
    required this.userId,
    required this.user_roleID,
    required this.onAddressSelected,
    required this.onRefreshAddresses,
  });

  @override
  State<DeliveryAddressModal> createState() => _DeliveryAddressModalState();
}

class _DeliveryAddressModalState extends State<DeliveryAddressModal> {
  delivery.Address? selectedAddress;
  int? selectedAddressId;
  bool showForm = false;

  final streetCtrl = TextEditingController();
  final postalCtrl = TextEditingController();
  final cityCtrl = TextEditingController();
  final countryCtrl = TextEditingController();

  @override
  void dispose() {
    streetCtrl.dispose();
    postalCtrl.dispose();
    cityCtrl.dispose();
    countryCtrl.dispose();
    super.dispose();
  }

  Future<void> addNewAddress() async {
    final street = streetCtrl.text.trim();
    final postal = postalCtrl.text.trim();
    final city = cityCtrl.text.trim();
    final country = countryCtrl.text.trim();
    if ([street, postal, city, country].any((e) => e.isEmpty)) return;

    final fullAddress = "$street, $postal $city, $country";
    try {
      final locations =
          await geocoding.locationFromAddress("$fullAddress, $city, $country");
      if (locations.isEmpty) {
        Toast(context, "Adresse introuvable.", false);
        return;
      }
      final lat = locations.first.latitude;
      final long = locations.first.longitude;

      final result = await delivery.Address.manageAddress(
        city: city,
        state: country,
        fullAddress: fullAddress,
        numero: int.tryParse(street.split(',').first) ?? 0,
        lat: lat.toString(),
        object: "Livraison",
        objectID: widget.userId,
        long: long.toString(),
        user_roleID: widget.user_roleID,
      );

      if (result is int) {
        final newAddr = {
          "object": "Livraison", "objectID": result,
          "city": city, "state": country,
          "fullAddress": fullAddress, "lat": lat, "long": long,
        };
        selectedAddressId = result;
        selectedAddress = delivery.Address.fromMap(newAddr);

        streetCtrl.clear();
        postalCtrl.clear();
        cityCtrl.clear();
        countryCtrl.clear();

        setState(() => showForm = false);
        await widget.onRefreshAddresses();
        Toast(context, "Adresse enregistrée !", true);
        Navigator.pop(context);
      }
    } catch (_) {
      Toast(context, "Adresse invalide.", false);
    }
  }

  Future<void> deleteAddress(int id, String object) async {
    if (object != "Livraison") {
      Toast(context, "Impossible de supprimer l'adresse principale.", false);
      return;
    }
    final result = await delivery.Address.deleteAddress(
      addressID: id, object: object, objectID: widget.userId,
    );
    if (result == "success") {
      await widget.onRefreshAddresses();
      Toast(context, "Adresse supprimée.", true);
      setState(() {
        widget.filteredAddresses.removeWhere((a) => a['addressID'] == id);
        if (selectedAddressId == id) selectedAddressId = null;
      });
      Navigator.pop(context);
    } else {
      Toast(context, "Erreur suppression.", false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20,
              MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            children: [
              // Poignée
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 20),
              Text('Vos adresses', style: AppTypography.titleMedium()),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    ...widget.filteredAddresses.map((addr) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: selectedAddressId == addr['objectID']
                              ? AppColors.brand
                              : AppColors.border,
                          width: selectedAddressId == addr['objectID'] ? 1.5 : 0.5,
                        ),
                      ),
                      child: ListTile(
                        title: Text(addr['fullAddress'] ?? ''),
                        leading: Radio<int>(
                          value: addr['objectID'],
                          groupValue: selectedAddressId,
                          onChanged: (v) => setState(() {
                            selectedAddressId = v;
                            selectedAddress =
                                delivery.Address.fromMap(addr);
                          }),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.error, size: 20),
                          onPressed: () => deleteAddress(
                              addr['addressID'], addr['object']),
                        ),
                      ),
                    )),
                    if (!showForm)
                      TextButton.icon(
                        onPressed: () => setState(() => showForm = true),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Nouvelle adresse'),
                      ),
                    if (showForm) ...[
                      const SizedBox(height: 8),
                      _addrField('Rue', streetCtrl),
                      _addrField('Code postal', postalCtrl,
                          keyboardType: TextInputType.number),
                      _addrField('Ville', cityCtrl),
                      _addrField('Pays', countryCtrl),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: addNewAddress,
                        child: const Text('Enregistrer'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: selectedAddress != null
                      ? () {
                          widget.onAddressSelected(selectedAddress!);
                          Navigator.pop(context);
                        }
                      : null,
                  child: const Text('Valider'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _addrField(String hint, TextEditingController ctrl,
      {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(hintText: hint, isDense: true),
      ),
    );
  }
}
