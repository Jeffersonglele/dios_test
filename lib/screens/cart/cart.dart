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
import '../../services/delivery_shipping_service.dart';
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
import '../orders/order_tracking_page.dart';
import '../payment/nyole_payment_page.dart';

class Cart extends ConsumerStatefulWidget {
  const Cart({super.key, this.restaurantId});

  final int? restaurantId;

  @override
  ConsumerState<Cart> createState() => _CartState();
}

class _CartState extends ConsumerState<Cart> {
  final TextEditingController _promoController = TextEditingController();

  PromoApplication? _appliedPromo;
  bool _isSubmittingPayment = false;
  bool _payOnline = false;
  bool _isUsingCurrentLocation = false;
  DeliveryAvailability? _cartDeliveryAvailability;
  RestaurantOpeningStatus? _cartOpeningStatus;
  double? _calculatedDeliveryFee;
  String? _deliveryFeeKey;
  int _deliveryFeeRequestId = 0;

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

  Future<double> calculateDeliveryFee(
      List<Map<String, dynamic>> cartItems) async {
    if (cartItems.isEmpty) return _staticDeliveryFee(cartItems);
    
    debugPrint('🚚 Calculating delivery fee...');
    debugPrint('🚚 Selected address: ${selectedAddress?.addressID}');
    
    // Try new shipping service with GPS coordinates (this should work even without Node token)
    if (selectedAddress != null) {
      final dlvLat = double.tryParse(selectedAddress!.lat ?? '');
      final dlvLng = double.tryParse(selectedAddress!.long ?? '');
      debugPrint('🚚 Address coords: lat=$dlvLat, lng=$dlvLng');
      if (dlvLat != null && dlvLng != null) {
        final resto = cartItems.first['restaurant'] as Map<String, dynamic>?;
        if (resto != null) {
          final restaurantId = int.tryParse(resto['restau_id']?.toString() ?? '');
          final rstLat = double.tryParse(resto['restau_lat']?.toString() ?? '');
          final rstLng = double.tryParse(resto['restau_lng']?.toString() ?? '');
          debugPrint('🚚 Restaurant coords: lat=$rstLat, lng=$rstLng');
          
          if (restaurantId != null && rstLat != null && rstLng != null) {
            try {
              debugPrint('🚚 Trying new shipping service...');
              final quote = await DeliveryShippingService.calculateShipping(
                restaurantId: restaurantId,
                deliveryLat: dlvLat,
                deliveryLng: dlvLng,
              );
              debugPrint('🚚 Shipping service quote: $quote');
              if (quote != null) {
                return quote.shippingFee;
              }
            } catch (e) {
              debugPrint('🚚 Shipping service error: $e');
            }
          }
        }
      }
    }
    
    // Try Node.js backend
    final nodeToken = await SessionService.readNodeToken();
    if (nodeToken != null && selectedAddress?.addressID != null) {
      final restaurant = cartItems.first['restaurant'] as Map<String, dynamic>?;
      final restaurantId =
          int.tryParse(restaurant?['restau_id']?.toString() ?? '');
      debugPrint('🚚 Trying Node.js quote: restaurantId=$restaurantId, addressId=${selectedAddress?.addressID}');
      if (restaurantId != null) {
        try {
          final quote = await NodeOrderService.quoteDelivery(
            token: nodeToken,
            restaurantId: restaurantId,
            addressId: selectedAddress!.addressID!,
          );
          debugPrint('🚚 Node.js quote response: $quote');
          if (quote['available'] == true) {
            return (quote['deliveryFee'] as num?)?.toDouble() ?? 0;
          }
        } catch (e) {
          debugPrint('🚚 Node.js quote error: $e');
        }
      }
    }
    
    if (selectedAddress == null) {
      debugPrint('🚚 No address selected, using fallback');
      return _configuredDeliveryFeeFallback(cartItems);
    }

    final dlvLat = double.tryParse(selectedAddress!.lat ?? '');
    final dlvLng = double.tryParse(selectedAddress!.long ?? '');
    if (dlvLat == null || dlvLng == null) {
      debugPrint('🚚 Invalid address coords, using fallback');
      return _configuredDeliveryFeeFallback(cartItems);
    }

    final resto = cartItems.first['restaurant'] as Map<String, dynamic>?;
    if (resto == null) return _configuredDeliveryFeeFallback(cartItems);

    final rstLat = double.tryParse(resto['restau_lat']?.toString() ?? '');
    final rstLng = double.tryParse(resto['restau_lng']?.toString() ?? '');
    if (rstLat == null || rstLng == null) {
      debugPrint('🚚 Invalid restaurant coords, using fallback');
      return _configuredDeliveryFeeFallback(cartItems);
    }

    try {
      debugPrint('🚚 Trying Parse Cloud Function...');
      final fn = ParseCloudFunction('calculateDeliveryFee');
      final response = await fn.execute(parameters: {
        'restauLat': rstLat,
        'restauLng': rstLng,
        'deliveryLat': dlvLat,
        'deliveryLng': dlvLng,
      });
      if (response.success && response.result != null) {
        final data = response.result as Map<String, dynamic>;
        if (data['success'] == true && data['delivery_fee'] != null) {
          debugPrint('🚚 Parse Cloud Function returned: ${data['delivery_fee']}');
          return (data['delivery_fee'] as num).toDouble();
        }
      }
    } catch (e) {
      debugPrint('🚚 Parse Cloud Function error: $e');
    }

    debugPrint('🚚 All methods failed, using fallback');
    return _configuredDeliveryFeeFallback(cartItems);
  }

  String _deliveryFeeCacheKey(List<Map<String, dynamic>> cartItems) {
    final restaurant = cartItems.first['restaurant'] as Map<String, dynamic>?;
    return [
      restaurant?['restau_id'],
      selectedAddress?.addressID,
      selectedAddress?.lat,
      selectedAddress?.long,
      _subtotal(cartItems),
    ].join('|');
  }

  void _ensureDisplayedDeliveryFee(
      List<Map<String, dynamic>> cartItems, String deliveryMode) {
    if (deliveryMode != kDeliveryOptionLivraison || cartItems.isEmpty) {
      _deliveryFeeKey = null;
      _calculatedDeliveryFee = null;
      return;
    }

    final key = _deliveryFeeCacheKey(cartItems);
    if (_deliveryFeeKey == key && _calculatedDeliveryFee != null) return;

    _deliveryFeeKey = key;
    _calculatedDeliveryFee = null;
    final requestId = ++_deliveryFeeRequestId;
    calculateDeliveryFee(cartItems).then((fee) {
      if (!mounted ||
          requestId != _deliveryFeeRequestId ||
          _deliveryFeeKey != key) {
        return;
      }
      setState(() => _calculatedDeliveryFee = fee);
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
    final promo = await PromoService.applyCode(
      rawCode: _promoController.text,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
    );
    if (promo == null) {
      setState(() => _appliedPromo = null);
      Toast(context, AppLocalizations.of(context)!.cart_promo_invalid, false);
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
    final deliveryFee = safeOption == kDeliveryOptionLivraison
        ? (_calculatedDeliveryFee ?? _staticDeliveryFee(cartItems))
        : 0.0;
    
    debugPrint('🚚 Final delivery fee: $deliveryFee (calculated: $_calculatedDeliveryFee, static: ${_staticDeliveryFee(cartItems)})');
    final cartTotal = _subtotal(cartItems);
    final reduction = _appliedPromo?.discountAmount ?? 0.0;
    final payableTotal =
        (cartTotal + deliveryFee - reduction).clamp(0.0, double.infinity);
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
                              cartItems: cartItems, deliveryFee: deliveryFee),
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
                      CartSummaryRow(l10n.deliveryFee,
                          CurrencyUtil.formatConvertedPrice(deliveryFee)),
                    if (_appliedPromo != null)
                      CartSummaryRow(
                        l10n.cart_discount,
                        '- ${_formatAmount(reduction, cc, cs)}',
                        valueColor: CC.success,
                      ),
                    const CartDashedDivider(),
                    CartTotalRow(
                        l10n.total, _formatAmount(payableTotal, cc, cs)),
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
              child: Row(
                children: [
                  Expanded(
                    child: CartPaymentOption(
                      icon: Icons.payments_outlined,
                      label: l10n.cart_payment_cod,
                      selected: !_payOnline,
                      onTap: () => setState(() => _payOnline = false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CartPaymentOption(
                      icon: Icons.credit_card_outlined,
                      label: l10n.cart_payment_fedapay,
                      selected: _payOnline,
                      onTap: () => setState(() => _payOnline = true),
                    ),
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
          label: _isSubmittingPayment
              ? l10n.cart_processing
              : l10n.cart_order_button(
                  CurrencyUtil.formatConvertedPrice(payableTotal)),
          onPressed: canSubmit
              ? () async {
                  if (deliveryBlocked) {
                    await showDeliveryUnavailableSheet(context);
                    return;
                  }
                  if (restaurantClosed) {
                    await showRestaurantClosedSheet(context);
                    return;
                  }
                  if (_payOnline) {
                    await _handleOnlinePayment();
                  } else {
                    await _handleOrder();
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

  Future<void> _handleOrder() async {
    final option = ref.read(selectedDeliveryProvider);
    final l10n = AppLocalizations.of(context)!;
    if (option == kDeliveryOptionLivraison && selectedAddress == null) {
      Toast(context, l10n.cart_choose_address_warning, false);
      return;
    }
    if (option == kDeliveryOptionLivraison && selectedAddress != null) {
      final inZone = await _checkAddressInZone(selectedAddress!);
      if (!inZone) return;
    }
    final cartItems = _itemsForRestaurant(ref.read(cartStateProvider));
    await _refreshCartDeliveryAvailability(cartItems);
    if (_cartDeliveryAvailability != null &&
        !_cartDeliveryAvailability!.canOrder) {
      await showDeliveryUnavailableSheet(context);
      return;
    }
    if (_cartOpeningStatus != null && !_cartOpeningStatus!.isOpen) {
      await showRestaurantClosedSheet(context);
      return;
    }
    final cartNotifier = ref.read(cartStateProvider.notifier);
    final items = List<Map<String, dynamic>>.from(cartItems);
    final country = _countryFromCart(items);
    final cc = _currencyCode(country);
    final fee = option == kDeliveryOptionLivraison
        ? await calculateDeliveryFee(items)
        : 0.0;
    final discount = _appliedPromo?.discountAmount ?? 0.0;

    setState(() => _isSubmittingPayment = true);
    try {
      final commandeId = await createOrder(
        cartItems,
        fee,
        option == kDeliveryOptionLivraison ? selectedAddress?.addressID : null,
        null,
        ref,
        currencyCode: cc,
        country: country,
        reduction: discount,
        promoCode: _appliedPromo?.code,
        cityID: _userCityId,
        deliveryMode: option,
      );
      if (commandeId != null) {
        Toast(context, l10n.cart_order_confirm_message, true);
        final restaurantId = int.tryParse(
                cartItems.first['restaurant']['restau_id'].toString()) ??
            0;
        final restaurantsList = await Restaurant.fetchRestaurantsFromDB();
        final currentRestaurant = Restaurant.getRestaurantByRestaurantId(
            restaurantsList, restaurantId);
        if (currentRestaurant != null) {
          final total = _subtotal(items) + fee - discount;
          NotificationService.sendOrderNotificationToRestaurateur(
            restaurateurId: currentRestaurant.userID,
            restaurantName: currentRestaurant.name,
            totalAmount: total.clamp(0.0, double.infinity),
            orderId: int.tryParse(commandeId),
            currencySymbol: CurrencyUtil.symbol(CurrencyUtil.code(country)),
          );
        }
        await cartNotifier.clearRestaurantCart(restaurantId);
        if (mounted) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      OrderConfirmationPage(commandeId: commandeId)));
        }
      } else {
        Toast(context, l10n.cart_order_failed, false);
      }
    } catch (_) {
      Toast(context, l10n.cart_order_error_retry, false);
    } finally {
      if (mounted) setState(() => _isSubmittingPayment = false);
    }
  }

  Future<void> _handleOnlinePayment() async {
    final option = ref.read(selectedDeliveryProvider);
    final l10n = AppLocalizations.of(context)!;
    if (option == kDeliveryOptionLivraison && selectedAddress == null) {
      Toast(context, l10n.cart_choose_address_warning, false);
      return;
    }
    if (option == kDeliveryOptionLivraison && selectedAddress != null) {
      final inZone = await _checkAddressInZone(selectedAddress!);
      if (!inZone) return;
    }
    final cartItems = _itemsForRestaurant(ref.read(cartStateProvider));
    await _refreshCartDeliveryAvailability(cartItems);
    if (_cartDeliveryAvailability != null &&
        !_cartDeliveryAvailability!.canOrder) {
      await showDeliveryUnavailableSheet(context);
      return;
    }
    if (_cartOpeningStatus != null && !_cartOpeningStatus!.isOpen) {
      await showRestaurantClosedSheet(context);
      return;
    }
    final cartNotifier = ref.read(cartStateProvider.notifier);
    final items = List<Map<String, dynamic>>.from(cartItems);
    final country = _countryFromCart(items);
    final cc = _currencyCode(country);
    final fee = option == kDeliveryOptionLivraison
        ? await calculateDeliveryFee(items)
        : 0.0;
    final discount = _appliedPromo?.discountAmount ?? 0.0;
    final total =
        (_subtotal(items) + fee - discount).clamp(0.0, double.infinity);
    setState(() => _isSubmittingPayment = true);
    try {
      final commandeId = await createOrder(
        cartItems,
        fee,
        option == kDeliveryOptionLivraison ? selectedAddress?.addressID : null,
        null,
        ref,
        currencyCode: cc,
        country: country,
        reduction: discount,
        promoCode: _appliedPromo?.code,
        cityID: _userCityId,
        deliveryMode: option,
      );
      if (commandeId == null) {
        Toast(context, AppLocalizations.of(context)!.cart_order_failed, false);
        return;
      }
      Map<String, dynamic>? data;
      final nodeToken = await SessionService.readNodeToken();
      if (nodeToken != null) {
        final orders = await NodeOrderService.listMine(
          token: nodeToken,
          userId: current_userID,
        );
        Map<String, dynamic>? nodeOrder;
        for (final order in orders) {
          if (order['orderId']?.toString() == commandeId) {
            nodeOrder = order;
            break;
          }
        }
        final orderUuid = nodeOrder?['id']?.toString();
        if (orderUuid == null || orderUuid.isEmpty) {
          throw const NodeAuthException('Commande Node introuvable.');
        }
        data = await NodeOrderService.initializeNyole(
          token: nodeToken,
          orderUuid: orderUuid,
        );
      } else {
        final session = await SessionService.readSession();
        final usersList = await Users.fetchUsersFromDB();
        final currentUser = Users.getUsersByUserId(usersList, session.userId);
        final response = await ParseCloudFunction('createNyoleCheckout')
            .execute(parameters: {
          'commandeID': int.tryParse(commandeId),
          'customerName':
              '${currentUser?.firstname ?? ""} ${currentUser?.lastname ?? ""}',
          'customerEmail': currentUser?.email ?? '',
          'customerPhone': currentUser?.telephone?.toString() ?? '',
        });
        if (response.success && response.result is Map) {
          data = Map<String, dynamic>.from(response.result as Map);
        }
      }
      if (data != null) {
        final paymentUrl = data['paymentUrl']?.toString();
        if (paymentUrl != null && paymentUrl.isNotEmpty) {
          final restaurantId = int.tryParse(
                  cartItems.first['restaurant']['restau_id'].toString()) ??
              0;
          await cartNotifier.clearRestaurantCart(restaurantId);
          
          if (mounted) {
            final paymentResult = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => NyolePaymentPage(
                  paymentUrl: paymentUrl,
                  orderId: commandeId,
                  onPaymentSuccess: () {
                    // Le paiement est réussi, on continue vers la page de confirmation
                  },
                  onPaymentFailed: () {
                    Toast(context, 'Le paiement a échoué', false);
                  },
                  onPaymentCancelled: () {
                    Toast(context, 'Paiement annulé', false);
                  },
                ),
              ),
            );
            
            // Si le paiement a réussi (paymentResult == true), on navigue vers la confirmation
            if (paymentResult == true && mounted) {
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => OrderConfirmationPage(
                            commandeId: commandeId,
                            paymentPending: true,
                          )));
            } else if (paymentResult == false && mounted) {
              // Si le paiement a échoué ou été annulé, on reste sur la page du panier
              // ou on pourrait rediriger vers une page d'erreur
            }
          }
        } else {
          Toast(context, AppLocalizations.of(context)!.cart_payment_url_error,
              false);
        }
      } else {
        Toast(context, AppLocalizations.of(context)!.cart_payment_online_error,
            false);
      }
    } catch (e) {
      final errorMessage = e.toString();
      print('Erreur paiement: $errorMessage');
      Toast(context, 'Erreur paiement: $errorMessage', false);
    } finally {
      if (mounted) setState(() => _isSubmittingPayment = false);
    }
  }

  int get _userCityId => _cityID;

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
        paymentMethod: idPaiement ?? (_payOnline ? 'NYOLE' : 'CASH'),
        reduction: reduction,
        promoCode: promoCode,
        cityId: cityID,
        currency: currencyCode,
        country: country,
      );
      final order = result['order'];
      if (order is! Map) return null;
      final normalizedOrder = Map<String, dynamic>.from(order);
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

// ── Composants UI Panier ───────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: AppTypography.titleMedium(
          color: AppColors.resolve(AppColors.ink, AppDarkColors.ink),
        ).copyWith(fontSize: 17));
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
                ? AppTypography.titleMedium(
                    color: AppColors.resolve(AppColors.ink, AppDarkColors.ink),
                  ).copyWith(fontSize: 16)
                : AppTypography.bodyLarge(
                    color: AppColors.resolve(AppColors.ink, AppDarkColors.ink),
                  ),
          ),
          Text(value,
              style: (isBold
                  ? AppTypography.titleMedium(
                      color:
                          AppColors.resolve(AppColors.ink, AppDarkColors.ink),
                    ).copyWith(fontSize: 16)
                  : AppTypography.bodyLarge(
                      color:
                          AppColors.resolve(AppColors.ink, AppDarkColors.ink),
                    )))
        ],
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.item,
    required this.country,
    required this.onDelete,
    required this.onQuantityChanged,
  });

  final Map<String, dynamic> item;
  final String country;
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

    String format(double v) => CurrencyUtil.formatPrice(v, country);

    return Dismissible(
      key: Key('cart_${item.hashCode}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color:
              AppColors.resolve(AppColors.errorLight, AppDarkColors.errorLight),
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
          color: AppColors.resolve(AppColors.card, AppDarkColors.card),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
              color: AppColors.resolve(AppColors.border, AppDarkColors.border),
              width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Photo
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: DiosImage(
                  url: meal["image"],
                  width: 72,
                  height: 72,
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
                      style: AppTypography.titleMedium(
                        color:
                            AppColors.resolve(AppColors.ink, AppDarkColors.ink),
                      ).copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      format(lineTotal),
                      style: AppTypography.bodyLarge(
                        color:
                            AppColors.resolve(AppColors.ink, AppDarkColors.ink),
                      ),
                    ),
                    if (item["optionDetails"] != null &&
                        item["optionDetails"] is Map)
                      ...(item["optionDetails"] as Map)
                          .entries
                          .map<Widget>((entry) {
                        final info = entry.value as Map<String, dynamic>;
                        return Text(
                          '${entry.key}: ${info["name"] ?? ""}',
                          style: AppTypography.labelMedium(
                              color: AppColors.resolve(AppColors.inkSubtle,
                                  AppDarkColors.inkSubtle)),
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
                    color: AppColors.resolve(AppColors.ink, AppDarkColors.ink),
                    onTap: quantity < maxQty
                        ? () => onQuantityChanged(quantity + 1)
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '$quantity',
                      style: AppTypography.titleMedium(
                        color:
                            AppColors.resolve(AppColors.ink, AppDarkColors.ink),
                      ).copyWith(fontSize: 16),
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
  const _QtyButton({
    required this.icon,
    this.color,
    required this.onTap,
  });
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 28,
        decoration: BoxDecoration(
          color: onTap != null
              ? AppColors.resolve(
                  AppColors.brandSurface, AppDarkColors.brandSurface)
              : AppColors.resolve(
                  AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon,
            size: 18,
            color: onTap != null
                ? AppColors.resolve(AppColors.brand, AppDarkColors.brand)
                : AppColors.resolve(AppColors.border, AppDarkColors.border)),
      ),
    );
  }
}

// ── Confirmation ────────────────────────────────────────

class OrderConfirmationPage extends StatelessWidget {
  final String commandeId;
  final bool paymentPending;

  const OrderConfirmationPage({
    super.key,
    required this.commandeId,
    this.paymentPending = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final content = SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              paymentPending
                  ? const Icon(Icons.hourglass_top_rounded,
                      size: 76, color: Colors.orange)
                  : const AnimatedSuccessCheck(),
              const SizedBox(height: 28),
              Text(
                  paymentPending
                      ? l10n.pending
                      : l10n.cart_order_confirm_message,
                  style: AppTypography.headlineMedium(
                    color: AppColors.resolve(AppColors.ink, AppDarkColors.ink),
                  ),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                paymentPending
                    ? l10n.tracking_pending_label
                    : l10n.cart_order_confirmed_message(commandeId),
                style: AppTypography.bodyLarge(
                  color: AppColors.resolve(AppColors.ink, AppDarkColors.ink),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          OrderTrackingPage(highlightedCommandeId: commandeId),
                    ),
                  ),
                  child: Text(l10n.cart_track_order),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Scaffold(
      backgroundColor:
          AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      body: paymentPending ? content : OrderConfettiCelebration(child: content),
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
