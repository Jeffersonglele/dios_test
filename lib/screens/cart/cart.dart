import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

import '../../l10n/app_localizations.dart';
import '../../db/database_helper.dart';
import '../../models/address.dart' as delivery;
import '../../models/commande.dart';
import '../../models/restaurant.dart';
import '../../models/users.dart';
import '../../providers/cart_provider.dart';
import '../../providers/selected_delivery.dart';
import '../../services/commande_api.dart';
import '../../services/delivery_availability_service.dart';
import '../../services/notification_service.dart';
import '../../services/promo_service.dart';
import '../../services/restaurant_opening_hours_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_util.dart';
import '../../utils/toast.dart';
import '../../widgets/animations.dart';
import '../../widgets/delivery_unavailable.dart';
import '../../widgets/dios_image.dart';
import '../orders/order_tracking_page.dart';

const kDeliveryOptionLivraison = 'En Livraison';
const kDeliveryOptionEmporter = 'À Emporter';

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
    final addressesList = await delivery.Address.fetchAddressesFromDB();
    if (!mounted) return;
    setState(() {
      addresses = addressesList;
      current_userID = session.userId;
      current_user_role = session.role.id;
      selectedAddress = null;
    });
    final user = await DatabaseHelper.getUser(current_userID);
    if (!mounted) return;
    _cityID = user?.cityID ?? 1;
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
    final restaurants = await Restaurant.fetchRestaurantsFromDB();
    final restaurant = Restaurant.getRestaurantByRestaurantId(
        restaurants, int.tryParse(restaurantId.toString()) ?? 0);
    if (restaurant == null) return;
    final availability = await DeliveryAvailabilityService.forRestaurant(
      restaurant,
      customerAddress: selectedAddress,
    );
    if (mounted) {
      setState(() {
        _cartDeliveryAvailability = availability;
        _cartOpeningStatus = restaurant.openingStatus;
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
    final list = await delivery.Address.fetchAddressesFromDB();
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
        Toast(context, l10n.location_disabled, false);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        Toast(context, l10n.location_disabled, false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      final nearbyAddress = await _findNearbySavedAddress(position);
      if (nearbyAddress != null) {
        await refreshAddresses();
        if (mounted) setState(() => selectedAddress = nearbyAddress);
        return;
      }

      Map<String, dynamic> geocoded = {};
      try {
        final response = await ParseCloudFunction(
          'reverseGeocodeDeliveryLocation',
        ).execute(parameters: {
          'lat': position.latitude,
          'lng': position.longitude,
        });
        if (response.success && response.result is Map) {
          geocoded = Map<String, dynamic>.from(response.result as Map);
        }
      } catch (_) {
        // Les coordonnées GPS suffisent à créer une adresse livrable :
        // Nominatim reste un enrichissement, pas un point de blocage.
      }

      final fallbackAddress = 'Position GPS : '
          '${position.latitude.toStringAsFixed(6)}, '
          '${position.longitude.toStringAsFixed(6)}';
      final fullAddress = _firstText([
        geocoded['displayName'],
        fallbackAddress,
      ]);
      final city = _firstText([geocoded['city'], geocoded['district']]);
      final state = _firstText([
        geocoded['district'],
        geocoded['department'],
        geocoded['country'],
      ]);

      final result = await delivery.Address.manageAddress(
        city: city,
        state: state,
        fullAddress: fullAddress,
        lat: position.latitude.toString(),
        long: position.longitude.toString(),
        object: 'Livraison',
        objectID: current_userID,
        user_roleID: current_user_role,
      );

      await refreshAddresses();
      if (result is int) {
        final saved = addresses.where((address) => address.addressID == result);
        if (mounted) {
          setState(() {
            selectedAddress = saved.isNotEmpty
                ? saved.first
                : delivery.Address(
                    addressID: result,
                    object: 'Livraison',
                    objectID: current_userID,
                    city: city,
                    state: state,
                    fullAddress: fullAddress,
                    lat: position.latitude.toString(),
                    long: position.longitude.toString(),
                  );
          });
        }
      } else if (result == 'EXISTING_ADDRESS') {
        final existing = await _findNearbySavedAddress(position);
        if (mounted && existing != null)
          setState(() => selectedAddress = existing);
      } else {
        Toast(context, l10n.location_detect_failed, false);
      }
    } catch (_) {
      if (mounted) Toast(context, l10n.location_detect_failed, false);
    } finally {
      if (mounted) setState(() => _isUsingCurrentLocation = false);
    }
  }

  double _staticDeliveryFee(List<Map<String, dynamic>> cartItems) {
    if (cartItems.isEmpty) return 0.0;
    final restaurant = cartItems.first['restaurant'] as Map<String, dynamic>?;
    final fee = restaurant?['delivery_fee'];
    if (fee is num && fee > 0) return fee.toDouble();
    final parsed = double.tryParse(fee?.toString() ?? '') ?? 0.0;
    return parsed > 0 ? parsed : 2000.0;
  }

  Future<double> _configuredDeliveryFeeFallback(
      List<Map<String, dynamic>> cartItems) async {
    final restaurantFee = _staticDeliveryFee(cartItems);
    try {
      final response = await ParseCloudFunction('getDeliveryConfig').execute();
      if (response.success && response.result is Map) {
        final data = Map<String, dynamic>.from(response.result as Map);
        final baseFee = (data['baseFee'] as num?)?.toDouble() ?? 2000;
        final increment =
            (data['roundingIncrement'] as num?)?.toDouble() ?? 50;
        final minFee = (data['minFee'] as num?)?.toDouble() ?? 0;
        final roundedBase = (baseFee / math.max(1, increment)).ceil() *
            math.max(1, increment);
        return math.max(
          roundedBase,
          minFee > 0 ? minFee : baseFee,
        ).toDouble();
      }
    } catch (_) {}

    // Compatibilité avec les anciens restaurants qui possèdent encore un
    // tarif local. Si ce tarif est absent, le défaut Parse est 2 000 FCFA.
    return restaurantFee > 0 ? restaurantFee : 2000.0;
  }

  Future<double> calculateDeliveryFee(
      List<Map<String, dynamic>> cartItems) async {
    if (cartItems.isEmpty) return _staticDeliveryFee(cartItems);
    if (selectedAddress == null) {
      return _configuredDeliveryFeeFallback(cartItems);
    }

    final dlvLat = double.tryParse(selectedAddress!.lat ?? '');
    final dlvLng = double.tryParse(selectedAddress!.long ?? '');
    if (dlvLat == null || dlvLng == null) {
      return _configuredDeliveryFeeFallback(cartItems);
    }

    final resto = cartItems.first['restaurant'] as Map<String, dynamic>?;
    if (resto == null) return _configuredDeliveryFeeFallback(cartItems);

    final rstLat = double.tryParse(resto['restau_lat']?.toString() ?? '');
    final rstLng = double.tryParse(resto['restau_lng']?.toString() ?? '');
    if (rstLat == null || rstLng == null) {
      return _configuredDeliveryFeeFallback(cartItems);
    }

    try {
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
          return (data['delivery_fee'] as num).toDouble();
        }
      }
    } catch (_) {}

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

  void _ensureDisplayedDeliveryFee(List<Map<String, dynamic>> cartItems,
      String deliveryMode) {
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
      if (!mounted || requestId != _deliveryFeeRequestId ||
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
  String _currencySymbol(String country) => CurrencyUtil.symbol(country);

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
      Toast(context, AppLocalizations.of(context)!.cart_promo_invalid, false);
      return;
    }
    setState(() => _appliedPromo = promo);
    Toast(
        context,
        AppLocalizations.of(context)!.cart_promo_applied(promo.description),
        true);
  }

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
        : kDeliveryOptionEmporter;

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
    final cartTotal = _subtotal(cartItems);
    final reduction = _appliedPromo?.discountAmount ?? 0.0;
    final payableTotal =
        (cartTotal + deliveryFee - reduction).clamp(0.0, double.infinity);
    final deliveryLabels = {
      kDeliveryOptionLivraison: l10n.cart_delivery_option_delivery,
      kDeliveryOptionEmporter: l10n.cart_delivery_option_takeaway,
    };
    final deliveryBlocked = _cartDeliveryAvailability != null &&
        !_cartDeliveryAvailability!.canOrder;
    final restaurantClosed =
        _cartOpeningStatus != null && !_cartOpeningStatus!.isOpen;

    if (widget.restaurantId == null && basketGroups.length > 1) {
      return _buildBasketSelection(context, basketGroups, l10n);
    }

    if (cartItems.isEmpty) {
      return Scaffold(
        backgroundColor:
            AppColors.resolve(AppColors.surface, AppDarkColors.surface),
        appBar: AppBar(title: Text(l10n.cart_title)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_basket_outlined,
                  size: 80,
                  color: AppColors.resolve(
                      AppColors.border, AppDarkColors.border)),
              const SizedBox(height: 20),
              Text(l10n.cart_empty,
                  style: AppTypography.titleMedium(
                      color:
                          AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
              const SizedBox(height: 8),
              Text(l10n.cart_empty_hint,
                  style: AppTypography.bodyMedium(
                      color:
                          AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      appBar: AppBar(
        title: Text(
            widget.restaurantId != null
                ? ((cartItems.first['restaurant']
                            as Map<String, dynamic>?)?['name']
                        ?.toString() ??
                    l10n.cart_title)
                : l10n.cart_title,
            style: AppTypography.titleLarge(
              color: AppColors.resolve(AppColors.ink, AppDarkColors.ink),
            ).copyWith(fontSize: 20)),
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
                    final globalIndex = visibleGlobalIndices[index];
                    return _CartItemCard(
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
                    );
                  }),
                  const SizedBox(height: 20),

                  // ── Livraison ───────────────────────
                  _SectionTitle(l10n.cart_delivery_section),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.resolve(
                                AppColors.card, AppDarkColors.card),
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border:
                                Border.all(color: AppColors.border, width: 0.5),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: safeOption,
                              isDense: true,
                              isExpanded: true,
                              items: allowedOptions
                                  .map((o) => DropdownMenuItem(
                                      value: o,
                                      child: Text(deliveryLabels[o] ?? o)))
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
                  if (safeOption == kDeliveryOptionLivraison) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.resolve(
                            AppColors.brandSurface, AppDarkColors.brandSurface),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: AppColors.brand.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.cart_delivery_to,
                            style: AppTypography.titleSmall(
                              color: AppColors.resolve(
                                  AppColors.ink, AppDarkColors.ink),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedAddress?.fullAddress ??
                                l10n.cart_choose_current_location,
                            style: AppTypography.bodyMedium(
                              color: AppColors.resolve(
                                  AppColors.inkMuted, AppDarkColors.inkMuted),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isUsingCurrentLocation
                                      ? null
                                      : _useCurrentLocation,
                                  icon: _isUsingCurrentLocation
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.my_location_rounded,
                                          size: 18),
                                  label: Text(_isUsingCurrentLocation
                                      ? l10n.cart_location_in_progress
                                      : l10n.cart_current_location),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: selectedAddress != null
                                    ? l10n.cart_change_address
                                    : l10n.cart_choose_address,
                                onPressed: _isUsingCurrentLocation
                                    ? null
                                    : _showAddressPicker,
                                icon: const Icon(
                                    Icons.edit_location_alt_outlined),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (selectedAddress != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.resolve(AppColors.successLight,
                              AppDarkColors.successLight),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.my_location_rounded,
                                color: AppColors.resolve(
                                    AppColors.success, AppDarkColors.success),
                                size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.cart_location_saved,
                                style: AppTypography.labelMedium(
                                  color: AppColors.resolve(
                                      AppColors.ink, AppDarkColors.ink),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (deliveryBlocked) ...[
                      const SizedBox(height: 8),
                      DeliveryUnavailableBanner(
                        onTap: () => showDeliveryUnavailableSheet(context),
                      ),
                    ],
                    if (restaurantClosed) ...[
                      const SizedBox(height: 8),
                      RestaurantClosedBanner(
                        status: _cartOpeningStatus!,
                        onTap: () => showRestaurantClosedSheet(context),
                      ),
                    ],
                  ],

                  // ── Code promo ──────────────────────
                  const SizedBox(height: 24),
                  _SectionTitle(l10n.cart_promo_section),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _promoController,
                          textCapitalization: TextCapitalization.characters,
                          style: AppTypography.bodyLarge(
                            color: AppColors.resolve(
                                AppColors.ink, AppDarkColors.ink),
                          ),
                          decoration: InputDecoration(
                            hintText: l10n.cart_promo_hint,
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
                          child: Text(l10n.cart_promo_apply),
                        ),
                      ),
                    ],
                  ),
                  if (_appliedPromo != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.resolve(
                            AppColors.successLight, AppDarkColors.successLight),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: AppColors.resolve(
                                  AppColors.success, AppDarkColors.success),
                              size: 18),
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
                  _SectionTitle(l10n.cart_summary_section),
                  const SizedBox(height: 14),
                  _SummaryRow(l10n.subtotal, _formatAmount(cartTotal, cc, cs)),
                  if (safeOption == kDeliveryOptionLivraison)
                    _SummaryRow(
                        l10n.deliveryFee, _formatAmount(deliveryFee, cc, cs)),
                  if (_appliedPromo != null)
                    _SummaryRow(
                      l10n.cart_discount,
                      '- ${_formatAmount(reduction, cc, cs)}',
                      valueColor: AppColors.success,
                    ),
                  const Divider(height: 20),
                  _SummaryRow(
                    l10n.total,
                    _formatAmount(payableTotal, cc, cs),
                    isBold: true,
                    valueColor: AppColors.brand,
                  ),

                  // ── Paiement ────────────────────────
                  const SizedBox(height: 24),
                  _SectionTitle(l10n.cart_payment_section),
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
                                  ? AppColors.resolve(AppColors.brandSurface,
                                      AppDarkColors.brandSurface)
                                  : AppColors.resolve(
                                      AppColors.card, AppDarkColors.card),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(
                                color: !_payOnline
                                    ? AppColors.resolve(
                                        AppColors.brand, AppDarkColors.brand)
                                    : AppColors.resolve(
                                        AppColors.border, AppDarkColors.border),
                                width: !_payOnline ? 1.5 : 0.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.payments_outlined,
                                    color: !_payOnline
                                        ? AppColors.resolve(AppColors.brand,
                                            AppDarkColors.brand)
                                        : AppColors.resolve(AppColors.inkMuted,
                                            AppDarkColors.inkMuted)),
                                const SizedBox(height: 4),
                                Text(l10n.cart_payment_cod,
                                    style: AppTypography.labelMedium(
                                        color: !_payOnline
                                            ? AppColors.resolve(AppColors.brand,
                                                AppDarkColors.brand)
                                            : AppColors.resolve(
                                                AppColors.inkMuted,
                                                AppDarkColors.inkMuted))),
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
                                  ? AppColors.resolve(AppColors.brandSurface,
                                      AppDarkColors.brandSurface)
                                  : AppColors.resolve(
                                      AppColors.card, AppDarkColors.card),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(
                                color: _payOnline
                                    ? AppColors.resolve(
                                        AppColors.brand, AppDarkColors.brand)
                                    : AppColors.resolve(
                                        AppColors.border, AppDarkColors.border),
                                width: _payOnline ? 1.5 : 0.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.credit_card_outlined,
                                    color: _payOnline
                                        ? AppColors.resolve(AppColors.brand,
                                            AppDarkColors.brand)
                                        : AppColors.resolve(AppColors.inkMuted,
                                            AppDarkColors.inkMuted)),
                                const SizedBox(height: 4),
                                Text(l10n.cart_payment_fedapay,
                                    style: AppTypography.labelMedium(
                                        color: _payOnline
                                            ? AppColors.resolve(AppColors.brand,
                                                AppDarkColors.brand)
                                            : AppColors.resolve(
                                                AppColors.inkMuted,
                                                AppDarkColors.inkMuted))),
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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color:
                    AppColors.resolve(AppColors.surface, AppDarkColors.surface),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.resolve(AppColors.ink, AppDarkColors.ink)
                        .withValues(alpha: 0.04),
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
                    onPressed: cartItems.isNotEmpty && !_isSubmittingPayment
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
                    child: Text(
                      _isSubmittingPayment
                          ? l10n.cart_processing
                          : l10n.cart_order_button(
                              CurrencyUtil.formatPrice(payableTotal, country)),
                      style: AppTypography.labelLarge(
                          color: AppColors.resolve(
                              AppColors.card, AppDarkColors.card)),
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
            currencySymbol: CurrencyUtil.symbol(country),
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
      final session = await SessionService.readSession();
      final usersList = await Users.fetchUsersFromDB();
      final currentUser = Users.getUsersByUserId(usersList, session.userId);

      final response = await ParseCloudFunction('createIkeepayCheckout')
          .execute(parameters: {
        'commandeID': int.tryParse(commandeId),
        'customerName':
            '${currentUser?.firstname ?? ""} ${currentUser?.lastname ?? ""}',
        'customerEmail': currentUser?.email ?? '',
        'customerPhone': currentUser?.telephone?.toString() ?? '',
      });
      if (response.success && response.result is Map) {
        final data = Map<String, dynamic>.from(response.result as Map);
        final paymentUrl = data['paymentUrl']?.toString();
        if (paymentUrl != null && paymentUrl.isNotEmpty) {
          final uri = Uri.parse(paymentUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
          final restaurantId = int.tryParse(
                  cartItems.first['restaurant']['restau_id'].toString()) ??
              0;
          final restaurantsList = await Restaurant.fetchRestaurantsFromDB();
          final currentRestaurant = Restaurant.getRestaurantByRestaurantId(
              restaurantsList, restaurantId);
          if (currentRestaurant != null) {
            NotificationService.sendOrderNotificationToRestaurateur(
              restaurateurId: currentRestaurant.userID,
              restaurantName: currentRestaurant.name,
              totalAmount: total,
              orderId: int.tryParse(commandeId),
              currencySymbol: CurrencyUtil.symbol(country),
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
          Toast(context, AppLocalizations.of(context)!.cart_payment_url_error,
              false);
        }
      } else {
        Toast(context, AppLocalizations.of(context)!.cart_payment_online_error,
            false);
      }
    } catch (_) {
      Toast(context, AppLocalizations.of(context)!.cart_payment_error, false);
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
  const OrderConfirmationPage({super.key, required this.commandeId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
        backgroundColor:
            AppColors.resolve(AppColors.surface, AppDarkColors.surface),
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
                    Text(l10n.cart_order_confirm_message,
                        style: AppTypography.headlineMedium(
                          color: AppColors.resolve(
                              AppColors.ink, AppDarkColors.ink),
                        ),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Text(
                      l10n.cart_order_confirmed_message(commandeId),
                      style: AppTypography.bodyLarge(
                        color:
                            AppColors.resolve(AppColors.ink, AppDarkColors.ink),
                      ),
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
                        child: Text(l10n.cart_track_order),
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
