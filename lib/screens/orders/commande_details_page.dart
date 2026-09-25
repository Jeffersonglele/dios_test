import 'dart:async';
import 'package:dios_delices/core/app_role.dart';
import 'package:dios_delices/core/commande_status.dart';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/models/address.dart';
import 'package:dios_delices/models/commande.dart';
import 'package:dios_delices/models/dish.dart';
import 'package:dios_delices/models/ligne_commande.dart';
import 'package:dios_delices/models/restaurant.dart';
import 'package:dios_delices/models/users.dart';
import 'package:dios_delices/services/commande_api.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/currency_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../chat/chat_screen.dart';
import '../../widgets/rating_dialog.dart';

class CommandeDetailsPage extends StatefulWidget {
  final Commande commande;

  const CommandeDetailsPage({super.key, required this.commande});

  @override
  State<CommandeDetailsPage> createState() => _CommandeDetailsPageState();
}

class _CommandeDetailsPageState extends State<CommandeDetailsPage> {
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
  bool _canAssignLivreur = false;
  bool _isRestaurantView = false;
  Timer? _trackingTimer;
  String _country = 'RDC';

  @override
  void initState() {
    super.initState();
    _commande = widget.commande;
    _loadData();
    _startTracking();
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    super.dispose();
  }

  void _startTracking() {
    if (_commande.deliveryStatus == null || _commande.deliveryStatus == 'delivered') return;
    _trackingTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refreshCommande());
  }

  Future<void> _refreshCommande() async {
    try {
      final query = QueryBuilder<ParseObject>(ParseObject('Commande'))
        ..whereEqualTo('commandeID', _commande.commandeID);
      final resp = await query.query();
      if (resp.success && resp.results != null && resp.results!.isNotEmpty) {
        final obj = resp.results!.first;
        if (mounted) {
          final lat = obj.get<double>('livreurLat');
          final lng = obj.get<double>('livreurLng');
          final status = obj.get<String>('deliveryStatus');
          setState(() {
            if (lat != null) _commande.livreurLat = lat;
            if (lng != null) _commande.livreurLng = lng;
            if (status != null) _commande.deliveryStatus = status;
          });
          if (status == 'delivered') _trackingTimer?.cancel();
        }
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    try {
      final session = await SessionService.readSession();
      _country = session.country;
      _canAssignLivreur =
          session.role.isAdmin || session.role == AppRole.livreur;
      _isRestaurantView =
          session.role.isAdmin || session.role == AppRole.microRestaurant;

      await Future.wait([
        Commande.refreshLocalCommandes(),
        LigneCommande.getAllLignesCommande(),
        Address.getAllAdressesDetails(),
      ]);

      final results = await Future.wait([
        Dish.fetchDishesFromDB(),
        Restaurant.fetchRestaurantsFromDB(),
        Users.fetchUsersFromDB(),
        LigneCommande.fetchLignesCommandeByCommandeID(_commande.commandeID),
        Address.fetchAddressesFromDB(),
      ]);

      final allD = results[0] as List<Dish>;
      final allR = results[1] as List<Restaurant>;
      final allU = results[2] as List<Users>;
      final lignes = results[3] as List<LigneCommande>;
      final allA = results[4] as List<Address>;

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
      if (_commande.addressID != null && _commande.addressID! > 0) {
        final address = Address.getAddressByObject(
            allA, 'Commande', _commande.commandeID);
        if (address == null) {
          final addr = allA.where(
              (a) => a.addressID == _commande.addressID);
          if (addr.isNotEmpty) {
            addressLabel = addr.first.fullAddress ?? '';
          }
        } else {
          addressLabel = address.fullAddress ?? '';
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
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          newStatus == CommandeStatus.confirmed
              ? AppLocalizations.of(context)!.commande_details_confirm_order
              : AppLocalizations.of(context)!.commande_details_cancel_order,
          style: AppTypography.titleSmall(),
        ),
        content: Text(
          newStatus == CommandeStatus.confirmed
              ? AppLocalizations.of(context)!.user_orders_confirm_prompt(_commande.commandeID)
              : AppLocalizations.of(context)!.user_orders_cancel_prompt(_commande.commandeID),
          style: AppTypography.bodyMedium(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.no),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == CommandeStatus.confirmed
                  ? AppColors.success
                  : AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(newStatus == CommandeStatus.confirmed
                ? AppLocalizations.of(context)!.user_orders_yes_confirm
                : AppLocalizations.of(context)!.user_orders_yes_cancel),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      try {
        await CommandeApi.updateOrderStatus(
            _commande.commandeID.toString(), newStatus);
        await Commande.refreshLocalCommandes();
        final allC = await Commande.fetchCommandesFromDB();
        final updated =
            allC.where((c) => c.commandeID == _commande.commandeID);
        if (updated.isNotEmpty && mounted) {
          setState(() => _commande = updated.first);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(newStatus == CommandeStatus.confirmed
                  ? AppLocalizations.of(context)!.orderConfirmed
                  : AppLocalizations.of(context)!.orderCancelled),
              backgroundColor: newStatus == CommandeStatus.confirmed
                  ? AppColors.success
                  : AppColors.error,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${e.toString()}'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  double get _subtotal {
    double sum = 0;
    for (final l in _lignes) {
      sum += l.prixUnitaire * l.quantite;
    }
    return sum;
  }

  double get _total =>
      _subtotal + _commande.fraisLivraison - _commande.reduction;

  @override
  Widget build(BuildContext context) {
    final status = CommandeStatus.normalize(_commande.status);
    final statusColor = CommandeStatus.color(status);
    final bool isCancelled = status == CommandeStatus.cancelled;
    final bool isConfirmed = status == CommandeStatus.confirmed;
    final bool isDelivered = status == CommandeStatus.delivered;
    final bool canCancel = !isCancelled && !isConfirmed && !isDelivered;
    final bool canConfirm = !isConfirmed && !isCancelled;

    return Scaffold(
      backgroundColor: AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.commande_details_title,
            style: AppTypography.titleSmall(
                color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
        foregroundColor: AppColors.resolve(AppColors.ink, AppDarkColors.ink),
        backgroundColor: AppColors.resolve(AppColors.surface, AppDarkColors.surface),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                      color: AppColors.resolve(AppColors.brand, AppDarkColors.brand)))
              : _hasError
                  ? _buildErrorView()
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final maxWidth = constraints.maxWidth > 600 ? 560.0 : constraints.maxWidth;
                          return Center(
                            child: SizedBox(
                              width: maxWidth,
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                                children: [
                              _buildHeader(status, statusColor),
                              const SizedBox(height: 20),
                              _buildStatusTimeline(status),
                              const SizedBox(height: 20),
                              _buildInfoSection(),
                              const SizedBox(height: 20),
                              _buildLineItems(),
                              const SizedBox(height: 20),
                              _buildTotals(),
                              if (_addressLabel.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                _buildAddressSection(),
                              ],
                              if (_commande.livreurLat != null &&
                                  _commande.livreurLng != null) ...[
                                const SizedBox(height: 20),
                                _buildDeliveryMap(),
                              ],
                              if (_commande.deliveryStatus != null &&
                                  _commande.deliveryStatus!.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                _buildDeliveryInfo(),
                              ],
                              const SizedBox(height: 24),
                              _buildActions(canCancel, canConfirm, status),
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
              child: const Center(
                child: CircularProgressIndicator(),
              ),
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

  // ── En-tête ───────────────────────────────────────────
  Widget _buildHeader(String status, Color statusColor) {
    final dateStr =
        '${_commande.dateCommande.toLocal().toString().split(" ")[0]} à ${_commande.heure}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('${AppLocalizations.of(context)!.orders} #${_commande.commandeID}',
                style: AppTypography.titleLarge(
                    color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 13,
                color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted)),
            const SizedBox(width: 6),
            Text(dateStr,
                style: AppTypography.bodyMedium(
                    color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted))),
          ],
        ),
      ],
    );
  }

  // ── Timeline de statut ────────────────────────────────
  Widget _buildStatusTimeline(String currentStatus) {
    final steps = [
      _StepData(CommandeStatus.pending, AppLocalizations.of(context)!.commande_details_ordered, Icons.hourglass_top_rounded),
      _StepData(CommandeStatus.paid, AppLocalizations.of(context)!.commande_details_confirmed, Icons.payment_rounded),
      _StepData(CommandeStatus.confirmed, AppLocalizations.of(context)!.commande_details_confirmed, Icons.check_circle_rounded),
      _StepData('Livrée', AppLocalizations.of(context)!.commande_details_delivered, Icons.delivery_dining_rounded),
    ];

    int activeIndex = -1;
    if (CommandeStatus.isCancelled(currentStatus)) {
      activeIndex = -2;
    } else {
      for (int i = 0; i < steps.length; i++) {
        if (CommandeStatus.normalize(currentStatus) ==
            CommandeStatus.normalize(steps[i].status)) {
          activeIndex = i;
          break;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: AppColors.resolve(AppColors.border, AppDarkColors.border),
            width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline_rounded, size: 16,
                  color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted)),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.commande_details_tracking,
                  style: AppTypography.titleSmall(
                      color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
            ],
          ),
          const SizedBox(height: 16),
          if (activeIndex == -2)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.cancel_rounded, size: 18, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context)!.commande_details_cancelled,
                      style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              ),
            ),
          ...List.generate(steps.length, (i) {
            final step = steps[i];
            final bool isActive = i <= activeIndex;
            final bool isCurrent = i == activeIndex;
            final Color stepColor = isActive ? AppColors.brand : AppColors.border;
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Column(
                      children: [
                        Container(
                          width: isCurrent ? 14 : 10,
                          height: isCurrent ? 14 : 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive ? AppColors.brand : Colors.transparent,
                            border: Border.all(
                                color: stepColor, width: isCurrent ? 3 : 2),
                          ),
                        ),
                        if (i < steps.length - 1)
                          Expanded(
                            child: Container(
                              width: 1.5,
                              color: activeIndex > i
                                  ? AppColors.brand
                                  : AppColors.resolve(
                                      AppColors.border, AppDarkColors.border),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(step.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  isCurrent ? FontWeight.w700 : FontWeight.w500,
                              color: isActive
                                  ? AppColors.resolve(
                                      AppColors.ink, AppDarkColors.ink)
                                  : AppColors.resolve(
                                      AppColors.inkMuted, AppDarkColors.inkMuted),
                            )),
                      ],
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
    switch (_commande.moyenPaiementID) {
      case 1:
        return AppLocalizations.of(context)!.commande_details_cash;
      default:
        return AppLocalizations.of(context)!.commande_details_cinetpay;
    }
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

  // ── Carte de livraison ────────────────────────────────
  Widget _buildDeliveryMap() {
    final lat = _commande.livreurLat;
    final lng = _commande.livreurLng;
    if (lat == null || lng == null) return const SizedBox.shrink();
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
              Icon(Icons.map_rounded, size: 16,
                  color: AppColors.resolve(AppColors.brand, AppDarkColors.brand)),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.commande_details_driver_position,
                  style: AppTypography.titleSmall(
                      color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 160,
              child: FlutterMap(
                options: MapOptions(
                    initialCenter: LatLng(lat, lng),
                    initialZoom: 14,
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
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(lat, lng),
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.brand,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [AppShadows.card],
                          ),
                          child: const Icon(Icons.delivery_dining_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
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
  Widget _buildActions(bool canCancel, bool canConfirm, String status) {
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
              Icon(Icons.touch_app_rounded, size: 16,
                  color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted)),
              const SizedBox(width: 8),
              Text(AppLocalizations.of(context)!.commande_details_actions,
                  style: AppTypography.titleSmall(
                      color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _actionButton(
                  icon: Icons.chat_rounded,
                  label: AppLocalizations.of(context)!.commande_details_message,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        withUserID: _isRestaurantView
                            ? _commande.userID
                            : _commande.restaurateurID,
                        withUsername: _isRestaurantView
                            ? _clientName
                            : _restaurantName.isNotEmpty
                                ? _restaurantName
                                : 'Restaurateur',
                      ),
                    ),
                  ),
                  outlined: true,
                ),
                if (_isRestaurantView && canCancel)
                  _actionButton(
                    icon: Icons.cancel_rounded,
                    label: AppLocalizations.of(context)!.cancel,
                    onPressed: () => _updateStatus(CommandeStatus.cancelled),
                    backgroundColor: AppColors.error,
                  ),
                if (!_isRestaurantView &&
                    CommandeStatus.isPending(_commande.status))
                  _actionButton(
                    icon: Icons.cancel_outlined,
                    label: AppLocalizations.of(context)!.commande_details_cancel_order,
                    onPressed: () => _updateStatus(CommandeStatus.cancelled),
                    outlined: true,
                    foregroundColor: AppColors.error,
                  ),
                if (_isRestaurantView && canConfirm)
                  _actionButton(
                    icon: Icons.check_circle_rounded,
                    label: AppLocalizations.of(context)!.confirm,
                    onPressed: () => _updateStatus(CommandeStatus.confirmed),
                    backgroundColor: AppColors.success,
                  ),
                if (_canAssignLivreur)
                  _actionButton(
                    icon: Icons.person_add_rounded,
                    label: AppLocalizations.of(context)!.livreurs,
                    onPressed: () => _showAssignLivreur(_commande.commandeID),
                    outlined: true,
                  ),
                if (!_isRestaurantView && status == CommandeStatus.confirmed)
                  _actionButton(
                    icon: Icons.star_rounded,
                    label: AppLocalizations.of(context)!.review,
                    onPressed: () =>
                        _showRate(_commande.commandeID, _commande.restauID),
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                  ),
                if (!_isRestaurantView &&
                    _commande.livreurID != null &&
                    status == CommandeStatus.confirmed)
                  _actionButton(
                    icon: Icons.star_rounded,
                    label: AppLocalizations.of(context)!.commande_details_rate_driver,
                    onPressed: () => _showRateLivreur(_commande.livreurID!),
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color? backgroundColor,
    Color? foregroundColor,
    bool outlined = false,
  }) {
    if (outlined) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          label: Text(label, style: const TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            side: BorderSide(
                color: foregroundColor ??
                    AppColors.resolve(AppColors.border, AppDarkColors.border)),
            foregroundColor:
                foregroundColor ?? AppColors.resolve(AppColors.ink, AppDarkColors.ink),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor ?? Colors.white,
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  // ── Assigner livreur ──────────────────────────────────
  void _showAssignLivreur(int commandeID) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.user_orders_assign_driver,
                style: AppTypography.titleMedium(
                    color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await CommandeApi.updateOrderStatus(
                        commandeID.toString(), 'Assigné');
                    if (mounted) Navigator.pop(ctx);
                    await _loadData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!.user_orders_driver_assigned),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erreur: ${e.toString()}'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.check_circle_rounded),
                label: Text(AppLocalizations.of(context)!.user_orders_mark_assigned),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context)!.close),
            ),
          ],
        ),
      ),
    );
  }

  // ── Notation ──────────────────────────────────────────
  void _showRate(int commandeID, int restauID) {
    showDialog(
      context: context,
      builder: (_) => RatingDialog(
        targetType: 1,
        targetID: restauID,
        title: AppLocalizations.of(context)!.commande_details_rate_restaurant,
      ),
    ).then((result) {
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
        title: AppLocalizations.of(context)!.commande_details_rate_driver,
      ),
    ).then((result) {
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
