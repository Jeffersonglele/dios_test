import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../../l10n/app_localizations.dart';
import '../../db/database_helper.dart';
import '../../models/address.dart' as delivery;
import '../../models/commande.dart';
import '../../models/ligne_commande.dart';
import '../../models/restaurant.dart';
import '../../models/users.dart';
import '../../providers/cart_provider.dart';
import '../../providers/selected_delivery.dart';
import '../../services/commande_api.dart';
import '../../services/delivery_availability_service.dart';
import '../../services/geocoding_api_service.dart';
import '../../services/location_cache_service.dart';
import '../../services/notification_service.dart';
import '../../services/node_home_service.dart';
import '../../services/node_order_service.dart';
import '../../services/node_auth_service.dart';
import '../../services/node_catalog_service.dart';
import '../../services/promo_service.dart';
import '../../services/restaurant_opening_hours_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../../services/currency_service.dart';
import '../../utils/currency_util.dart';
import '../../utils/country_util.dart';
import '../../utils/toast.dart';
import '../../widgets/animations.dart';
import '../../widgets/delivery_unavailable.dart';
import '../../widgets/dios_image.dart';
import '../../widgets/cart_widgets.dart';
import '../navigation/curved_navigation_user.dart';
import '../../utils/payment_provider_label.dart';
import '../orders/order_tracking_page.dart';
import '../payment/nyole_payment_page.dart';
import '../../services/wallet_service.dart';
import '../wallet/wallet_screen.dart';

class Cart extends ConsumerStatefulWidget {
  const Cart({super.key, this.restaurantId});

  final int? restaurantId;

  @override
  ConsumerState<Cart> createState() => _CartState();
}

/// Modes de paiement proposés dans le panier.
enum _PayMode { cash, mobileMoney, wallet }

/// Données figées au moment où le client valide le panier.
class _Checkout {
  const _Checkout({
    required this.option,
    required this.items,
    required this.country,
    required this.currencyCode,
    required this.fee,
    required this.discount,
    required this.restaurantId,
  });

  final String option;
  final List<Map<String, dynamic>> items;
  final String country;
  final String currencyCode;
  final double fee;
  final double discount;
  final int restaurantId;

  bool get isDelivery => option == kDeliveryOptionLivraison;
}

/// Commande Mobile Money créée mais pas encore payée. Réutilisée si le
/// client relance le paiement sans avoir modifié son panier.
class _PendingOnlineOrder {
  const _PendingOnlineOrder({
    required this.orderId,
    required this.orderUuid,
    required this.signature,
  });

  final String orderId;
  final String? orderUuid;
  final String signature;
}

/// Résultat du devis de livraison affiché dans le panier.
class _FeeQuote {
  const _FeeQuote.priced(double this.fee, {this.distanceKm})
      : needsAddress = false,
        message = null;
  const _FeeQuote.needsAddress()
      : fee = null,
        distanceKm = null,
        needsAddress = true,
        message = null;
  const _FeeQuote.unavailable(String this.message)
      : fee = null,
        distanceKm = null,
        needsAddress = false;
  const _FeeQuote.error(String this.message)
      : fee = null,
        distanceKm = null,
        needsAddress = false;

  final double? fee;
  final double? distanceKm;
  final bool needsAddress;
  final String? message;

  bool get ok => fee != null;
}

class _CartState extends ConsumerState<Cart> {
  final TextEditingController _promoController = TextEditingController();

  PromoApplication? _appliedPromo;
  bool _isSubmittingPayment = false;
  _PayMode _payMode = _PayMode.cash;

  /// Commande déjà créée mais pas encore payée (solde insuffisant) :
  /// réutilisée au prochain essai pour ne pas créer de doublon.
  String? _walletPendingOrderId;
  _PendingOnlineOrder? _onlinePending;

  /// UUID Node de la dernière commande créée par [createOrder].
  String? _lastCreatedOrderUuid;
  bool _isUsingCurrentLocation = false;
  DeliveryAvailability? _cartDeliveryAvailability;
  RestaurantOpeningStatus? _cartOpeningStatus;
  _FeeQuote? _feeQuote;

  /// Vrai une fois les adresses du client chargées (évite d'afficher un
  /// tarif provisoire avant de connaître l'adresse de livraison).
  bool _addressesLoaded = false;
  String? _deliveryFeeKey;
  int _deliveryFeeRequestId = 0;
  bool _isDeliveryFeeLoading = false;

  delivery.Address? selectedAddress;
  List<delivery.Address> addresses = [];
  List<Map<String, dynamic>> filteredAddresses = [];

  int current_userID = 0;
  int current_user_role = 0;
  int _cityID = 1;

  List<Map<String, dynamic>> _itemsForRestaurant(
      List<Map<String, dynamic>> items) {
    if (widget.restaurantId == null) return items;
    return items.where((item) {
      final restaurant = item['restaurant'] as Map<String, dynamic>?;
      return int.tryParse(restaurant?['restau_id']?.toString() ?? '') ==
          widget.restaurantId;
    }).toList();
  }

  Map<int, List<Map<String, dynamic>>> _groupItems(
      List<Map<String, dynamic>> items) {
    final groups = <int, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final restaurant = item['restaurant'] as Map<String, dynamic>?;
      final id = int.tryParse(restaurant?['restau_id']?.toString() ?? '');
      if (id == null) continue;
      groups.putIfAbsent(id, () => []).add(item);
    }
    return groups;
  }

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
    await ref
        .read(cartStateProvider.notifier)
        .activateUser(session.userId, refreshRemote: true);
    var addressesList = await delivery.Address.fetchAddressesFromDB();
    Users? nodeUser;
    final nodeToken = await SessionService.readNodeToken();
    if (nodeToken != null) {
      try {
        final snapshot = await NodeHomeService.load(token: nodeToken);
        addressesList = snapshot.addresses;
        nodeUser = snapshot.user;
      } catch (_) {
        // Le cache local reste utilisable si le backend est momentanément indisponible.
      }
    }
    if (!mounted) return;
    setState(() {
      addresses = addressesList;
      current_userID = session.userId;
      current_user_role = session.role.id;
      selectedAddress = null;
      _addressesLoaded = true;
    });
    final user = await DatabaseHelper.getUser(current_userID);
    if (!mounted) return;
    _cityID = nodeUser?.cityID ?? user?.cityID ?? 1;
    await _filterAddresses();
    await _refreshCartDeliveryAvailability(
        _itemsForRestaurant(ref.read(cartStateProvider)));
  }

  Future<void> _refreshCartDeliveryAvailability(
      List<Map<String, dynamic>> cartItems) async {
    if (cartItems.isEmpty) {
      if (mounted) {
        setState(() {
          _cartDeliveryAvailability = null;
          _cartOpeningStatus = null;
        });
      }
      return;
    }
    final restaurantId =
        (cartItems.first['restaurant'] as Map<String, dynamic>?)?['restau_id'];
    if (restaurantId == null) return;
    Restaurant? restaurant;
    final nodeToken = await SessionService.readNodeToken();
    if (nodeToken != null) {
      try {
        restaurant = await NodeCatalogService.loadRestaurant(
          restaurantId: int.tryParse(restaurantId.toString()) ?? 0,
          token: nodeToken,
        );
      } catch (_) {}
    } else {
      final restaurants = await Restaurant.fetchRestaurantsFromDB();
      restaurant = Restaurant.getRestaurantByRestaurantId(
          restaurants, int.tryParse(restaurantId.toString()) ?? 0);
    }
    if (restaurant == null) return;
    final availability = await DeliveryAvailabilityService.forRestaurant(
      restaurant,
      customerAddress: selectedAddress,
    );
    if (mounted) {
      setState(() {
        _cartDeliveryAvailability = availability;
        _cartOpeningStatus = restaurant?.openingStatus;
      });
    }
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
    var list = await delivery.Address.fetchAddressesFromDB();
    final nodeToken = await SessionService.readNodeToken();
    if (nodeToken != null) {
      try {
        list = (await NodeHomeService.load(token: nodeToken)).addresses;
      } catch (_) {}
    }
    setState(() => addresses = list);
    await _filterAddresses();
  }

  Widget _buildBasketSelection(
    BuildContext context,
    Map<int, List<Map<String, dynamic>>> groups,
    AppLocalizations l10n,
  ) {
    return Scaffold(
      backgroundColor:
          AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      appBar: AppBar(
        title: Text(
          l10n.cart_baskets_title,
          style: AppTypography.titleLarge(
            color: AppColors.resolve(AppColors.ink, AppDarkColors.ink),
          ).copyWith(fontSize: 20),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        itemCount: groups.length + 1,
        separatorBuilder: (_, index) => index == 0
            ? const SizedBox(height: 18)
            : const SizedBox(height: 10),
        itemBuilder: (_, index) {
          if (index == 0) {
            return Text(
              l10n.cart_baskets_hint,
              style: AppTypography.bodyLarge(
                color: AppColors.resolve(AppColors.ink, AppDarkColors.ink),
              ),
            );
          }

          final entry = groups.entries.elementAt(index - 1);
          final items = entry.value;
          final restaurant = items.first['restaurant'] as Map<String, dynamic>?;
          final name = restaurant?['name']?.toString() ?? l10n.cart_title;
          final image = restaurant?['image']?.toString() ?? '';
          final count = items.fold<int>(
            0,
            (sum, item) =>
                sum +
                (((item['order'] as Map<String, dynamic>?)?['quantity'] as num?)
                        ?.toInt() ??
                    0),
          );
          final country = _countryFromCart(items);
          final total = _subtotal(items);

          return InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Cart(restaurantId: entry.key),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.resolve(AppColors.card, AppDarkColors.card),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                    color: AppColors.resolve(
                        AppColors.border, AppDarkColors.border),
                    width: 0.5),
              ),
              child: Row(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 58,
                      height: 58,
                      child: image.isEmpty
                          ? ColoredBox(
                              color: AppColors.resolve(
                                  AppColors.ink, AppDarkColors.ink),
                              child: Icon(Icons.storefront_rounded,
                                  color: Colors.white, size: 28),
                            )
                          : DiosImage(url: image, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: AppTypography.titleMedium(
                                color: AppColors.resolve(
                                    AppColors.ink, AppDarkColors.ink))),
                        const SizedBox(height: 5),
                        Text(
                          '${_formatAmount(total, _currencyCode(country), _currencySymbol(country))} • ${l10n.cart_basket_articles(count)}',
                          style: AppTypography.bodyLarge(
                            color: AppColors.resolve(
                                AppColors.ink, AppDarkColors.ink),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          l10n.cart_basket_details,
                          style: AppTypography.labelLarge(
                              color: AppColors.resolve(
                                  AppColors.brand, AppDarkColors.brand)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.inkMuted, size: 28),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  Future<delivery.Address?> _findNearbySavedAddress(
    Position position,
  ) async {
    final savedAddresses = await delivery.Address.fetchAddressesFromDB();
    for (final address in savedAddresses) {
      if (address.objectID != current_userID ||
          (address.object != 'Livraison' && address.object != 'User')) {
        continue;
      }
      final lat = double.tryParse(address.lat ?? '');
      final lng = double.tryParse(address.long ?? '');
      if (lat == null || lng == null) continue;
      if (Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            lat,
            lng,
          ) <=
          25) {
        return address;
      }
    }
    return null;
  }

  Future<void> _useCurrentLocation() async {
    if (_isUsingCurrentLocation) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isUsingCurrentLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) Toast(context, 'Veuillez activer le GPS', false);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) Toast(context, l10n.location_detect_failed, false);
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (e) {
        debugPrint(
            'cart.getCurrentPosition failed or timed out: $e, fallback to lastKnownPosition');
        try {
          position = await Geolocator.getLastKnownPosition();
        } catch (lastErr) {
          debugPrint('cart.getLastKnownPosition failed: $lastErr');
        }
      }

      if (position == null) {
        if (mounted) Toast(context, l10n.location_detect_failed, false);
        return;
      }

      GeocodingResult? geocoded;
      try {
        geocoded = await GeocodingApiService.reverse(
          position.latitude,
          position.longitude,
        );
      } catch (e) {
        debugPrint('GeocodingApiService.reverse error: $e');
      }

      final fallbackAddress = 'Position GPS : '
          '${position.latitude.toStringAsFixed(6)}, '
          '${position.longitude.toStringAsFixed(6)}';
      final fullAddress = _firstText([
        geocoded?.displayName,
        geocoded?.street,
        fallbackAddress,
      ]);
      final city = _firstText([
        geocoded?.locality,
        geocoded?.subAdministrativeArea,
        geocoded?.administrativeArea,
      ]);
      final state = _firstText([
        geocoded?.administrativeArea,
        geocoded?.country,
      ]);

      // Met en cache la position et les infos géocodées
      LocationCacheService.instance.updateCache(
        position: position,
        displayName: fullAddress,
        city: city,
        country: state,
      );

      delivery.Address? matchedAddress;
      final nearby = await _findNearbySavedAddress(position);
      if (nearby != null) {
        matchedAddress = delivery.Address(
          addressID: nearby.addressID,
          object: 'Livraison',
          objectID: current_userID,
          city: city.isNotEmpty ? city : (nearby.city ?? ''),
          state: state.isNotEmpty ? state : (nearby.state ?? ''),
          fullAddress: fullAddress,
          lat: position.latitude.toString(),
          long: position.longitude.toString(),
        );
      } else {
        int? savedId;
        try {
          final result = await delivery.Address.manageAddress(
            city: city,
            state: state,
            fullAddress: fullAddress,
            lat: position.latitude.toString(),
            long: position.longitude.toString(),
            object: 'Livraison',
            objectID: current_userID,
            user_roleID: current_user_role,
            nominatimPlaceId: geocoded?.placeId,
          );
          if (result is int) {
            savedId = result;
          } else if (result == 'EXISTING_ADDRESS') {
            final found = await _findNearbySavedAddress(position);
            if (found != null) {
              matchedAddress = delivery.Address(
                addressID: found.addressID,
                object: 'Livraison',
                objectID: current_userID,
                city: city.isNotEmpty ? city : (found.city ?? ''),
                state: state.isNotEmpty ? state : (found.state ?? ''),
                fullAddress: fullAddress,
                lat: position.latitude.toString(),
                long: position.longitude.toString(),
              );
            }
          }
        } catch (e) {
          debugPrint('delivery.Address.manageAddress failed: $e');
        }

        if (matchedAddress == null) {
          if (savedId != null) {
            await refreshAddresses();
            final saved = addresses.where((a) => a.addressID == savedId);
            if (saved.isNotEmpty) {
              matchedAddress = saved.first;
            }
          }
          matchedAddress ??= delivery.Address(
            addressID: savedId,
            object: 'Livraison',
            objectID: current_userID,
            city: city,
            state: state,
            fullAddress: fullAddress,
            lat: position.latitude.toString(),
            long: position.longitude.toString(),
          );
        }
      }

      if (mounted) {
        setState(() => selectedAddress = matchedAddress);
        await _refreshCartDeliveryAvailability(
          _itemsForRestaurant(ref.read(cartStateProvider)),
        );
        Toast(context, 'Position actuelle mise à jour.', true);
      }
    } catch (e) {
      debugPrint('cart._useCurrentLocation unexpected: $e');
    } finally {
      if (mounted) setState(() => _isUsingCurrentLocation = false);
    }
  }

  double _staticDeliveryFee(List<Map<String, dynamic>> cartItems) {
    if (cartItems.isEmpty) return 0.0;
    final restaurant = cartItems.first['restaurant'] as Map<String, dynamic>?;
    
    // Essayer plusieurs clés possibles pour le frais de livraison
    final fee = restaurant?['delivery_fee'] ?? 
                 restaurant?['deliveryFee'] ?? 
                 restaurant?['deliveryfee'];
                 
    debugPrint('🚚 _staticDeliveryFee: restaurant = ${restaurant?.keys.toList()}');
    debugPrint('🚚 _staticDeliveryFee: delivery_fee value = $fee');
    
    if (fee is num && fee > 0) {
      debugPrint('🚚 _staticDeliveryFee: returning fee $fee');
      return fee.toDouble();
    }
    final parsed = double.tryParse(fee?.toString() ?? '') ?? 0.0;
    if (parsed > 0) {
      debugPrint('🚚 _staticDeliveryFee: returning parsed fee $parsed');
      return parsed;
    }
    
    // Fallback par pays
    final country = _countryFromCart(cartItems);
    final countryCode = CountryUtil.canonical(country);
    final defaultFee = countryCode == CountryUtil.benin ? 500.0 : 2000.0;
    debugPrint('🚚 _staticDeliveryFee: using country default $defaultFee for $countryCode');
    return defaultFee;
  }

  Future<double> _configuredDeliveryFeeFallback(
      List<Map<String, dynamic>> cartItems) async {
    final restaurantFee = _staticDeliveryFee(cartItems);
    try {
      final response = await ParseCloudFunction('getDeliveryConfig').execute();
      if (response.success && response.result is Map) {
        final data = Map<String, dynamic>.from(response.result as Map);
        final baseFee = (data['baseFee'] as num?)?.toDouble() ?? 2000;
        final increment = (data['roundingIncrement'] as num?)?.toDouble() ?? 50;
        final minFee = (data['minFee'] as num?)?.toDouble() ?? 0;
        final roundedBase =
            (baseFee / math.max(1, increment)).ceil() * math.max(1, increment);
        return math
            .max(
              roundedBase,
              minFee > 0 ? minFee : baseFee,
            )
            .toDouble();
      }
    } catch (_) {}

    // Compatibilité avec les anciens restaurants qui possèdent encore un
    // tarif local. Si ce tarif est absent, le défaut Parse est 2 000 FCFA.
    return restaurantFee > 0 ? restaurantFee : 2000.0;
  }

  /// Devis de livraison du serveur (POST /delivery/quote) : c'est le même
  /// calcul que celui appliqué à la création de la commande, le montant
  /// affiché est donc celui qui sera facturé.
  Future<_FeeQuote> _quoteDeliveryFee(
      List<Map<String, dynamic>> cartItems) async {
    if (cartItems.isEmpty) return const _FeeQuote.needsAddress();
    final address = selectedAddress;
    if (address == null) return const _FeeQuote.needsAddress();

    final nodeToken = await SessionService.readNodeToken();
    if (nodeToken == null) {
      // Ancien compte Parse : on garde l'ancien calcul.
      return _FeeQuote.priced(await _legacyDeliveryFee(cartItems));
    }
    final addressId = address.addressID;
    if (addressId == null) return const _FeeQuote.needsAddress();

    final restaurant = cartItems.first['restaurant'] as Map<String, dynamic>?;
    final restaurantId =
        int.tryParse(restaurant?['restau_id']?.toString() ?? '');
    if (restaurantId == null) {
      return const _FeeQuote.error('Restaurant introuvable.');
    }
    try {
      final quote = await NodeOrderService.quoteDelivery(
        token: nodeToken,
        restaurantId: restaurantId,
        addressId: addressId,
      );
      if (quote['available'] != true) {
        return _FeeQuote.unavailable(
          quote['message']?.toString() ??
              'Marchand hors de votre zone de livraison.',
        );
      }
      return _FeeQuote.priced(
        (quote['deliveryFee'] as num?)?.toDouble() ?? 0,
        distanceKm: (quote['estimatedDistanceKm'] as num?)?.toDouble(),
      );
    } catch (e) {
      debugPrint('🚚 Devis de livraison impossible : $e');
      return _FeeQuote.error(
        e is NodeAuthException
            ? e.message
            : 'Impossible de calculer les frais de livraison.',
      );
    }
  }

  /// Montant utilisé au moment de commander. Le serveur recalcule de toute
  /// façon les frais à la création de la commande.
  Future<double> calculateDeliveryFee(
      List<Map<String, dynamic>> cartItems) async {
    final quote = await _quoteDeliveryFee(cartItems);
    return quote.fee ?? 0.0;
  }

  /// Ancien calcul (comptes Parse sans session Node uniquement).
  Future<double> _legacyDeliveryFee(
      List<Map<String, dynamic>> cartItems) async {
    final dlvLat = double.tryParse(selectedAddress?.lat ?? '');
    final dlvLng = double.tryParse(selectedAddress?.long ?? '');
    final resto = cartItems.first['restaurant'] as Map<String, dynamic>?;
    final rstLat = double.tryParse(resto?['restau_lat']?.toString() ?? '');
    final rstLng = double.tryParse(resto?['restau_lng']?.toString() ?? '');
    if (dlvLat != null && dlvLng != null && rstLat != null && rstLng != null) {
      try {
        final response =
            await ParseCloudFunction('calculateDeliveryFee').execute(
          parameters: {
            'restauLat': rstLat,
            'restauLng': rstLng,
            'deliveryLat': dlvLat,
            'deliveryLng': dlvLng,
          },
        );
        if (response.success && response.result is Map) {
          final data = Map<String, dynamic>.from(response.result as Map);
          if (data['success'] == true && data['delivery_fee'] != null) {
            return (data['delivery_fee'] as num).toDouble();
          }
        }
      } catch (_) {}
    }
    return _configuredDeliveryFeeFallback(cartItems);
  }

  String _deliveryFeeCacheKey(List<Map<String, dynamic>> cartItems) {
    final restaurant = cartItems.first['restaurant'] as Map<String, dynamic>?;
    return [
      restaurant?['restau_id'],
      selectedAddress?.addressID,
      selectedAddress?.lat,
      selectedAddress?.long,
    ].join('|');
  }

  void _ensureDisplayedDeliveryFee(
      List<Map<String, dynamic>> cartItems, String deliveryMode) {
    if (deliveryMode != kDeliveryOptionLivraison || cartItems.isEmpty) {
      _deliveryFeeKey = null;
      _feeQuote = null;
      _isDeliveryFeeLoading = false;
      return;
    }
    // Les adresses ne sont pas encore chargées : on attend au lieu
    // d'afficher un tarif provisoire qui changerait ensuite.
    if (!_addressesLoaded) {
      _isDeliveryFeeLoading = true;
      return;
    }

    final key = _deliveryFeeCacheKey(cartItems);
    if (_deliveryFeeKey == key && _feeQuote != null) return;

    _deliveryFeeKey = key;
    _feeQuote = null;
    _isDeliveryFeeLoading = true;
    final requestId = ++_deliveryFeeRequestId;
    _quoteDeliveryFee(cartItems).then((quote) {
      if (!mounted ||
          requestId != _deliveryFeeRequestId ||
          _deliveryFeeKey != key) {
        return;
      }
      setState(() {
        _feeQuote = quote;
        _isDeliveryFeeLoading = false;
      });
    });
  }

  String _countryFromCart(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return 'RDC';
    return items.first['meal']['country']?.toString() ?? 'RDC';
  }

  String _currencyCode(String country) => CurrencyUtil.code(country);
  String _currencySymbol(String country) => CurrencyUtil.symbol(_currencyCode(country));

  double _lineTotal(Map<String, dynamic> item) {
    final unitPrice = (item['meal']['price'] as num?)?.toDouble() ?? 0.0;
    final quantity = (item['order']['quantity'] as num?)?.toInt() ?? 0;
    final optionPrice = (item['optionPrice'] as num?)?.toDouble() ?? 0.0;
    return (unitPrice + optionPrice) * quantity;
  }

  double _subtotal(List<Map<String, dynamic>> items) =>
      items.fold(0.0, (sum, i) => sum + _lineTotal(i));

  String _formatAmount(double amount, String code, String symbol) {
    return CurrencyUtil.formatConvertedPrice(amount);
  }

  Future<void> _applyPromo({
    required List<Map<String, dynamic>> cartItems,
    required double deliveryFee,
  }) async {
    final subtotal = _subtotal(cartItems);
    final check = await PromoService.applyCode(
      rawCode: _promoController.text,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
    );
    if (!mounted) return;
    final promo = check.promo;
    if (promo == null) {
      setState(() => _appliedPromo = null);
      // Message précis du serveur (expiré, minimum, déjà utilisé…).
      Toast(context,
          check.error ?? AppLocalizations.of(context)!.cart_promo_invalid, false);
      return;
    }
    setState(() => _appliedPromo = promo);
    Toast(
        context,
        AppLocalizations.of(context)!.cart_promo_applied(promo.description),
        true);
  }

  // ═══════════════════════════════════════════════════════════════
//  REMPLACE la méthode `build` de _CartState (l'ancienne en entier).
//  + ajoute en haut de cart.dart :  import 'cart_widgets.dart';
//  + SUPPRIME les anciennes classes : _SectionTitle, _SummaryRow,
//    _CartItemCard, _QtyButton (remplacées par cart_widgets.dart).
//  Toute la logique (commande, paiement, livraison, promo) est inchangée.
// ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final allCartItems = ref.watch(cartStateProvider);
    final cartItems = _itemsForRestaurant(allCartItems);
    final basketGroups = _groupItems(allCartItems);
    final visibleGlobalIndices = <int>[];
    for (var i = 0; i < allCartItems.length; i++) {
      if (widget.restaurantId == null ||
          int.tryParse(((allCartItems[i]['restaurant']
                          as Map<String, dynamic>?)?['restau_id'])
                      ?.toString() ??
                  '') ==
              widget.restaurantId) {
        visibleGlobalIndices.add(i);
      }
    }
    final cartNotifier = ref.read(cartStateProvider.notifier);
    final selectedOption = ref.watch(selectedDeliveryProvider);
    final deliveryNotifier = ref.read(selectedDeliveryProvider.notifier);

    final l10n = AppLocalizations.of(context)!;
    final allowedOptions = [kDeliveryOptionLivraison, kDeliveryOptionEmporter];
    final safeOption = allowedOptions.contains(selectedOption)
        ? selectedOption
        : kDeliveryOptionLivraison;

    if (safeOption != selectedOption) {
      deliveryNotifier.state = safeOption;
    }

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
    _ensureDisplayedDeliveryFee(cartItems, safeOption);
    // N'afficher le montant de livraison que lorsqu'il est effectivement calculé.
    // Pendant le chargement, deliveryFee reste à null pour éviter
    // un flash visuel (ex: 500 → 1500 FCFA).
    final deliveryFee =
        safeOption == kDeliveryOptionLivraison ? _feeQuote?.fee : 0.0;
    final bool deliveryFeeLoading =
        safeOption == kDeliveryOptionLivraison && _isDeliveryFeeLoading;
    
    final cartTotal = _subtotal(cartItems);
    // Recalculée si le panier change après l'application du code.
    final reduction = _appliedPromo?.discountFor(cartTotal) ?? 0.0;
    final payableTotal =
        (cartTotal + (deliveryFee ?? 0.0) - reduction).clamp(0.0, double.infinity);
    final deliveryBlocked = _cartDeliveryAvailability != null &&
        !_cartDeliveryAvailability!.canOrder;
    final restaurantClosed =
        _cartOpeningStatus != null && !_cartOpeningStatus!.isOpen;

    if (widget.restaurantId == null && basketGroups.length > 1) {
      return _buildBasketSelection(context, basketGroups, l10n);
    }

    PreferredSizeWidget appBar(String title) => AppBar(
          backgroundColor: CC.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: Text(
            title,
            style: AppTypography.titleLarge(color: CC.ink)
                .copyWith(fontSize: 20),
          ),
        );

    if (cartItems.isEmpty) {
      return Scaffold(
        backgroundColor: CC.surface,
        appBar: appBar(l10n.cart_title),
        body: CartEmptyState(title: l10n.cart_empty, hint: l10n.cart_empty_hint),
      );
    }

    final restaurant = cartItems.first['restaurant'] as Map<String, dynamic>?;
    final restaurantName = restaurant?['name']?.toString() ?? l10n.cart_title;
    final restaurantImage = restaurant?['image']?.toString() ?? '';
    final articleCount = cartItems.fold<int>(
      0,
      (sum, item) =>
          sum +
          (((item['order'] as Map<String, dynamic>?)?['quantity'] as num?)
                  ?.toInt() ??
              0),
    );

    final canSubmit = !_isSubmittingPayment;

    return Scaffold(
      backgroundColor: CC.surface,
      appBar: appBar(l10n.cart_title),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          // ── Bannière restaurant ─────────────────────
          FadeSlideIn(
            child: CartStoreHeader(
              name: restaurantName,
              image: restaurantImage,
              subtitle: l10n.cart_basket_articles(articleCount),
            ),
          ),
          const SizedBox(height: 18),

          // ── Articles ────────────────────────────────
          ...List.generate(cartItems.length, (index) {
            final item = cartItems[index];
            final globalIndex = visibleGlobalIndices[index];
            return FadeSlideIn(
              index: index + 1,
              child: CartItemTile(
                item: item,
                country: country,
                onDelete: () {
                  cartNotifier.removeFromCart(globalIndex);
                  Toast(
                      context,
                      l10n.cart_item_deleted(item['meal']['meal_name']),
                      true);
                },
                onQuantityChanged: (qty) =>
                    cartNotifier.updateQuantity(globalIndex, qty),
              ),
            );
          }),
          const SizedBox(height: 6),

          // ── Livraison ───────────────────────────────
          FadeSlideIn(
            index: 2,
            child: CartSectionCard(
              icon: Icons.delivery_dining_rounded,
              title: l10n.cart_delivery_section,
              child: Column(
                children: [
                  CartSegmented(
                    value: safeOption,
                    onChanged: (v) => deliveryNotifier.state = v,
                    segments: [
                      CartSegment(
                        kDeliveryOptionLivraison,
                        l10n.cart_delivery_option_delivery,
                        Icons.delivery_dining_rounded,
                      ),
                      CartSegment(
                        kDeliveryOptionEmporter,
                        l10n.cart_delivery_option_takeaway,
                        Icons.shopping_bag_outlined,
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: safeOption == kDeliveryOptionLivraison
                        ? Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Column(
                              children: [
                                CartAddressBox(
                                  title: l10n.cart_delivery_to,
                                  address: selectedAddress?.fullAddress,
                                  placeholder: l10n.cart_choose_current_location,
                                  locating: _isUsingCurrentLocation,
                                  locateLabel: _isUsingCurrentLocation
                                      ? l10n.cart_location_in_progress
                                      : l10n.cart_current_location,
                                  onLocate: _isUsingCurrentLocation
                                      ? null
                                      : _useCurrentLocation,
                                  onEdit: _isUsingCurrentLocation
                                      ? null
                                      : _showAddressPicker,
                                  editTooltip: selectedAddress != null
                                      ? l10n.cart_change_address
                                      : l10n.cart_choose_address,
                                  savedLabel: l10n.cart_location_saved,
                                ),
                                if (deliveryBlocked) ...[
                                  const SizedBox(height: 10),
                                  DeliveryUnavailableBanner(
                                    onTap: () =>
                                        showDeliveryUnavailableSheet(context),
                                  ),
                                ],
                                if (restaurantClosed) ...[
                                  const SizedBox(height: 10),
                                  RestaurantClosedBanner(
                                    status: _cartOpeningStatus!,
                                    onTap: () =>
                                        showRestaurantClosedSheet(context),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Code promo ──────────────────────────────
          FadeSlideIn(
            index: 3,
            child: CartSectionCard(
              icon: Icons.local_offer_rounded,
              title: l10n.cart_promo_section,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _promoController,
                          textCapitalization: TextCapitalization.characters,
                          style: AppTypography.bodyLarge(color: CC.ink),
                          decoration: InputDecoration(
                            hintText: l10n.cart_promo_hint,
                            filled: true,
                            fillColor: CC.surfaceWarm,
                            prefixIcon: Icon(Icons.confirmation_number_outlined,
                                size: 20, color: CC.brand),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              borderSide:
                                  BorderSide(color: CC.brand, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () => _applyPromo(
                              cartItems: cartItems, deliveryFee: deliveryFee ?? 0.0),
                          child: Text(l10n.cart_promo_apply),
                        ),
                      ),
                    ],
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _appliedPromo != null
                        ? CartPromoBadge(
                            key: ValueKey(_appliedPromo!.code),
                            text:
                                '${_appliedPromo!.code} : ${_appliedPromo!.description}',
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Résumé ──────────────────────────────────
          FadeSlideIn(
            index: 4,
            child: CartSectionCard(
              icon: Icons.receipt_long_rounded,
              title: l10n.cart_summary_section,
              child: AnimatedBuilder(
                animation: CurrencyService.instance,
                builder: (_, __) => Column(
                  children: [
                    CartSummaryRow(
                        l10n.subtotal, _formatAmount(cartTotal, cc, cs)),
                    if (safeOption == kDeliveryOptionLivraison)
                      CartSummaryRow(
                        _feeQuote?.distanceKm != null
                            ? '${l10n.deliveryFee} · '
                                '${_feeQuote!.distanceKm!.toStringAsFixed(1)} km'
                            : l10n.deliveryFee,
                        deliveryFeeLoading
                            ? '...'
                            : _feeQuote?.ok == true
                                ? CurrencyUtil.formatConvertedPrice(
                                    _feeQuote!.fee!)
                                : _feeQuote?.needsAddress == true
                                    ? l10n.cart_choose_address
                                    : '—',
                        valueColor: _feeQuote?.ok == true ? null : CC.inkMuted,
                      ),
                    if (safeOption == kDeliveryOptionLivraison &&
                        !deliveryFeeLoading &&
                        _feeQuote?.message != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          _feeQuote!.message!,
                          style: AppTypography.bodySmall(
                            color: AppColors.resolve(
                                AppColors.error, AppDarkColors.error),
                          ),
                        ),
                      ),
                    if (_appliedPromo != null)
                      CartSummaryRow(
                        l10n.cart_discount,
                        '- ${_formatAmount(reduction, cc, cs)}',
                        valueColor: CC.success,
                      ),
                    const CartDashedDivider(),
                    CartTotalRow(
                        l10n.total,
                        deliveryFeeLoading
                            ? '...'
                            : _formatAmount(payableTotal, cc, cs)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Paiement ────────────────────────────────
          FadeSlideIn(
            index: 5,
            child: CartSectionCard(
              icon: Icons.account_balance_wallet_rounded,
              title: l10n.cart_payment_section,
              child: Column(
                children: [
                  _PaymentRowTile(
                    icon: Icons.payments_outlined,
                    label: l10n.cart_payment_cod,
                    subtitle: safeOption == kDeliveryOptionLivraison
                        ? l10n.cart_payment_cod_hint
                        : l10n.cart_payment_cod_pickup_hint,
                    selected: _payMode == _PayMode.cash,
                    onTap: () => setState(() => _payMode = _PayMode.cash),
                  ),
                  const SizedBox(height: 10),
                  _PaymentRowTile(
                    icon: Icons.phone_android_rounded,
                    label: l10n.cart_payment_fedapay,
                    subtitle: l10n.cart_payment_mobile_money_hint,
                    selected: _payMode == _PayMode.mobileMoney,
                    onTap: () =>
                        setState(() => _payMode = _PayMode.mobileMoney),
                  ),
                  const SizedBox(height: 10),
                  _PaymentRowTile(
                    icon: Icons.account_balance_wallet_rounded,
                    label: l10n.cart_payment_wallet,
                    subtitle: l10n.cart_payment_wallet_hint,
                    selected: _payMode == _PayMode.wallet,
                    onTap: () => setState(() => _payMode = _PayMode.wallet),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Bouton Commander collant ─────────────────────
      bottomNavigationBar: AnimatedBuilder(
        animation: CurrencyService.instance,
        builder: (_, __) => CartCheckoutBar(
          loading: _isSubmittingPayment,
          totalLabel: l10n.total,
          totalValue: deliveryFeeLoading
              ? '...'
              : CurrencyUtil.formatConvertedPrice(payableTotal),
          methodLabel: switch (_payMode) {
            _PayMode.cash => l10n.cart_payment_cod,
            _PayMode.mobileMoney => l10n.cart_payment_fedapay,
            _PayMode.wallet => l10n.cart_payment_wallet,
          },
          label: _isSubmittingPayment
              ? l10n.cart_processing
              : (_payMode == _PayMode.cash
                  ? l10n.cart_checkout_order
                  : l10n.cart_checkout_pay),
          onPressed: canSubmit && !deliveryFeeLoading
              ? () async {
                  if (deliveryBlocked) {
                    await showDeliveryUnavailableSheet(context);
                    return;
                  }
                  if (restaurantClosed) {
                    await showRestaurantClosedSheet(context);
                    return;
                  }
                  switch (_payMode) {
                    case _PayMode.wallet:
                      await _handleWalletPayment();
                      break;
                    case _PayMode.mobileMoney:
                      await _handleOnlinePayment();
                      break;
                    case _PayMode.cash:
                      await _handleOrder();
                      break;
                  }
                }
              : null,
        ),
      ),
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
        onAddressSelected: (selected) async {
          setState(() => selectedAddress = selected);
          await _refreshCartDeliveryAvailability(
              _itemsForRestaurant(ref.read(cartStateProvider)));
        },
      ),
    );
  }

  // ── Logique métier (inchangée) ──────────────────────────
  Future<bool> _checkAddressInZone(delivery.Address address) async {
    final l10n = AppLocalizations.of(context)!;
    if (await SessionService.hasNodeSession()) {
      // Le devis Node est la source de vérité et revalidera l'adresse dans
      // createOrder. Cela évite de consulter l'ancien Cloud Code Parse.
      return true;
    }
    final lat = double.tryParse(address.lat ?? '');
    final lng = double.tryParse(address.long ?? '');
    if (lat == null || lng == null) {
      Toast(context, l10n.cart_address_out_of_zone_detail, false);
      return false;
    }
    try {
      final fn = ParseCloudFunction('checkAddressInZone');
      final response = await fn.execute(parameters: {
        'lat': lat,
        'lng': lng,
        'cityID': _userCityId,
        'address': address.fullAddress,
      });
      if (response.success && response.result != null) {
        final data = response.result as Map<String, dynamic>;
        if (data['deliverable'] == true) return true;
      }
    } catch (_) {}
    Toast(context, l10n.cart_address_out_of_zone, false);
    return false;
  }

  // ═══════════════════════════════════════════════════════════
  //  Passage de commande — étapes communes aux trois modes
  // ═══════════════════════════════════════════════════════════

  /// Vérifications communes (adresse, zone, disponibilité, horaires) puis
  /// calcul des montants. Retourne null si la commande ne peut pas partir ;
  /// le client a alors déjà été informé.
  Future<_Checkout?> _prepareCheckout() async {
    final option = ref.read(selectedDeliveryProvider);
    final l10n = AppLocalizations.of(context)!;
    if (option == kDeliveryOptionLivraison && selectedAddress == null) {
      Toast(context, l10n.cart_choose_address_warning, false);
      return null;
    }
    if (option == kDeliveryOptionLivraison && selectedAddress != null) {
      final inZone = await _checkAddressInZone(selectedAddress!);
      if (!inZone || !mounted) return null;
    }
    final cartItems = _itemsForRestaurant(ref.read(cartStateProvider));
    if (cartItems.isEmpty) return null;
    await _refreshCartDeliveryAvailability(cartItems);
    if (!mounted) return null;
    if (_cartDeliveryAvailability != null &&
        !_cartDeliveryAvailability!.canOrder) {
      await showDeliveryUnavailableSheet(context);
      return null;
    }
    if (_cartOpeningStatus != null && !_cartOpeningStatus!.isOpen) {
      await showRestaurantClosedSheet(context);
      return null;
    }
    final items = List<Map<String, dynamic>>.from(cartItems);
    final country = _countryFromCart(items);
    var fee = 0.0;
    if (option == kDeliveryOptionLivraison) {
      final quote = await _quoteDeliveryFee(items);
      if (!mounted) return null;
      if (!quote.ok) {
        Toast(
          context,
          quote.needsAddress
              ? l10n.cart_choose_address_warning
              : (quote.message ?? l10n.cart_order_error_retry),
          false,
        );
        return null;
      }
      fee = quote.fee!;
    }
    final restaurantId = int.tryParse(
            (items.first['restaurant'] as Map)['restau_id'].toString()) ??
        0;
    return _Checkout(
      option: option,
      items: items,
      country: country,
      currencyCode: _currencyCode(country),
      fee: fee,
      discount: _appliedPromo?.discountFor(_subtotal(items)) ?? 0.0,
      restaurantId: restaurantId,
    );
  }

  Future<String?> _createOrderFor(_Checkout c) => createOrder(
        c.items,
        c.fee,
        c.isDelivery ? selectedAddress?.addressID : null,
        null,
        ref,
        currencyCode: c.currencyCode,
        country: c.country,
        reduction: c.discount,
        promoCode: _appliedPromo?.code,
        cityID: _userCityId,
        deliveryMode: c.option,
      );

  /// Empreinte du panier : une commande Mobile Money impayée n'est
  /// réutilisée que si rien n'a changé (articles, mode, adresse, promo).
  String _checkoutSignature(_Checkout c) {
    final lines = c.items.map((item) {
      final meal = item['meal'] as Map;
      final order = item['order'] as Map;
      return '${meal['mealID']}x${order['quantity']}'
          '${item['optionDetails'] ?? ''}';
    }).join(',');
    final address = c.isDelivery ? selectedAddress?.addressID : null;
    return '${c.restaurantId}|$lines|${c.option}|$address|'
        '${_appliedPromo?.code ?? ''}';
  }

  /// Suite commune après une commande acceptée : notification du
  /// restaurateur, vidage du panier, page de confirmation.
  Future<void> _completeOrder(
    _Checkout c,
    String commandeId, {
    required String paymentProvider,
    bool paymentPending = false,
  }) async {
    final restaurantsList = await Restaurant.fetchRestaurantsFromDB();
    final currentRestaurant =
        Restaurant.getRestaurantByRestaurantId(restaurantsList, c.restaurantId);
    if (currentRestaurant != null) {
      final total = _subtotal(c.items) + c.fee - c.discount;
      NotificationService.sendOrderNotificationToRestaurateur(
        restaurateurId: currentRestaurant.userID,
        restaurantName: currentRestaurant.name,
        totalAmount: total.clamp(0.0, double.infinity),
        orderId: int.tryParse(commandeId),
        currencySymbol: CurrencyUtil.symbol(CurrencyUtil.code(c.country)),
      );
    }
    await ref
        .read(cartStateProvider.notifier)
        .clearRestaurantCart(c.restaurantId);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OrderConfirmationPage(
          commandeId: commandeId,
          paymentPending: paymentPending,
          paymentProvider: paymentProvider,
        ),
      ),
    );
  }

  /// Message lisible pour une erreur du backend ou du réseau.
  String _errorMessage(Object error, AppLocalizations l10n) {
    if (error is NodeAuthException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    if (error is WalletException && error.message.trim().isNotEmpty) {
      return error.message;
    }
    return l10n.cart_order_error_retry;
  }

  // ── 1. À la livraison (espèces) ──────────────────────────
  Future<void> _handleOrder() async {
    final l10n = AppLocalizations.of(context)!;
    final checkout = await _prepareCheckout();
    if (checkout == null || !mounted) return;

    setState(() => _isSubmittingPayment = true);
    try {
      final commandeId = await _createOrderFor(checkout);
      if (!mounted) return;
      if (commandeId == null || commandeId.isEmpty) {
        Toast(context, l10n.cart_order_failed, false);
        return;
      }
      Toast(context, l10n.cart_order_confirm_message, true);
      await _completeOrder(
        checkout,
        commandeId,
        paymentProvider: 'confirmed_cash',
      );
    } catch (e) {
      if (mounted) Toast(context, _errorMessage(e, l10n), false);
    } finally {
      if (mounted) setState(() => _isSubmittingPayment = false);
    }
  }

  /// SnackBar « Solde insuffisant » avec action « Recharger ».
  void _showInsufficientBalance(String message) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          duration: const Duration(seconds: 8),
          content: Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: l10n.cart_wallet_topup,
            textColor: Colors.white,
            onPressed: () {
              if (!mounted) return;
              // Ouvre directement la recharge ; au retour, le client relance
              // « Payer » depuis le panier, qui est conservé.
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WalletScreen(openTopUpOnStart: true),
                ),
              );
            },
          ),
        ),
      );
  }

  static bool _isInsufficientBalance(Object error) {
    final message = error is NodeAuthException
        ? error.message
        : (error is WalletException ? error.message : '');
    return message.toLowerCase().contains('insuffisant') ||
        message.toLowerCase().contains('insufficient');
  }

  // ── 2. Portefeuille ──────────────────────────────────────
  /// Avec une session Node, le backend débite le portefeuille dans la même
  /// transaction que la création de la commande (ou refuse tout si le
  /// solde manque) : rien d'autre à faire. L'ancien flux Parse crée la
  /// commande puis la règle via /pay-wallet.
  Future<void> _handleWalletPayment() async {
    final l10n = AppLocalizations.of(context)!;
    final checkout = await _prepareCheckout();
    if (checkout == null || !mounted) return;

    setState(() => _isSubmittingPayment = true);
    try {
      final hasNodeSession = await SessionService.hasNodeSession();
      String? commandeId;
      if (hasNodeSession) {
        commandeId = await _createOrderFor(checkout);
      } else {
        commandeId = _walletPendingOrderId ?? await _createOrderFor(checkout);
        if (commandeId != null) {
          _walletPendingOrderId = commandeId;
          await WalletService.payOrderWithWallet(commandeId);
        }
      }
      if (!mounted) return;
      if (commandeId == null || commandeId.isEmpty) {
        Toast(context, l10n.cart_order_failed, false);
        return;
      }
      _walletPendingOrderId = null;
      Toast(context, l10n.cart_order_confirm_message, true);
      await _completeOrder(checkout, commandeId, paymentProvider: 'wallet');
    } catch (e) {
      if (!mounted) return;
      if (_isInsufficientBalance(e)) {
        _showInsufficientBalance(_errorMessage(e, l10n));
      } else {
        Toast(context, _errorMessage(e, l10n), false);
      }
    } finally {
      if (mounted) setState(() => _isSubmittingPayment = false);
    }
  }

  // ── 3. Mobile Money (Nyole) ──────────────────────────────
  /// Crée la commande (statut AWAITING_PAYMENT), ouvre la page Nyole et ne
  /// vide le panier qu'une fois le retour « succès » reçu. Si le client
  /// annule, le panier est conservé et la même commande est réutilisée au
  /// prochain essai tant que le panier n'a pas changé.
  Future<void> _handleOnlinePayment() async {
    final l10n = AppLocalizations.of(context)!;
    final checkout = await _prepareCheckout();
    if (checkout == null || !mounted) return;

    setState(() => _isSubmittingPayment = true);
    try {
      final signature = _checkoutSignature(checkout);
      final reusable = _onlinePending?.signature == signature;
      String? commandeId = reusable ? _onlinePending!.orderId : null;
      String? orderUuid = reusable ? _onlinePending!.orderUuid : null;

      if (commandeId == null) {
        _lastCreatedOrderUuid = null;
        commandeId = await _createOrderFor(checkout);
        if (!mounted) return;
        if (commandeId == null || commandeId.isEmpty) {
          Toast(context, l10n.cart_order_failed, false);
          return;
        }
        orderUuid = _lastCreatedOrderUuid;
        _onlinePending = _PendingOnlineOrder(
          orderId: commandeId,
          orderUuid: orderUuid,
          signature: signature,
        );
      }

      final data = await _initializeOnlinePayment(commandeId, orderUuid);
      if (!mounted) return;
      final paymentUrl = data?['paymentUrl']?.toString();
      if (paymentUrl == null || paymentUrl.isEmpty) {
        Toast(
          context,
          data == null ? l10n.cart_payment_online_error : l10n.cart_payment_url_error,
          false,
        );
        return;
      }

      final paid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => NyolePaymentPage(
            paymentUrl: paymentUrl,
            orderId: commandeId!,
          ),
        ),
      );
      if (!mounted) return;

      if (paid == true) {
        _onlinePending = null;
        // Le retour « succès » n'est pas une preuve : la commande passe à
        // « payée » quand le webhook Nyole est vérifié côté serveur.
        await _completeOrder(
          checkout,
          commandeId,
          paymentProvider: 'awaiting_payment',
          paymentPending: true,
        );
      } else {
        Toast(context, l10n.cart_payment_not_completed, false);
      }
    } catch (e) {
      if (mounted) Toast(context, _errorMessage(e, l10n), false);
    } finally {
      if (mounted) setState(() => _isSubmittingPayment = false);
    }
  }

  /// Ouvre (ou réutilise) la session de paiement Nyole de la commande.
  Future<Map<String, dynamic>?> _initializeOnlinePayment(
    String commandeId,
    String? orderUuid,
  ) async {
    final nodeToken = await SessionService.readNodeToken();
    if (nodeToken != null) {
      var uuid = orderUuid;
      if (uuid == null || uuid.isEmpty) {
        // Repli : retrouver l'UUID dans la liste des commandes du client.
        final orders = await NodeOrderService.listMine(
          token: nodeToken,
          userId: current_userID,
          includeLines: false,
        );
        for (final order in orders) {
          if (order['orderId']?.toString() == commandeId) {
            uuid = order['id']?.toString();
            break;
          }
        }
      }
      if (uuid == null || uuid.isEmpty) {
        throw const NodeAuthException('Commande introuvable sur le serveur.');
      }
      return NodeOrderService.initializeNyole(
        token: nodeToken,
        orderUuid: uuid,
      );
    }

    final session = await SessionService.readSession();
    final usersList = await Users.fetchUsersFromDB();
    final currentUser = Users.getUsersByUserId(usersList, session.userId);
    final response =
        await ParseCloudFunction('createNyoleCheckout').execute(parameters: {
      'commandeID': int.tryParse(commandeId),
      'customerName':
          '${currentUser?.firstname ?? ""} ${currentUser?.lastname ?? ""}',
      'customerEmail': currentUser?.email ?? '',
      'customerPhone': currentUser?.telephone?.toString() ?? '',
    });
    if (response.success && response.result is Map) {
      return Map<String, dynamic>.from(response.result as Map);
    }
    return null;
  }

  int get _userCityId => _cityID;

  /// Code attendu par le backend Node (POST /orders).
  String get _paymentMethodCode {
    switch (_payMode) {
      case _PayMode.cash:
        return 'CASH';
      case _PayMode.mobileMoney:
        return 'NYOLE';
      case _PayMode.wallet:
        return 'WALLET';
    }
  }

  Future<String?> createOrder(
    List<dynamic> cartItems,
    double deliveryFee,
    int? idAdresse,
    String? idPaiement,
    WidgetRef ref, {
    required String currencyCode,
    required String country,
    required double reduction,
    required String deliveryMode,
    String? promoCode,
    int cityID = 1,
  }) async {
    final nodeToken = await SessionService.readNodeToken();
    if (nodeToken != null) {
      final restaurantId = int.tryParse(
        (cartItems.first['restaurant'] as Map)['restau_id'].toString(),
      );
      if (restaurantId == null) return null;
      final lines = cartItems.map<Map<String, dynamic>>((item) {
        final meal = Map<String, dynamic>.from(item['meal'] as Map);
        final order = Map<String, dynamic>.from(item['order'] as Map);
        return {
          'dishId': meal['mealID'],
          'quantity': order['quantity'],
          if (item['optionDetails'] is Map) 'options': item['optionDetails'],
        };
      }).toList();
      final result = await NodeOrderService.create(
        token: nodeToken,
        userId: current_userID,
        restaurantId: restaurantId,
        lines: lines,
        deliveryMode: deliveryMode,
        addressId: idAdresse,
        paymentMethod: idPaiement ?? _paymentMethodCode,
        reduction: reduction,
        promoCode: promoCode,
        cityId: cityID,
        currency: currencyCode,
        country: country,
      );
      final order = result['order'];
      if (order is! Map) return null;
      final normalizedOrder = Map<String, dynamic>.from(order);
      _lastCreatedOrderUuid = normalizedOrder['id']?.toString();
      final commande = NodeOrderService.toLegacyCommande(normalizedOrder);
      await DatabaseHelper.createCommande(commande);

      // Synchroniser les lignes de commande localement
      final orderLines = result['lines'] as List<dynamic>?;
      if (orderLines != null) {
        for (final line in orderLines) {
          if (line is Map<String, dynamic>) {
            final ligne = LigneCommande(
              ligneID: line['lineId']?.toString() ?? line['id']?.toString() ?? '',
              commandeID: commande.commandeID.toString(),
              platID: int.tryParse(line['dishId']?.toString() ?? '') ?? 0,
              quantite: int.tryParse(line['quantity']?.toString() ?? '') ?? 1,
              prixUnitaire: double.tryParse(line['unitPrice']?.toString() ?? '') ?? 0.0,
              reduction: double.tryParse(line['reduction']?.toString() ?? '') ?? 0.0,
              nomPlat: line['dishName']?.toString(),
            );
            await DatabaseHelper.createLigneCommande(ligne);
          }
        }
      }

      return (normalizedOrder['orderId'] ?? normalizedOrder['commandeID'] ?? '')
          .toString();
    }

    final restaurantsList = await Restaurant.fetchRestaurantsFromDB();
    final restaurantId = cartItems.first['restaurant']['restau_id'];
    final currentRestaurant =
        Restaurant.getRestaurantByRestaurantId(restaurantsList, restaurantId);

    final subtotal = _subtotal(List<Map<String, dynamic>>.from(cartItems));
    final totalAmount =
        (subtotal + deliveryFee - reduction).clamp(0.0, double.infinity);

    final items = cartItems.map((item) {
      final unitPrice = ((item["meal"]["price"] as num?)?.toDouble() ?? 0.0) +
          ((item["optionPrice"] as num?)?.toDouble() ?? 0.0);
      return {
        "platID": item["meal"]["mealID"],
        "id_plat": item["meal"]["mealID"],
        "nomPlat": item["meal"]["meal_name"],
        "quantite": item["order"]["quantity"],
        "prixUnitaire": unitPrice,
        "prix_unitaire": unitPrice,
        "prix": unitPrice,
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
      };
    }).toList();
    final params = <String, dynamic>{
      "userID": current_userID,
      "restaurantId": restaurantId,
      "id_restaurateur": currentRestaurant?.userID,
      "currency": currencyCode,
      "country": country,
      "fraisLivraison": deliveryFee,
      "deliveryMode": deliveryMode,
      "reduction": reduction,
      "subtotalAmount": subtotal,
      "totalAmount": totalAmount,
      "items": items,
      if (idPaiement != null) "moyenPaiementID": idPaiement,
      "cityID": cityID,
      if (promoCode != null) "promo_code": promoCode,
      if (idAdresse != null) "id_adresse_livraison": idAdresse,
    };

    final cloudFunction = ParseCloudFunction('createOrder');
    final response = await cloudFunction.execute(parameters: params);
    if (response.success && response.result != null) {
      final data = response.result as Map<String, dynamic>;
      final commandeId = data['commandeID'];
      if (data['success'] == true && commandeId != null) {
        await Commande.refreshLocalCommandes();
        return commandeId.toString();
      }
    }
    return null;
  }
}

class OrderConfirmationPage extends StatelessWidget {
  final String commandeId;
  final bool paymentPending;

  /// Valeur `paymentProvider` de la commande (awaiting_payment, confirmed_cash,
  /// wallet) : affichée sous forme de libellé lisible, masquée si absente.
  final String? paymentProvider;

  const OrderConfirmationPage({
    super.key,
    required this.commandeId,
    this.paymentPending = false,
    this.paymentProvider,
  });

  /// Le panier est un onglet de CurvedNavigationUser : le `pushReplacement`
  /// qui ouvre cette page a remplacé tout ce shell, il ne reste rien dessous.
  /// On reconstruit donc le shell sur l'onglet Accueil en vidant la pile.
  Future<void> _goHome(BuildContext context) async {
    final session = await SessionService.readSession();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => CurvedNavigationUser(
          specified_index: 0,
          country: session.country,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final cardBg = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final line = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final warm =
        AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);
    final payLabel = paymentProviderLabel(paymentProvider);

    final content = SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Icône ──
              FadeSlideIn(
                index: 0,
                child: paymentPending
                    ? Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.hourglass_top_rounded,
                            size: 56, color: Colors.orange),
                      )
                    : const AnimatedSuccessCheck(),
              ),
              const SizedBox(height: 28),

              // ── Titre + message ──
              FadeSlideIn(
                index: 1,
                child: Column(
                  children: [
                    Text(
                      paymentPending
                          ? l10n.pending
                          : l10n.cart_order_confirm_message,
                      style: AppTypography.headlineMedium(color: ink),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      paymentPending
                          ? l10n.tracking_pending_label
                          : l10n.cart_order_confirmed_message(commandeId),
                      style: AppTypography.bodyLarge(color: muted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Récapitulatif ──
              FadeSlideIn(
                index: 2,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: line.withValues(alpha: 0.7)),
                    boxShadow: [AppShadows.subtle],
                  ),
                  child: Column(
                    children: [
                      _ConfirmRow(
                        icon: Icons.receipt_long_rounded,
                        label: 'Commande',
                        value: '#$commandeId',
                      ),
                      if (payLabel != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Divider(
                              height: 1, color: line.withValues(alpha: 0.6)),
                        ),
                        _ConfirmRow(
                          icon: paymentProviderIcon(paymentProvider),
                          label: 'Mode de paiement',
                          value: payLabel,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── Actions ──
              FadeSlideIn(
                index: 3,
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            brand,
                            Color.lerp(brand, Colors.black, 0.18)!,
                          ]),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          boxShadow: [
                            BoxShadow(
                              color: brand.withValues(alpha: 0.30),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderTrackingPage(
                                    highlightedCommandeId: commandeId),
                              ),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.delivery_dining_rounded,
                                      color: Colors.white, size: 22),
                                  const SizedBox(width: 10),
                                  Text(
                                    l10n.cart_track_order,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () => _goHome(context),
                        icon: const Icon(Icons.home_rounded),
                        label: const Text("Retour à l'accueil"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: brand,
                          backgroundColor: warm,
                          side: BorderSide(color: line),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // le bouton « retour » du téléphone ramène à l'accueil (sans quoi il
    // fermerait l'application, la page étant la seule de la pile)
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome(context);
      },
      child: Scaffold(
        backgroundColor:
            AppColors.resolve(AppColors.surface, AppDarkColors.surface),
        body:
            paymentPending ? content : OrderConfettiCelebration(child: content),
      ),
    );
  }
}

/// Ligne « icône · libellé · valeur » du récapitulatif de confirmation.
class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.resolve(
                AppColors.brandSurface, AppDarkColors.brandSurface),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, color: brand, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodyMedium(
                color:
                    AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted)),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelLarge(
                    color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))
                .copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
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
      final response = await ParseCloudFunction('geocodeDeliveryAddress')
          .execute(parameters: {'query': fullAddress});
      if (!response.success || response.result is! Map) {
        Toast(context, AppLocalizations.of(context)!.cart_address_not_found,
            false);
        return;
      }
      final geocoded = Map<String, dynamic>.from(response.result as Map);
      final lat = double.tryParse(geocoded['latitude']?.toString() ?? '');
      final long = double.tryParse(geocoded['longitude']?.toString() ?? '');
      if (geocoded['success'] != true || lat == null || long == null) {
        Toast(context, AppLocalizations.of(context)!.cart_address_not_found,
            false);
        return;
      }

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
          "addressID": result,
          "object": "Livraison",
          "objectID": widget.userId,
          "city": city,
          "state": country,
          "fullAddress": fullAddress,
          "lat": lat,
          "long": long,
        };
        selectedAddressId = result;
        selectedAddress = delivery.Address.fromMap(newAddr);

        streetCtrl.clear();
        postalCtrl.clear();
        cityCtrl.clear();
        countryCtrl.clear();

        setState(() => showForm = false);
        await widget.onRefreshAddresses();
        Toast(context, AppLocalizations.of(context)!.cart_address_saved, true);
        widget.onAddressSelected(selectedAddress!);
        Navigator.pop(context);
      }
    } catch (_) {
      Toast(context, AppLocalizations.of(context)!.cart_address_invalid, false);
    }
  }

  Future<void> deleteAddress(int id, String object) async {
    if (object != "Livraison") {
      Toast(context,
          AppLocalizations.of(context)!.cart_address_delete_forbidden, false);
      return;
    }
    final result = await delivery.Address.deleteAddress(
      addressID: id,
      object: object,
      objectID: widget.userId,
    );
    if (result == "success") {
      await widget.onRefreshAddresses();
      Toast(context, AppLocalizations.of(context)!.cart_address_deleted, true);
      setState(() {
        widget.filteredAddresses.removeWhere((a) => a['addressID'] == id);
        if (selectedAddressId == id) selectedAddressId = null;
      });
      Navigator.pop(context);
    } else {
      Toast(context, AppLocalizations.of(context)!.cart_address_delete_error,
          false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            children: [
              // Poignée
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      AppColors.resolve(AppColors.border, AppDarkColors.border),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 20),
              Text(l10n.cart_your_addresses,
                  style: AppTypography.titleMedium(
                    color: AppColors.resolve(AppColors.ink, AppDarkColors.ink),
                  )),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    ...widget.filteredAddresses.map((addr) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AppColors.resolve(
                                AppColors.card, AppDarkColors.card),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: selectedAddressId == addr['addressID']
                                  ? AppColors.resolve(
                                      AppColors.brand, AppDarkColors.brand)
                                  : AppColors.resolve(
                                      AppColors.border, AppDarkColors.border),
                              width: selectedAddressId == addr['addressID']
                                  ? 1.5
                                  : 0.5,
                            ),
                          ),
                          child: ListTile(
                            title: Text(addr['fullAddress'] ?? ''),
                            leading: Radio<int>(
                              value: addr['addressID'],
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
                        label: Text(l10n.cart_new_address),
                      ),
                    if (showForm) ...[
                      const SizedBox(height: 8),
                      _addrField(l10n.street, streetCtrl),
                      _addrField(l10n.postal_code, postalCtrl,
                          keyboardType: TextInputType.number),
                      _addrField(l10n.city, cityCtrl),
                      _addrField(l10n.country, countryCtrl),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: addNewAddress,
                        child: Text(l10n.save),
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
                  child: Text(l10n.validate),
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

// ═══════════════════════════════════════════════════════════
// Option de paiement (ligne pleine largeur + bouton radio) — les 3 modes
// partagent ce même composant pour être parfaitement alignés.
// ═══════════════════════════════════════════════════════════
class _PaymentRowTile extends StatelessWidget {
  const _PaymentRowTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: selected ? CC.brandSurface : CC.card,
          borderRadius: radius,
          border: Border.all(
            color: selected ? CC.brand : CC.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: selected
                          ? CC.brand
                          : CC.brand.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon,
                        size: 21, color: selected ? Colors.white : CC.brand),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: AppTypography.titleSmall(color: CC.ink)
                              .copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppTypography.bodySmall(color: CC.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      key: ValueKey(selected),
                      size: 22,
                      color: selected ? CC.brand : CC.border,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
