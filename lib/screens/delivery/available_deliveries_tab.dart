import 'dart:async';

import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/currency_util.dart';
import 'package:dios_delices/widgets/order_otp_widgets.dart'
    show OtpGradientButton;
import 'package:dios_delices/widgets/swirling_loader.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/delivery_orders_service.dart';

enum _Problem { locationOff, denied, deniedForever, network }

/// Onglet « Commandes disponibles » (Open Market) du dashboard livreur.
///
/// Dans delivery_dashboard.dart : ajoutez un onglet « Disponibles » et
/// placez `const AvailableDeliveriesTab()` dans le TabBarView.
/// `onAccepted` permet de basculer vers « Mes courses » après acceptation.
class AvailableDeliveriesTab extends StatefulWidget {
  const AvailableDeliveriesTab({
    super.key,
    this.onAccepted,
    this.isOnline = true,
  });

  final void Function(AvailableDelivery delivery)? onAccepted;

  /// Hors ligne : la liste n'est pas chargée et aucune course ne peut être prise.
  final bool isOnline;

  @override
  State<AvailableDeliveriesTab> createState() => _AvailableDeliveriesTabState();
}

class _AvailableDeliveriesTabState extends State<AvailableDeliveriesTab>
    with AutomaticKeepAliveClientMixin {
  List<AvailableDelivery> _items = [];
  final Set<String> _accepting = {};
  bool _loading = true;
  _Problem? _problem;
  String? _error;
  Position? _position;
  Timer? _autoRefresh;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.isOnline) {
      _load();
    } else {
      _loading = false;
    }
    // l'Open Market bouge vite : rafraîchissement discret toutes les 30 s
    _autoRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted &&
          widget.isOnline &&
          !_loading &&
          _accepting.isEmpty &&
          _problem == null) {
        _load(silent: true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant AvailableDeliveriesTab old) {
    super.didUpdateWidget(old);
    if (!old.isOnline && widget.isOnline) _load();
    if (old.isOnline && !widget.isOnline) {
      setState(() {
        _items = [];
        _problem = null;
      });
    }
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  // ── Position du livreur ─────────────────────────────────
  /// Retourne null et renseigne _problem si la position est inaccessible.
  Future<Position?> _locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _problem = _Problem.locationOff;
      return null;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      _problem = _Problem.denied;
      return null;
    }
    if (perm == LocationPermission.deniedForever) {
      _problem = _Problem.deniedForever;
      return null;
    }
    // position via votre service (même appel que le reste de l'app)
    final pos = await DeliveryOrdersService.getCurrentPosition();
    if (pos == null) _problem = _Problem.locationOff;
    return pos;
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _problem = null;
        _error = null;
      });
    }
    try {
      _problem = null;
      final pos = await _locate();
      if (pos == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }
      _position = pos;
      final list = await DeliveryOrdersService.fetchAvailableDeliveries(
        pos.latitude,
        pos.longitude,
      );
      if (!mounted) return;
      setState(() {
        _items = list;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (!silent) {
          _error = e is DeliveryException
              ? e.message
              : 'Impossible de charger les commandes disponibles.';
          _problem = _Problem.network;
        }
      });
    }
  }

  // ── Accepter une course ─────────────────────────────────
  Future<void> _accept(AvailableDelivery d) async {
    if (_accepting.contains(d.routeId)) return;
    setState(() => _accepting.add(d.routeId));
    try {
      await DeliveryOrdersService.acceptOrder(d.routeId);
      if (!mounted) return;
      setState(() => _items.removeWhere((x) => x.routeId == d.routeId));
      _snack('Course acceptée', success: true);
      widget.onAccepted?.call(d);
    } on DeliveryException catch (e) {
      if (!mounted) return;
      if (e.isConflict) {
        // 409 : déjà prise par un autre livreur
        _snack('Un autre livreur a déjà pris cette commande');
        await _load(silent: true);
      } else if (e.isCashCeiling) {
        // 403 : plafond d'espèces atteint
        await _showCashCeilingDialog();
      } else {
        _snack(e.message);
      }
    } catch (_) {
      if (mounted) _snack('Impossible d\'accepter la course. Réessayez.');
    } finally {
      if (mounted) setState(() => _accepting.remove(d.routeId));
    }
  }

  Future<void> _showCashCeilingDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // bloquante : seul « Fermer » la ferme
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(Icons.account_balance_wallet_rounded,
            color: AppColors.error, size: 36),
        title: const Text('Plafond atteint', textAlign: TextAlign.center),
        content: const Text(
          'Plafond d\'espèces atteint. Vous devez effectuer un reversement.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: success ? AppColors.success : AppColors.error,
        content: Text(msg),
      ));
  }

  // ── UI ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!widget.isOnline) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 90),
          _StateMessage(
            icon: Icons.power_settings_new_rounded,
            title: 'Vous êtes hors ligne',
            text: 'Passez en ligne pour voir et accepter des courses autour de vous.',
          ),
        ],
      );
    }
    if (_loading) {
      return Center(child: Swirling(size: 56, color: AppColors.brand));
    }
    if (_problem != null) return _problemView();

    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: _load,
      child: _items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 90),
                _StateMessage(
                  icon: Icons.delivery_dining_rounded,
                  title: 'Aucune course disponible',
                  text:
                      'Rien dans un rayon de 5 km pour le moment. Tirez pour actualiser.',
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (_, i) {
                final d = _items[i];
                return _DeliveryCard(
                  delivery: d,
                  accepting: _accepting.contains(d.routeId),
                  onAccept: () => _accept(d),
                );
              },
            ),
    );
  }

  Widget _problemView() {
    late final IconData icon;
    late final String title;
    late final String text;
    late final String action;
    late final VoidCallback onAction;

    switch (_problem!) {
      case _Problem.locationOff:
        icon = Icons.location_off_rounded;
        title = 'Localisation désactivée';
        text = 'Activez le GPS pour voir les courses autour de vous.';
        action = 'Activer la localisation';
        onAction = () async {
          await Geolocator.openLocationSettings();
          if (mounted) _load();
        };
        break;
      case _Problem.denied:
        icon = Icons.location_disabled_rounded;
        title = 'Autorisation requise';
        text = 'Autorisez l\'accès à votre position pour trouver des courses.';
        action = 'Autoriser';
        onAction = _load;
        break;
      case _Problem.deniedForever:
        icon = Icons.lock_rounded;
        title = 'Accès à la position refusé';
        text =
            'Ouvrez les réglages de l\'application pour autoriser la localisation.';
        action = 'Ouvrir les réglages';
        onAction = () async {
          await Geolocator.openAppSettings();
          if (mounted) _load();
        };
        break;
      case _Problem.network:
        icon = Icons.cloud_off_rounded;
        title = 'Chargement impossible';
        text = _error ?? 'Vérifiez votre connexion et réessayez.';
        action = 'Réessayer';
        onAction = _load;
        break;
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 90),
        _StateMessage(
          icon: icon,
          title: title,
          text: text,
          action: TextButton(onPressed: onAction, child: Text(action)),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Carte d'une course
// ═══════════════════════════════════════════════════════════
class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.delivery,
    required this.accepting,
    required this.onAccept,
  });

  final AvailableDelivery delivery;
  final bool accepting;
  final VoidCallback onAccept;

  String _money(double v) =>
      '${CurrencyUtil.symbol(delivery.currency)} ${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final d = delivery;
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border, width: 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête : restaurant + gain
          Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: brand.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.storefront_rounded, color: brand, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.restaurantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium(color: ink)
                          .copyWith(fontWeight: FontWeight.w800)),
                  if (d.orderNumber.isNotEmpty)
                    Text('Commande #${d.orderNumber}',
                        style: AppTypography.bodyMedium(color: muted)
                            .copyWith(fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(_money(d.deliveryFee),
                  style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 16),

          // Trajet
          _RouteLine(
            pickup: d.pickupAddress ?? 'Adresse du restaurant',
            dropoff: d.dropoffAddress ?? 'Adresse du client',
            ink: ink,
            muted: muted,
            brand: brand,
          ),
          const SizedBox(height: 14),

          // Infos
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (d.distanceKm != null)
              _Chip(Icons.near_me_rounded,
                  '${d.distanceKm!.toStringAsFixed(1)} km', muted),
            if (d.isCash)
              _Chip(
                Icons.payments_rounded,
                d.cashToCollect != null
                    ? 'Espèces : ${_money(d.cashToCollect!)}'
                    : 'Paiement en espèces',
                const Color(0xFFF59E0B),
              )
            else
              _Chip(Icons.verified_rounded, 'Déjà payée', AppColors.success),
          ]),
          const SizedBox(height: 16),

          OtpGradientButton(
            label: 'Accepter la course',
            icon: Icons.check_circle_outline_rounded,
            isLoading: accepting,
            onPressed: accepting ? null : onAccept,
          ),
        ],
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.pickup,
    required this.dropoff,
    required this.ink,
    required this.muted,
    required this.brand,
  });

  final String pickup, dropoff;
  final Color ink, muted, brand;

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, {bool filled = true}) => Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? c : Colors.transparent,
            border: Border.all(color: c, width: 2),
          ),
        );

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          const SizedBox(height: 4),
          dot(brand),
          Expanded(
            child: Container(
              width: 2,
              margin: const EdgeInsets.symmetric(vertical: 3),
              color: muted.withValues(alpha: 0.3),
            ),
          ),
          dot(AppColors.success, filled: false),
          const SizedBox(height: 4),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _line('Retrait', pickup),
              const SizedBox(height: 12),
              _line('Livraison', dropoff),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _line(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: ink, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      );
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.text, this.color);
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.text,
    this.action,
  });

  final IconData icon;
  final String title, text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(children: [
        Icon(icon, size: 56, color: muted.withValues(alpha: 0.6)),
        const SizedBox(height: 14),
        Text(title,
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium(color: ink)
                .copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(text,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium(color: muted).copyWith(height: 1.4)),
        if (action != null) ...[const SizedBox(height: 10), action!],
      ]),
    );
  }
}
