import 'dart:async';
import 'dart:io' show File;
import 'dart:math' as math;
import 'package:dios_delices/core/app_role.dart';
import 'package:dios_delices/core/commande_status.dart';
import 'package:dios_delices/core/order_stage.dart';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/models/address.dart';
import 'package:dios_delices/models/commande.dart';
import 'package:dios_delices/models/dish.dart';
import 'package:dios_delices/models/ligne_commande.dart';
import 'package:dios_delices/models/restaurant.dart';
import 'package:dios_delices/models/users.dart';
import 'package:dios_delices/services/commande_api.dart';
import 'package:dios_delices/services/node_auth_service.dart';
import 'package:dios_delices/services/node_order_service.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/services/socket_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/services/upload_service.dart';
import 'package:dios_delices/utils/currency_util.dart';
import 'package:dios_delices/utils/phone_number.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../chat/chat_screen.dart';
import '../delivery/livreur_map_page.dart';
import '../../services/order_tracking_service.dart';
import '../../widgets/courier_card.dart';
import '../../widgets/rating_dialog.dart';
import '../../widgets/order_otp_widgets.dart';
import '../../widgets/order_dispute_sheet.dart';
import '../../utils/payment_provider_label.dart';

// ── Code OTP de remise : accès tolérant aux champs de la commande ──────────
// (ils renvoient null / false tant que le modèle Commande n'a pas
//  `retrievalOtp` et `isOtpVerified`)
String? _otpOf(Commande c) {
  try {
    final v = (c as dynamic).retrievalOtp;
    return v?.toString();
  } catch (_) {
    return null;
  }
}

bool _otpVerifiedOf(Commande c) {
  try {
    return (c as dynamic).isOtpVerified == true;
  } catch (_) {
    return false;
  }
}

bool _isPickupOrder(Commande c) =>
    orderOtpModeFrom(deliveryMode: c.deliveryMode) == OrderOtpMode.pickup;

// ── Fenêtre de litige : 60 minutes après la livraison ──────────────────────
const Duration _kDisputeWindow = Duration(minutes: 60);

/// Date de livraison (`deliveredAt`), lue de façon tolérante.
/// Renvoie null tant que le modèle Commande ne l'expose pas.
DateTime? _deliveredAtOf(Commande c) {
  try {
    final v = (c as dynamic).deliveredAt;
    if (v is DateTime) return v.toLocal();
    if (v != null) return DateTime.tryParse(v.toString())?.toLocal();
  } catch (_) {}
  return null;
}

class CommandeDetailsPage extends StatefulWidget {
  final Commande commande;

  const CommandeDetailsPage({super.key, required this.commande});

  @override
  State<CommandeDetailsPage> createState() => _CommandeDetailsPageState();
}

class _CommandeDetailsPageState extends State<CommandeDetailsPage>
    with TickerProviderStateMixin {
  late Commande _commande;
  List<LigneCommande> _lignes = [];
  Map<int, String> _dishNames = {};
  String _restaurantName = '';
  String _clientName = '';
  String _clientPhone = '';
  String _addressLabel = '';
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _hasError = false;
  bool _isRestaurantOwner = false;
  bool _isAdmin = false;
  bool _isRestaurantView = false;
  Timer? _trackingTimer;
  Timer? _disputeTimer;
  bool _disputeSent = false;
  String _country = 'RDC';

  // ── Live tracking state ──────────────────────────────────
  final MapController _mapController = MapController();
  final SocketService _socketService = SocketService();
  StreamSubscription<Map<String, dynamic>>? _courierMovedSub;
  StreamSubscription<Map<String, dynamic>>? _deliveryStatusSub;
  StreamSubscription<bool>? _connectionSub;
  AnimationController? _markerAnimController;
  double? _liveLat;
  double? _liveLng;
  double _animLat = 0;
  double _animLng = 0;
  double? _liveHeading;
  double? _liveAccuracy;
  bool _isSocketConnected = false;
  bool _hasReceivedLiveUpdate = false;
  Address? _deliveryAddress;

  /// Livreur assigné et points de la course (GET /orders/:id/tracking).
  OrderTracking? _tracking;

  @override
  void initState() {
    super.initState();
    _commande = widget.commande;
    // Seed live position from whatever the model already has
    _liveLat = _commande.livreurLat;
    _liveLng = _commande.livreurLng;
    _animLat = _commande.livreurLat ?? 0;
    _animLng = _commande.livreurLng ?? 0;
    _loadData();
    _startTracking();
    // la fenêtre de 60 min peut se refermer pendant que l'écran est ouvert
    _disputeTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    _disputeTimer?.cancel();
    _courierMovedSub?.cancel();
    _deliveryStatusSub?.cancel();
    _connectionSub?.cancel();
    _markerAnimController?.dispose();
    // Leave the tracking room if we joined one
    final orderId = _commande.commandeID.toString();
    _socketService.leaveOrderTracking(orderId);
    _mapController.dispose();
    super.dispose();
  }

  // ── Live tracking setup ──────────────────────────────────
  void _startTracking() {
    final stage = orderStageOf(_commande);
    if (stage == OrderStage.delivered || stage == OrderStage.cancelled) return;

    // 1. Temps réel (position du livreur, statut de course) en livraison.
    if (!_isPickupOrder(_commande)) _initLiveTracking();

    // 2. Rafraîchissement de secours du statut (acceptation, préparation…)
    _trackingTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshCommande(),
    );
  }

  Future<void> _initLiveTracking() async {
    try {
      await _socketService.connect();
      final orderId = _commande.commandeID.toString();
      _socketService.joinOrderTracking(orderId);

      // Connection state
      _connectionSub = _socketService.onConnectionChanged.listen((connected) {
        if (mounted) {
          setState(() => _isSocketConnected = connected);
          // Rejoin room on reconnect
          if (connected) {
            _socketService.joinOrderTracking(orderId);
          }
        }
      });

      // Real-time courier movement with smooth interpolation
      _courierMovedSub = _socketService.onCourierMoved.listen((data) {
        if (!mounted) return;
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) return;

        final prevLat = _animLat != 0 ? _animLat : (_liveLat ?? lat);
        final prevLng = _animLng != 0 ? _animLng : (_liveLng ?? lng);

        _markerAnimController?.stop();
        _markerAnimController?.dispose();
        _markerAnimController = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 800),
        );

        final curved = CurvedAnimation(
          parent: _markerAnimController!,
          curve: Curves.easeInOutQuad,
        );

        curved.addListener(() {
          if (!mounted) return;
          final t = curved.value;
          setState(() {
            _animLat = prevLat + (lat - prevLat) * t;
            _animLng = prevLng + (lng - prevLng) * t;
          });
        });

        _markerAnimController!.forward();

        setState(() {
          _liveLat = lat;
          _liveLng = lng;
          _liveHeading = (data['heading'] as num?)?.toDouble();
          _liveAccuracy = (data['accuracyM'] as num?)?.toDouble();
          _hasReceivedLiveUpdate = true;
          // Also update model for consistency
          _commande.livreurLat = lat;
          _commande.livreurLng = lng;
        });

        // Smoothly adjust camera to keep courier and destination in view
        _adjustCameraToCourierAndDestination(lat, lng);
      });

      // Delivery lifecycle events (status changes)
      _deliveryStatusSub = _socketService.onDeliveryStatusChanged.listen((data) {
        if (!mounted) return;
        final newStatus = data['status'] as String?;
        if (newStatus != null) {
          setState(() => _commande.deliveryStatus = newStatus);
          if (newStatus == 'delivered') {
            _trackingTimer?.cancel();
            _courierMovedSub?.cancel();
          }
        }
      });

      if (mounted) setState(() => _isSocketConnected = _socketService.isConnected);
    } catch (e) {
      print('[CommandeDetails] Live tracking init failed: $e');
    }
  }

  /// Profil du livreur (photo, nom, plaque) pour une commande en livraison.
  Future<void> _loadTracking() async {
    if (_isPickupOrder(_commande)) return;
    final tracking = await OrderTrackingService.fetch(_commande.commandeID);
    if (tracking != null && mounted) setState(() => _tracking = tracking);
  }

  void _openTrackingMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LivreurMapPage(
          commande: _commande,
          courierName: _tracking?.courier?.displayName,
        ),
      ),
    );
  }

  /// Carte « Votre livreur » pour le client et le restaurant, ou l'état
  /// « recherche d'un livreur » quand la commande est prête.
  List<Widget> _buildCourierSection(OrderStage stage) {
    if (_isPickupOrder(_commande) ||
        stage == OrderStage.cancelled ||
        stage == OrderStage.delivered && _tracking?.courier == null) {
      return const [];
    }
    final courier = _tracking?.courier;
    // Le livreur lui-même n'a pas besoin de sa propre fiche.
    if (_tracking?.viewer == 'courier') return const [];
    if (courier == null) {
      final searching =
          (_tracking?.deliveryStatus ?? '').toUpperCase() == 'SEARCHING';
      if (!searching) return const [];
      return const [CourierSearchingCard(), SizedBox(height: 16)];
    }
    final phone = courier.phone?.replaceAll(RegExp(r'[^0-9+]'), '');
    final active = stage != OrderStage.delivered;
    return [
      CourierCard(
        courier: courier,
        title: _isRestaurantView
            ? AppLocalizations.of(context)!.courier_card_title_restaurant
            : null,
        onCall: active && phone != null && phone.isNotEmpty
            ? () => _launch(Uri(scheme: 'tel', path: phone))
            : null,
        onTrack: active ? _openTrackingMap : null,
      ),
      const SizedBox(height: 16),
    ];
  }

  // ── Rafraîchissement depuis le backend Node ───────────────
  Future<void> _refreshCommande() async {
    try {
      final token = await SessionService.readNodeToken();
      if (token == null || token.isEmpty) return;
      final details = await NodeOrderService.getDetails(
        token: token,
        orderId: _commande.commandeID.toString(),
        includeLines: false,
      );
      final order = details?['order'];
      if (order is Map && mounted) _applyFreshOrder(order);
      await _loadTracking();
    } catch (_) {}
    // Le prochain cycle peut compléter si le socket est tombé.
    _hasReceivedLiveUpdate = false;
  }

  /// Remplace la commande affichée par la version serveur, en gardant la
  /// position temps réel du livreur si le socket l'a déjà mise à jour.
  void _applyFreshOrder(Map order) {
    final fresh =
        NodeOrderService.toLegacyCommande(Map<String, dynamic>.from(order));
    final keepLive = _hasReceivedLiveUpdate;
    setState(() {
      final liveLat = _commande.livreurLat;
      final liveLng = _commande.livreurLng;
      _commande = fresh;
      if (keepLive) {
        _commande.livreurLat = liveLat;
        _commande.livreurLng = liveLng;
      } else {
        _liveLat = fresh.livreurLat ?? _liveLat;
        _liveLng = fresh.livreurLng ?? _liveLng;
      }
    });
    final stage = orderStageOf(_commande);
    if (stage == OrderStage.delivered || stage == OrderStage.cancelled) {
      _trackingTimer?.cancel();
    }
  }

  Future<void> _loadData() async {
    try {
      final session = await SessionService.readSession();
      // Montants affichés dans la devise du pays de la commande.
      final orderCountry = (_commande.country ?? '').trim();
      _country = orderCountry.isNotEmpty ? orderCountry : session.country;
      _isAdmin = session.role.isAdmin;
      _isRestaurantOwner = session.role == AppRole.microRestaurant;
      _isRestaurantView = _isAdmin || _isRestaurantOwner;

      // Récupérer les détails de commande depuis le backend Node.js avec les lignes
      final token = await SessionService.readNodeToken();
      print('📦 Loading order details for orderId: ${_commande.commandeID}');
      print('📦 Token: ${token != null ? "present" : "null"}');

      Map<String, dynamic>? orderDetails;
      if (token != null && token.isNotEmpty) {
        try {
          orderDetails = await NodeOrderService.getDetails(
            token: token,
            orderId: _commande.commandeID.toString(),
            includeLines: true,
          );
          print('📦 Order details from backend: ${orderDetails != null ? "success" : "null"}');
        } catch (e) {
          print('📦 Backend order details failed: $e');
          orderDetails = null;
        }
      }

      final freshOrder = orderDetails?['order'];
      if (freshOrder is Map && mounted) _applyFreshOrder(freshOrder);
      unawaited(_loadTracking());

      final results = await Future.wait([
        Dish.fetchDishesFromDB(),
        Restaurant.fetchRestaurantsFromDB(),
        Users.fetchUsersFromDB(),
        Address.fetchAddressesFromDB(),
      ]);

      final allD = results[0] as List<Dish>;
      final allR = results[1] as List<Restaurant>;
      final allU = results[2] as List<Users>;
      final allA = results[3] as List<Address>;

      // Convertir les lignes du backend en LigneCommande
      List<LigneCommande> lignes = [];
      if (orderDetails != null && orderDetails['lines'] != null) {
        final linesData = orderDetails['lines'] as List;
        double parseD(dynamic v) {
          if (v == null) return 0.0;
          if (v is num) return v.toDouble();
          return double.tryParse(v.toString()) ?? 0.0;
        }
        int parseI(dynamic v, {int fallback = 0}) {
          if (v == null) return fallback;
          if (v is int) return v;
          if (v is num) return v.toInt();
          return int.tryParse(v.toString()) ?? fallback;
        }
        lignes = linesData.map((line) {
          final lineMap = line as Map<String, dynamic>;
          return LigneCommande(
            ligneID: lineMap['id']?.toString() ?? lineMap['ligneID']?.toString() ?? '',
            commandeID: _commande.commandeID.toString(),
            platID: parseI(lineMap['dishId'] ?? lineMap['platID']),
            quantite: parseI(lineMap['quantity'] ?? lineMap['quantite'], fallback: 1),
            prixUnitaire: parseD(lineMap['unitPrice'] ?? lineMap['prixUnitaire']),
            reduction: parseD(lineMap['discount'] ?? lineMap['reduction']),
            nomPlat: lineMap['dishName'] ?? lineMap['nomPlat'],
          );
        }).toList();
        print('📦 Loaded ${lignes.length} lines from backend');
      }

      // Si aucune ligne depuis le backend, essayer la base locale
      if (lignes.isEmpty) {
        lignes = await LigneCommande.fetchLignesCommandeByCommandeID(_commande.commandeID);
        print('📦 Loaded ${lignes.length} lines from local DB');
      }

      final dn = <int, String>{};
      for (final d in allD) {
        dn[d.dishID] = d.name ?? 'Plat #${d.dishID}';
      }

      String restoName = '';
      final resto =
          Restaurant.getRestaurantByRestaurantId(allR, _commande.restauID);
      if (resto != null) restoName = resto.name;

      String clientName = '';
      String clientPhone = '';
      final client = Users.getUsersByUserId(allU, _commande.userID);
      if (client != null) {
        clientName = '${client.firstname} ${client.lastname}'.trim();
        if (clientName.isEmpty) clientName = client.username;
        clientPhone = client.telephone;
      }

      String addressLabel = '';
      Address? deliveryAddress;
      if (_commande.addressID != null && _commande.addressID! > 0) {
        final address = Address.getAddressByObject(
            allA, 'Commande', _commande.commandeID);
        if (address == null) {
          final addr = allA.where(
              (a) => a.addressID == _commande.addressID);
          if (addr.isNotEmpty) {
            addressLabel = addr.first.fullAddress ?? '';
            deliveryAddress = addr.first;
          }
        } else {
          addressLabel = address.fullAddress ?? '';
          deliveryAddress = address;
        }
      }

      if (!mounted) return;
      setState(() {
        _lignes = lignes;
        _dishNames = dn;
        _restaurantName = restoName;
        _clientName = clientName;
        _clientPhone = clientPhone;
        _addressLabel = addressLabel;
        _deliveryAddress = deliveryAddress;
        _isLoading = false;
      });
    } catch (e, stack) {
      print('📦 Error loading order details: $e');
      print('📦 Stack trace: $stack');
      if (mounted) setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  double get _subtotal {
    // Utiliser le sous-total de la commande si disponible depuis le backend
    if (_commande.subtotalAmount != null && _commande.subtotalAmount! > 0) {
      return _commande.subtotalAmount!;
    }
    // Sinon calculer à partir des lignes
    double sum = 0;
    for (final l in _lignes) {
      sum += l.prixUnitaire * l.quantite;
    }
    return sum;
  }

  double get _total {
    // Utiliser le montant total depuis la commande si disponible
    if (_commande.totalAmount > 0) {
      return _commande.totalAmount;
    }
    // Sinon, calculer manuellement
    final showDeliveryFee = _commande.deliveryMode == 'DELIVERY' ||
                           _commande.deliveryMode?.toLowerCase() == 'livraison' ||
                           _commande.deliveryMode?.toLowerCase() == 'delivery';
    final deliveryFee = showDeliveryFee ? _commande.fraisLivraison : 0.0;
    return _subtotal + deliveryFee - _commande.reduction;
  }

  @override
  Widget build(BuildContext context) {
    final stage = _stage;
    final isCancelled = stage == OrderStage.cancelled;
    final isDelivered = stage == OrderStage.delivered;

    return Scaffold(
      backgroundColor: AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.commande_details_title,
            style: AppTypography.titleSmall(color: _ink)),
        foregroundColor: _ink,
        backgroundColor: AppColors.resolve(AppColors.surface, AppDarkColors.surface),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          _isLoading
              ? Center(child: CircularProgressIndicator(color: _brand))
              : _hasError
                  ? _buildErrorView()
                  : RefreshIndicator(
                      onRefresh: () async {
                        await _refreshCommande();
                        await _loadData();
                      },
                      color: _brand,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final maxWidth = constraints.maxWidth > 600
                              ? 560.0
                              : constraints.maxWidth;
                          return Center(
                            child: SizedBox(
                              width: maxWidth,
                              child: ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 40),
                                children: [
                                  _buildHeader(stage),
                                  if (stage == OrderStage.awaitingPayment &&
                                      !_isRestaurantView) ...[
                                    const SizedBox(height: 12),
                                    _buildAwaitingPaymentBanner(),
                                  ],
                                  const SizedBox(height: 16),
                                  // Code de remise (OTP) à communiquer au
                                  // livreur / présenter au restaurateur
                                  if (!_isRestaurantView &&
                                      !isCancelled &&
                                      stage != OrderStage.awaitingPayment &&
                                      (_otpOf(_commande) ?? '')
                                          .trim()
                                          .isNotEmpty) ...[
                                    OrderOtpCard(
                                      otp: _otpOf(_commande),
                                      mode: orderOtpModeFrom(
                                          deliveryMode: _commande.deliveryMode),
                                      verified: _otpVerifiedOf(_commande),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  ..._buildDisputeSection(isDelivered),
                                  _buildStatusTimeline(stage),
                                  const SizedBox(height: 16),
                                  _buildActions(stage),
                                  const SizedBox(height: 16),
                                  ..._buildCourierSection(stage),
                                  if (_commande.livreurLat != null &&
                                      _commande.livreurLng != null &&
                                      stage == OrderStage.onTheWay) ...[
                                    _buildDeliveryMap(),
                                    const SizedBox(height: 16),
                                  ],
                                  _buildLineItems(),
                                  const SizedBox(height: 16),
                                  _buildTotals(),
                                  if (_addressLabel.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    _buildAddressSection(),
                                  ],
                                  const SizedBox(height: 16),
                                  _buildInfoSection(),
                                  if (_commande.deliveryStatus != null &&
                                      _commande.deliveryStatus!.isNotEmpty &&
                                      !isCancelled) ...[
                                    const SizedBox(height: 16),
                                    _buildDeliveryInfo(),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          if (_isProcessing)
            Container(
              color: Colors.black26,
              child: Center(child: CircularProgressIndicator(color: _brand)),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 56,
                color: AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle)),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.commande_details_load_error,
                style: AppTypography.bodyMedium(
                    color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() { _hasError = false; _isLoading = true; });
                _loadData();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(AppLocalizations.of(context)!.retry),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Étape, libellés, couleurs ─────────────────────────
  OrderStage get _stage => orderStageOf(_commande);

  /// Payée en ligne (portefeuille ou Mobile Money confirmé) : une
  /// annulation donne lieu à un remboursement sur le portefeuille.
  bool get _paidOnline {
    final provider = (_commande.paymentProvider ?? '').toUpperCase();
    return provider == 'WALLET' ||
        (provider == 'NYOLE' &&
            CommandeStatus.normalize(_commande.status) == CommandeStatus.paid);
  }

  String _stageLabel(OrderStage stage) => orderStageLabel(
        AppLocalizations.of(context)!,
        stage,
        pickup: _isPickupOrder(_commande),
        refused: orderWasRefused(_commande),
      );

  Color _stageColor(OrderStage stage) => orderStageColor(stage);

  Color get _ink => AppColors.resolve(AppColors.ink, AppDarkColors.ink);
  Color get _inkMuted =>
      AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
  Color get _brand => AppColors.resolve(AppColors.brand, AppDarkColors.brand);
  Color get _cardColor => AppColors.resolve(AppColors.card, AppDarkColors.card);
  Color get _borderColor =>
      AppColors.resolve(AppColors.border, AppDarkColors.border);

  // ── En-tête ───────────────────────────────────────────
  Widget _buildHeader(OrderStage stage) {
    final l10n = AppLocalizations.of(context)!;
    final color = _stageColor(stage);
    final locale = Localizations.localeOf(context).toString();
    String date;
    try {
      date = DateFormat('d MMM yyyy · HH:mm', locale)
          .format(_commande.dateCommande.toLocal());
    } catch (_) {
      date =
          '${_commande.dateCommande.toLocal().toString().split(" ")[0]} · ${_commande.heure}';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: _borderColor.withValues(alpha: 0.7)),
        boxShadow: [AppShadows.card],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${l10n.orders} #${_commande.commandeID}',
                  style: AppTypography.headlineMedium(color: _ink)
                      .copyWith(fontSize: 24),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _stageLabel(stage),
                      style: AppTypography.labelMedium(color: color)
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.order_placed_on(date),
            style: AppTypography.bodyMedium(color: _inkMuted),
          ),
          if (_restaurantName.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.resolve(
                        AppColors.brandSurface, AppDarkColors.brandSurface),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(Icons.storefront_rounded, size: 17, color: _brand),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _restaurantName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleSmall(color: _ink),
                  ),
                ),
                Icon(
                  _isPickupOrder(_commande)
                      ? Icons.shopping_bag_outlined
                      : Icons.delivery_dining_rounded,
                  size: 18,
                  color: _inkMuted,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Bandeau « paiement en attente » (Mobile Money non encore confirmé).
  Widget _buildAwaitingPaymentBanner() {
    const color = Color(0xFFB7791F);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.accentLight, AppDarkColors.accentLight),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hourglass_top_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.order_awaiting_payment_hint,
              style: AppTypography.bodyMedium(color: _ink).copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ── Frise de suivi ────────────────────────────────────
  Widget _buildStatusTimeline(OrderStage stage) {
    final l10n = AppLocalizations.of(context)!;
    final pickup = _isPickupOrder(_commande);
    final steps = <(OrderStage, IconData)>[
      (OrderStage.received, Icons.receipt_long_rounded),
      (OrderStage.preparing, Icons.soup_kitchen_rounded),
      (OrderStage.ready, pickup ? Icons.shopping_bag_rounded : Icons.check_circle_rounded),
      if (!pickup) (OrderStage.onTheWay, Icons.delivery_dining_rounded),
      (OrderStage.delivered, pickup ? Icons.how_to_reg_rounded : Icons.home_rounded),
    ];
    final activeIndex = steps.indexWhere((s) => s.$1 == stage);
    final success = AppColors.resolve(AppColors.success, AppDarkColors.success);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: _borderColor.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.commande_details_tracking,
              style: AppTypography.titleSmall(color: _ink)),
          const SizedBox(height: 14),
          if (stage == OrderStage.cancelled)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.cancel_rounded,
                      size: 20, color: _stageColor(OrderStage.cancelled)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _stageLabel(OrderStage.cancelled),
                      style: AppTypography.bodyMedium(
                              color: _stageColor(OrderStage.cancelled))
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            )
          else
            ...List.generate(steps.length, (i) {
              final (stepStage, icon) = steps[i];
              final done = activeIndex > i ||
                  (stage == OrderStage.delivered && i == steps.length - 1);
              final current = i == activeIndex && stage != OrderStage.delivered;
              final reached = done || current;
              final dotColor = done ? success : (current ? _brand : _borderColor);
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 32,
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: AppMotion.normal,
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: reached
                                  ? dotColor
                                  : _cardColor,
                              border: Border.all(
                                  color: dotColor, width: reached ? 0 : 1.5),
                              boxShadow: current
                                  ? [
                                      BoxShadow(
                                        color: _brand.withValues(alpha: 0.30),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              done ? Icons.check_rounded : icon,
                              size: 16,
                              color: reached ? Colors.white : _inkMuted,
                            ),
                          ),
                          if (i < steps.length - 1)
                            Expanded(
                              child: Container(
                                width: 2,
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                color: done ? success : _borderColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 18),
                        child: Text(
                          _stageLabel(stepStage),
                          style: AppTypography.bodyMedium(
                            color: reached ? _ink : _inkMuted,
                          ).copyWith(
                            fontWeight:
                                current ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── Changement de statut ──────────────────────────────
  Future<void> _changeStatus({
    required String status,
    required String title,
    required String body,
    required String confirmLabel,
    required Color color,
    required String successMessage,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(title, style: AppTypography.titleMedium(color: _ink)),
        content: Text(body,
            style: AppTypography.bodyMedium(color: _inkMuted)
                .copyWith(height: 1.45)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.no),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      await CommandeApi.updateOrderStatus(
          _commande.commandeID.toString(), status);
      await _refreshCommande();
      try {
        await Commande.refreshLocalCommandes();
      } catch (_) {}
      if (mounted) _snack(successMessage, AppColors.success);
    } catch (e) {
      final message = e is NodeAuthException
          ? e.message
          : e.toString().replaceFirst('Exception: ', '');
      if (mounted) _snack(message, AppColors.error);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _snack(String message, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        content: Text(message),
      ));
  }

  void _cancelAsCustomer() {
    final l10n = AppLocalizations.of(context)!;
    final refund = _paidOnline;
    _changeStatus(
      status: CommandeStatus.cancelled,
      title: l10n.commande_details_cancel_order,
      body: refund
          ? '${l10n.order_cancel_free_hint}\n${l10n.order_cancel_refund_wallet}'
          : l10n.order_cancel_free_hint,
      confirmLabel: l10n.user_orders_yes_cancel,
      color: AppColors.error,
      successMessage:
          refund ? l10n.order_cancelled_refunded : l10n.order_cancelled_done,
    );
  }

  void _refuseAsRestaurant() {
    final l10n = AppLocalizations.of(context)!;
    _changeStatus(
      status: CommandeStatus.cancelled, // → REFUSED côté restaurant
      title: l10n.order_refuse_title,
      body: l10n.order_refuse_body,
      confirmLabel: l10n.order_refuse,
      color: AppColors.error,
      successMessage: l10n.order_refused_done,
    );
  }

  void _acceptAsRestaurant() {
    final l10n = AppLocalizations.of(context)!;
    _changeStatus(
      status: CommandeStatus.confirmed, // → EN_PREPARATION
      title: l10n.order_accept,
      body: l10n.order_accept_body,
      confirmLabel: l10n.order_accept,
      color: AppColors.success,
      successMessage: l10n.order_accepted_done,
    );
  }

  void _markReady() {
    final l10n = AppLocalizations.of(context)!;
    _changeStatus(
      status: CommandeStatus.ready, // → READY (lance la recherche de livreur)
      title: l10n.order_mark_ready,
      body: _isPickupOrder(_commande)
          ? l10n.order_step_ready_pickup
          : l10n.order_mark_ready_body,
      confirmLabel: l10n.order_mark_ready,
      color: AppColors.success,
      successMessage: l10n.order_ready_done,
    );
  }

  /// Commande « À emporter » prête, pas encore remise au client.
  bool _canValidatePickup(OrderStage stage) =>
      _isRestaurantOwner &&
      _isPickupOrder(_commande) &&
      stage == OrderStage.ready &&
      !_otpVerifiedOf(_commande);

  /// Dialogue « Valider le retrait du client » (code à 4 caractères).
  Future<void> _validatePickup() async {
    final ok = await showRestaurateurOtpDialog(
      context,
      orderId: _commande.commandeID,
    );
    if (ok == true && mounted) {
      await _refreshCommande();
      await _loadData();
    }
  }

  // ── Actions ───────────────────────────────────────────
  Widget _buildActions(OrderStage stage) {
    final l10n = AppLocalizations.of(context)!;
    final error = AppColors.resolve(AppColors.error, AppDarkColors.error);
    final success = AppColors.resolve(AppColors.success, AppDarkColors.success);
    final primary = <Widget>[];
    final secondary = <Widget>[];

    if (!_isRestaurantView) {
      // Client
      if (stage == OrderStage.delivered) {
        primary.add(_primaryButton(
          icon: Icons.star_rounded,
          label: l10n.commande_details_rate_restaurant,
          color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
          onPressed: () => _showRate(_commande.commandeID, _commande.restauID),
        ));
        if (_commande.livreurID != null && !_isPickupOrder(_commande)) {
          secondary.add(_secondaryButton(
            icon: Icons.delivery_dining_rounded,
            label: l10n.commande_details_rate_driver,
            onPressed: () => _showRateLivreur(_commande.livreurID!),
          ));
        }
      }
      if (stage == OrderStage.awaitingPayment || stage == OrderStage.received) {
        secondary.add(_secondaryButton(
          icon: Icons.cancel_outlined,
          label: l10n.commande_details_cancel_order,
          color: error,
          onPressed: _cancelAsCustomer,
        ));
      }
    } else if (_isRestaurantOwner) {
      // Restaurateur
      if (stage == OrderStage.received) {
        primary.add(_primaryButton(
          icon: Icons.soup_kitchen_rounded,
          label: l10n.order_accept,
          color: success,
          onPressed: _acceptAsRestaurant,
        ));
      }
      if (stage == OrderStage.preparing) {
        primary.add(_primaryButton(
          icon: Icons.check_circle_rounded,
          label: l10n.order_mark_ready,
          color: success,
          onPressed: _markReady,
        ));
      }
      if (_canValidatePickup(stage)) {
        primary.add(_primaryButton(
          icon: Icons.storefront_rounded,
          label: 'Valider le retrait du client',
          color: success,
          onPressed: _validatePickup,
        ));
      }
      if (stage == OrderStage.received || stage == OrderStage.preparing) {
        secondary.add(_secondaryButton(
          icon: Icons.block_rounded,
          label: l10n.order_refuse,
          color: error,
          onPressed: _refuseAsRestaurant,
        ));
      }
    } else if (_isAdmin &&
        stage != OrderStage.delivered &&
        stage != OrderStage.cancelled) {
      secondary.add(_secondaryButton(
        icon: Icons.cancel_outlined,
        label: l10n.commande_details_cancel_order,
        color: error,
        onPressed: () => _changeStatus(
          status: CommandeStatus.cancelled,
          title: l10n.commande_details_cancel_order,
          body: l10n.user_orders_cancel_prompt(_commande.commandeID),
          confirmLabel: l10n.user_orders_yes_cancel,
          color: AppColors.error,
          successMessage: l10n.order_cancelled_done,
        ),
      ));
    }

    // Canal direct (cahier des charges) : message, appel, WhatsApp.
    final contacts = <Widget>[
      if (stage != OrderStage.cancelled)
        _contactTile(
          icon: Icons.chat_bubble_outline_rounded,
          label: l10n.commande_details_message,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                orderId: _commande.commandeID,
                recipientName: _isRestaurantView
                    ? _clientName
                    : _restaurantName.isNotEmpty
                        ? _restaurantName
                        : 'Restaurateur',
              ),
            ),
          ),
        ),
      if (_isRestaurantView && _clientPhone.trim().isNotEmpty) ...[
        _contactTile(
          icon: Icons.call_rounded,
          label: l10n.order_call,
          onTap: () => _launch(Uri(scheme: 'tel', path: _clientPhoneE164)),
        ),
        _contactTile(
          icon: Icons.forum_rounded,
          label: l10n.order_whatsapp,
          onTap: () => _launch(Uri.parse(
              'https://wa.me/${_clientPhoneE164.replaceAll(RegExp(r'[^0-9]'), '')}')),
        ),
      ],
    ];

    if (primary.isEmpty && secondary.isEmpty && contacts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in primary) ...[b, const SizedBox(height: 10)],
        for (final b in secondary) ...[b, const SizedBox(height: 10)],
        if (stage == OrderStage.awaitingPayment || stage == OrderStage.received)
          if (!_isRestaurantView)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                l10n.order_cancel_free_hint,
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall(color: _inkMuted),
              ),
            ),
        if (contacts.isNotEmpty)
          Row(
            children: [
              for (var i = 0; i < contacts.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: contacts[i]),
              ],
            ],
          ),
      ],
    );
  }

  /// Numéro du client au format international pour l'appel / WhatsApp.
  String get _clientPhoneE164 {
    final raw = _clientPhone.trim();
    if (raw.startsWith('+')) return raw.replaceAll(RegExp(r'[^0-9+]'), '');
    try {
      return phoneE164ForCountry(phone: raw, country: _country);
    } catch (_) {
      return raw;
    }
  }

  Future<void> _launch(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) _snack('Action impossible sur cet appareil.', AppColors.error);
    } catch (_) {
      if (mounted) _snack('Action impossible sur cet appareil.', AppColors.error);
    }
  }

  Widget _primaryButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isProcessing ? null : onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label,
            style: AppTypography.labelLarge(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
    );
  }

  Widget _secondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    final fg = color ?? _ink;
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _isProcessing ? null : onPressed,
        icon: Icon(icon, size: 19, color: fg),
        label: Text(label, style: AppTypography.labelLarge(color: fg)),
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          side: BorderSide(
              color: color != null ? color.withValues(alpha: 0.5) : _borderColor),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
    );
  }

  Widget _contactTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: _borderColor.withValues(alpha: 0.8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: _brand),
              const SizedBox(height: 4),
              Text(label,
                  style: AppTypography.labelMedium(color: _ink)
                      .copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section infos ─────────────────────────────────────
  Widget _buildInfoSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: AppColors.resolve(AppColors.border, AppDarkColors.border),
            width: 0.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16,
                  color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted)),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.commande_details_information,
                  style: AppTypography.titleSmall(
                      color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
            ],
          ),
          const SizedBox(height: 12),
          if (_restaurantName.isNotEmpty)
            _buildInfoRow(
                Icons.store_rounded, AppLocalizations.of(context)!.commande_details_restaurant, _restaurantName),
          _buildInfoRow(Icons.person_rounded, AppLocalizations.of(context)!.commande_details_client, _clientName),
          if (_clientPhone.isNotEmpty)
            _buildInfoRow(
                Icons.phone_rounded, AppLocalizations.of(context)!.phone, _clientPhone),
          _buildInfoRow(
              Icons.payment_rounded, AppLocalizations.of(context)!.commande_details_payment, _paymentLabel),
          if (_commande.note != null && _commande.note! > 0)
            _buildInfoRow(Icons.star_rounded, AppLocalizations.of(context)!.commande_details_rating_label,
                '${_commande.note!.toStringAsFixed(1)} / 5'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18,
              color: AppColors.resolve(AppColors.brand, AppDarkColors.brand)),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(label + ' :',
                style: AppTypography.bodyMedium(
                    color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted))
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 4,
            child: Text(value,
                style: AppTypography.bodyMedium(
                    color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))
                    .copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  String get _paymentLabel {
    return paymentProviderLabel(
          _commande.paymentStatus,
          moyenPaiementID: _commande.moyenPaiementID,
        ) ??
        AppLocalizations.of(context)!.commande_details_cash;
  }

  // ── Articles ──────────────────────────────────────────
  Widget _buildLineItems() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: AppColors.resolve(AppColors.border, AppDarkColors.border),
            width: 0.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_bag_rounded, size: 16,
                  color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted)),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.commande_details_items,
                  style: AppTypography.titleSmall(
                      color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
              const Spacer(),
              Text(AppLocalizations.of(context)!.commande_details_item_count(_lignes.length),
                  style: AppTypography.bodyMedium(
                      color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted))),
            ],
          ),
          const SizedBox(height: 12),
          if (_lignes.isEmpty)
            Text(AppLocalizations.of(context)!.commande_details_no_items,
                style: AppTypography.bodyMedium(
                    color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted)))
          else
            ..._lignes.map((l) => _buildLineItem(l)),
        ],
      ),
    );
  }

  Widget _buildLineItem(LigneCommande l) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    (l.nomPlat?.trim().isNotEmpty == true
                            ? l.nomPlat!.trim()
                            : null) ??
                        _dishNames[l.platID] ??
                        'Plat #${l.platID}',
                    style: AppTypography.bodyMedium(
                        color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
                Text('${CurrencyUtil.formatPrice(l.prixUnitaire, _country)} · x${l.quantite}',
                    style: AppTypography.bodyMedium(
                            color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted))
                        .copyWith(fontSize: 12)),
              ],
            ),
          ),
          Text(CurrencyUtil.formatPrice(l.prixUnitaire * l.quantite, _country),
              style: AppTypography.labelMedium(
                  color: AppColors.resolve(AppColors.brand, AppDarkColors.brand))),
        ],
      ),
    );
  }

  // ── Totaux ────────────────────────────────────────────
  Widget _buildTotals() {
    // Afficher les frais de livraison seulement si c'est une livraison
    final showDeliveryFee = _commande.deliveryMode == 'DELIVERY' ||
                           _commande.deliveryMode?.toLowerCase() == 'livraison' ||
                           _commande.deliveryMode?.toLowerCase() == 'delivery';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: AppColors.resolve(AppColors.border, AppDarkColors.border),
            width: 0.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTotalRow(AppLocalizations.of(context)!.subtotal, CurrencyUtil.formatPrice(_subtotal, _country)),
          const SizedBox(height: 6),
          if (showDeliveryFee)
            _buildTotalRow(AppLocalizations.of(context)!.commande_details_livraison,
                CurrencyUtil.formatPrice(_commande.fraisLivraison, _country)),
          if (_commande.reduction > 0) ...[
            const SizedBox(height: 6),
            _buildTotalRow(AppLocalizations.of(context)!.commande_details_reduction,
                '-${CurrencyUtil.formatPrice(_commande.reduction, _country)}'),
          ],
          Divider(height: 24,
              color: AppColors.resolve(AppColors.border, AppDarkColors.border)),
          _buildTotalRow(AppLocalizations.of(context)!.total, CurrencyUtil.formatPrice(_total, _country), isTotal: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: isTotal
                ? AppTypography.titleSmall(
                    color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))
                : AppTypography.bodyMedium(
                    color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted))),
        Text(value,
            style: isTotal
                ? AppTypography.titleSmall(
                    color: AppColors.resolve(AppColors.brand, AppDarkColors.brand))
                : AppTypography.labelMedium(
                    color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
      ],
    );
  }

  // ── Adresse ───────────────────────────────────────────
  Widget _buildAddressSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: AppColors.resolve(AppColors.border, AppDarkColors.border),
            width: 0.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_rounded, size: 16,
                  color: AppColors.resolve(AppColors.brand, AppDarkColors.brand)),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.commande_details_address,
                  style: AppTypography.titleSmall(
                      color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_outlined, size: 16,
                  color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_addressLabel,
                    style: AppTypography.bodyMedium(
                        color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Carte de livraison en temps réel ──────────────────────
  void _adjustCameraToCourierAndDestination(double courierLat, double courierLng) {
    try {
      final destLat = double.tryParse(_deliveryAddress?.lat ?? '');
      final destLng = double.tryParse(_deliveryAddress?.long ?? '');
      if (destLat != null && destLng != null && (destLat != courierLat || destLng != courierLng)) {
        final bounds = LatLngBounds(
          LatLng(courierLat, courierLng),
          LatLng(destLat, destLng),
        );
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
          ),
        );
      } else {
        _mapController.move(LatLng(courierLat, courierLng), _mapController.camera.zoom);
      }
    } catch (_) {
      // MapController may not be ready yet
    }
  }

  // ── Carte de livraison en temps réel ──────────────────────
  Widget _buildDeliveryMap() {
    final lat = _liveLat ?? _commande.livreurLat;
    final lng = _liveLng ?? _commande.livreurLng;
    if (lat == null || lng == null) return const SizedBox.shrink();

    final currentDisplayLat = _animLat != 0 ? _animLat : lat;
    final currentDisplayLng = _animLng != 0 ? _animLng : lng;
    final courierPos = LatLng(currentDisplayLat, currentDisplayLng);

    // Build marker list
    final markers = <Marker>[
      // Marqueur Moto avec rotation selon le cap et animation lumineuse
      Marker(
        point: courierPos,
        width: 52,
        height: 52,
        child: Transform.rotate(
          angle: (_liveHeading ?? 0) * (math.pi / 180),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.brand,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brand.withValues(alpha: 0.45),
                  blurRadius: 14,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: const Icon(
              Icons.two_wheeler_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    ];

    // Marqueur de destination (adresse du client)
    final destLat = double.tryParse(_deliveryAddress?.lat ?? '');
    final destLng = double.tryParse(_deliveryAddress?.long ?? '');
    if (destLat != null && destLng != null) {
      markers.add(Marker(
        point: LatLng(destLat, destLng),
        width: 42,
        height: 42,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.red.shade600,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.red.shade600.withValues(alpha: 0.35),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
        ),
      ));
    }

    // Cercle de précision GPS
    final circles = <CircleMarker>[];
    if (_liveAccuracy != null && _liveAccuracy! > 0 && _liveAccuracy! < 500) {
      circles.add(CircleMarker(
        point: courierPos,
        radius: _liveAccuracy!,
        useRadiusInMeter: true,
        color: AppColors.brand.withValues(alpha: 0.08),
        borderColor: AppColors.brand.withValues(alpha: 0.3),
        borderStrokeWidth: 1.5,
      ));
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: AppColors.resolve(AppColors.border, AppDarkColors.border),
            width: 0.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with live indicator
          Row(
            children: [
              Icon(Icons.map_rounded, size: 16,
                  color: AppColors.resolve(AppColors.brand, AppDarkColors.brand)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.commande_details_driver_position,
                  style: AppTypography.titleSmall(
                      color: AppColors.resolve(AppColors.ink, AppDarkColors.ink)),
                ),
              ),
              // Live / Offline indicator badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _isSocketConnected
                      ? Colors.green.withOpacity(0.12)
                      : Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isSocketConnected ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isSocketConnected ? 'LIVE' : '•••',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _isSocketConnected ? Colors.green.shade700 : Colors.orange.shade700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Map
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 200,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                    initialCenter: courierPos,
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.drag |
                            InteractiveFlag.pinchZoom |
                            InteractiveFlag.doubleTapZoom)),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.diosdelices.app',
                  ),
                  if (circles.isNotEmpty)
                    CircleLayer(circles: circles),
                  MarkerLayer(markers: markers),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Infos livraison ───────────────────────────────────
  Widget _buildDeliveryInfo() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: AppColors.resolve(AppColors.border, AppDarkColors.border),
            width: 0.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.delivery_dining_rounded, size: 16,
                  color: AppColors.resolve(AppColors.brand, AppDarkColors.brand)),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.delivery,
                  style: AppTypography.titleSmall(
                      color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
                Text(AppLocalizations.of(context)!.commande_details_status,
                  style: AppTypography.bodyMedium(
                      color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted))),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(_deliveryStatusLabel(_commande.deliveryStatus),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.resolve(AppColors.brand, AppDarkColors.brand))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────
  // ── Litige (client, 60 min après la livraison) ─────────
  bool _disputeWindowOpen(bool isDelivered) {
    if (_isRestaurantView || !isDelivered) return false;
    final deliveredAt = _deliveredAtOf(_commande);
    if (deliveredAt == null) return false; // date inconnue : pas de bouton
    return DateTime.now().difference(deliveredAt).inMinutes <
        _kDisputeWindow.inMinutes;
  }

  List<Widget> _buildDisputeSection(bool isDelivered) {
    if (_disputeSent && !_isRestaurantView) {
      return [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.success),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Réclamation envoyée. Notre équipe vous répondra rapidement.',
                style: AppTypography.bodyMedium(color: AppColors.success)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),
      ];
    }
    if (!_disputeWindowOpen(isDelivered)) return const [];

    final deliveredAt = _deliveredAtOf(_commande)!;
    final deadline = deliveredAt.add(_kDisputeWindow);
    final left = deadline.difference(DateTime.now()).inMinutes + 1;
    return [
      DisputeButton(onPressed: () => _openDispute(deadline)),
      const SizedBox(height: 6),
      Center(
        child: Text(
          'Encore $left min pour signaler un problème',
          style: AppTypography.bodyMedium(
                  color: AppColors.resolve(
                      AppColors.inkMuted, AppDarkColors.inkMuted))
              .copyWith(fontSize: 12),
        ),
      ),
      const SizedBox(height: 20),
    ];
  }

  Future<void> _openDispute(DateTime deadline) async {
    final sent = await showOrderDisputeSheet(
      context,
      orderId: _commande.commandeID,
      deadline: deadline,
      uploadPhoto: _uploadDisputePhoto,
    );
    if (sent == true && mounted) {
      setState(() => _disputeSent = true);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          backgroundColor: AppColors.success,
          content: Text('Réclamation envoyée'),
        ));
    }
  }

  /// Envoi de la photo de preuve (stockage Parse, comme les autres images de
  /// l'app). Remplacez le corps si votre upload passe par un autre service.
  Future<String> _uploadDisputePhoto(File photo) async {
    if (await SessionService.hasNodeSession()) {
      final url = await UploadService.uploadImage(photo, scope: 'disputes');
      if (url == null || url.isEmpty) {
        throw Exception("Échec de l'envoi de la photo");
      }
      return url;
    }
    final file = ParseFile(
      photo,
      name:
          'dispute_${_commande.commandeID}_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    final res = await file.save();
    final url = file.url;
    if (!res.success || url == null || url.isEmpty) {
      throw Exception("Échec de l'envoi de la photo");
    }
    return url;
  }

  // ── Notation ──────────────────────────────────────────
  void _showRate(int commandeID, int restauID) {
    showDialog(
      context: context,
      builder: (_) => RatingDialog(
        targetType: 1,
        targetID: restauID,
        orderId: commandeID,
        title: AppLocalizations.of(context)!.commande_details_rate_restaurant,
      ),
    ).then((result) {
      if (result is String && result != "success" && mounted) {
        _snack(result, AppColors.error);
      }
      if (result == "success" && mounted) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.user_orders_thanks_review),
            backgroundColor: AppColors.success,
          ),
        );
      }
    });
  }

  void _showRateLivreur(int livreurID) {
    showDialog(
      context: context,
      builder: (_) => RatingDialog(
        targetType: 3,
        targetID: livreurID,
        orderId: _commande.commandeID,
        title: AppLocalizations.of(context)!.commande_details_rate_driver,
      ),
    ).then((result) {
      if (result is String && result != "success" && mounted) {
        _snack(result, AppColors.error);
      }
      if (result == "success" && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.user_orders_thanks_review_driver),
            backgroundColor: AppColors.success,
          ),
        );
      }
    });
  }

  String _deliveryStatusLabel(String? status) {
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case 'assigned':
        return l10n.delivery_status_assigned;
      case 'picked_up':
        return l10n.delivery_status_picked_up;
      case 'in_transit':
        return l10n.delivery_status_in_transit;
      case 'delivered':
        return l10n.delivery_status_delivered;
      default:
        return l10n.delivery_status_pending_assign;
    }
  }
}

class _StepData {
  final String status;
  final String label;
  final IconData icon;
  const _StepData(this.status, this.label, this.icon);
}