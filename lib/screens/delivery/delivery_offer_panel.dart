import 'dart:async';

import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/currency_util.dart';
import 'package:dios_delices/widgets/order_otp_widgets.dart'
    show OtpGradientButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../services/delivery_orders_service.dart';
import '../../services/socket_service.dart';

/// Proposition de course automatique (dispatch serveur) affichée en haut du
/// dashboard livreur, avec compte à rebours et boutons Accepter / Refuser.
///
/// Les propositions arrivent par le socket (« delivery_offer ») et sont aussi
/// relues toutes les 10 s via GET /couriers/me/offers tant que le livreur est
/// en ligne. L'onglet « Disponibles » reste la solution de secours.
class DeliveryOfferPanel extends StatefulWidget {
  const DeliveryOfferPanel({
    super.key,
    required this.isOnline,
    this.onAccepted,
  });

  final bool isOnline;
  final Future<void> Function(DeliveryOffer offer)? onAccepted;

  @override
  State<DeliveryOfferPanel> createState() => _DeliveryOfferPanelState();
}

class _DeliveryOfferPanelState extends State<DeliveryOfferPanel> {
  static const _pollEvery = Duration(seconds: 10);

  /// Propositions en attente, la plus ancienne en premier.
  final List<DeliveryOffer> _offers = [];

  /// Durée totale de chaque proposition au moment où on l'a reçue (anneau).
  final Map<String, Duration> _windows = {};
  Timer? _poll;
  Timer? _tick;
  StreamSubscription<Map<String, dynamic>>? _socketSub;
  String? _busy; // 'accept' | 'reject'

  @override
  void initState() {
    super.initState();
    _socketSub = SocketService().onDeliveryOffer.listen(_onSocketOffer);
    if (widget.isOnline) _start();
  }

  @override
  void didUpdateWidget(covariant DeliveryOfferPanel old) {
    super.didUpdateWidget(old);
    if (!old.isOnline && widget.isOnline) _start();
    if (old.isOnline && !widget.isOnline) _stop();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    _socketSub?.cancel();
    super.dispose();
  }

  void _start() {
    _poll?.cancel();
    _poll = Timer.periodic(_pollEvery, (_) => _refresh());
    _refresh();
  }

  void _stop() {
    _poll?.cancel();
    _tick?.cancel();
    _poll = null;
    _tick = null;
    if (mounted) {
      setState(() {
        _offers.clear();
        _windows.clear();
      });
    }
  }

  /// Le compte à rebours ne tourne que lorsqu'une proposition est affichée.
  void _ensureTicking() {
    if (_offers.isEmpty) {
      _tick?.cancel();
      _tick = null;
      return;
    }
    _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final hadExpired = _offers.any((o) => o.isExpired);
      setState(() => _offers.removeWhere((o) => o.isExpired));
      if (hadExpired) _ensureTicking();
    });
  }

  /// Ajoute les nouvelles propositions sans remplacer celles déjà affichées
  /// (sinon l'anneau du compte à rebours repartirait de zéro).
  void _merge(Iterable<DeliveryOffer> incoming, {bool replace = false}) {
    final ids = incoming.map((o) => o.id).toSet();
    var added = false;
    setState(() {
      if (replace) _offers.removeWhere((o) => !ids.contains(o.id));
      for (final offer in incoming) {
        if (offer.isExpired || _offers.any((o) => o.id == offer.id)) continue;
        _offers.add(offer);
        _windows[offer.id] = offer.remaining;
        added = true;
      }
      _windows.removeWhere((id, _) => !_offers.any((o) => o.id == id));
    });
    if (added) HapticFeedback.heavyImpact();
    _ensureTicking();
  }

  Future<void> _refresh() async {
    if (!widget.isOnline || _busy != null) return;
    try {
      final offers = await DeliveryOrdersService.fetchMyOffers();
      if (!mounted || !widget.isOnline || _busy != null) return;
      _merge(offers, replace: true);
    } catch (_) {
      // Silencieux : on réessaiera au prochain passage.
    }
  }

  void _onSocketOffer(Map<String, dynamic> data) {
    if (!mounted || !widget.isOnline) return;
    try {
      _merge([DeliveryOffer.fromJson(data)]);
    } catch (_) {}
  }

  void _drop(DeliveryOffer offer) {
    setState(() {
      _offers.removeWhere((o) => o.id == offer.id);
      _windows.remove(offer.id);
    });
    _ensureTicking();
  }

  Future<void> _accept(DeliveryOffer offer) async {
    if (_busy != null) return;
    setState(() => _busy = 'accept');
    try {
      await DeliveryOrdersService.acceptOffer(offer.id);
      if (!mounted) return;
      setState(() {
        _offers.clear();
        _windows.clear();
      });
      _ensureTicking();
      _snack('Course acceptée', success: true);
      await widget.onAccepted?.call(offer);
    } on DeliveryException catch (e) {
      if (!mounted) return;
      if (e.isConflict) {
        _drop(offer);
        _snack('Cette course n\'est plus disponible.');
      } else {
        _snack(e.message);
      }
    } catch (_) {
      if (mounted) _snack('Impossible d\'accepter la course. Réessayez.');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _reject(DeliveryOffer offer) async {
    if (_busy != null) return;
    setState(() => _busy = 'reject');
    try {
      await DeliveryOrdersService.rejectOffer(offer.id);
      if (mounted) _drop(offer);
    } on DeliveryException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('Impossible de refuser la course. Réessayez.');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: success ? AppColors.success : AppColors.error,
        content: Text(msg),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.isOnline && _offers.isNotEmpty ? _offers.first : null;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: offer == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: _OfferCard(
                offer: offer,
                window: _windows[offer.id] ?? offer.remaining,
                waiting: _offers.length - 1,
                busy: _busy,
                onAccept: () => _accept(offer),
                onReject: () => _reject(offer),
              ),
            ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.window,
    required this.waiting,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });

  final DeliveryOffer offer;
  final Duration window;
  final int waiting;
  final String? busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  String _money(double v) =>
      '${CurrencyUtil.symbol(offer.currency)} ${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);

    final left = offer.remaining.inSeconds;
    final total = window.inSeconds <= 0 ? 1 : window.inSeconds;
    final progress = (left / total).clamp(0.0, 1.0);
    final urgent = left <= 10;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: brand, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: brand.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    waiting > 0
                        ? 'Nouvelle course proposée (+$waiting)'
                        : 'Nouvelle course proposée',
                    style: TextStyle(
                        color: brand,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3),
                  ),
                  const SizedBox(height: 4),
                  Text(offer.restaurantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium(color: ink)
                          .copyWith(fontWeight: FontWeight.w800)),
                  if (offer.pickupAddress != null)
                    Text(offer.pickupAddress!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium(color: muted)
                            .copyWith(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Compte à rebours
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 4,
                    color: urgent ? AppColors.error : brand,
                    backgroundColor: muted.withValues(alpha: 0.15),
                  ),
                ),
                Text('${left}s',
                    style: TextStyle(
                        color: urgent ? AppColors.error : ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _Pill(Icons.payments_outlined, _money(offer.deliveryFee),
                AppColors.success),
            if (offer.distanceToPickupKm != null)
              _Pill(
                  Icons.storefront_rounded,
                  'Retrait à ${offer.distanceToPickupKm!.toStringAsFixed(1)} km',
                  muted),
            if (offer.deliveryDistanceKm != null)
              _Pill(
                  Icons.near_me_rounded,
                  'Course ${offer.deliveryDistanceKm!.toStringAsFixed(1)} km',
                  muted),
            if (offer.isCash)
              _Pill(
                Icons.account_balance_wallet_rounded,
                offer.totalAmount != null
                    ? 'Espèces : ${_money(offer.totalAmount!)}'
                    : 'Paiement en espèces',
                const Color(0xFFF59E0B),
              ),
          ]),
          if (offer.dropoffAddress != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.location_on_outlined, size: 16, color: muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(offer.dropoffAddress!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: ink, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ]),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: busy == null ? onReject : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: muted,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: busy == 'reject'
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Refuser',
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: OtpGradientButton(
                label: 'Accepter',
                icon: Icons.check_circle_outline_rounded,
                isLoading: busy == 'accept',
                onPressed: busy == null ? onAccept : null,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.icon, this.text, this.color);
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
