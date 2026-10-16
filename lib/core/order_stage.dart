import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/commande.dart';
import '../theme/app_theme.dart';
import 'commande_status.dart';

/// Étapes visibles d'une commande, communes à la liste et au détail.
/// Dérivées du statut serveur (CONFIRMED_CASH, PAID, EN_PREPARATION…) et du
/// statut de course du livreur.
enum OrderStage {
  awaitingPayment,
  received,
  preparing,
  ready,
  onTheWay,
  delivered,
  cancelled,
}

OrderStage orderStageOf(Commande c) {
  final status = CommandeStatus.normalize(c.status);
  if (status == CommandeStatus.cancelled || status == CommandeStatus.refused) {
    return OrderStage.cancelled;
  }
  final delivery = (c.deliveryStatus ?? '').trim();
  final deliveryStage =
      delivery.isEmpty ? null : DeliveryStatus.normalize(delivery);
  if (status == CommandeStatus.delivered ||
      deliveryStage == DeliveryStatus.delivered) {
    return OrderStage.delivered;
  }
  if (status == CommandeStatus.awaitingPayment) {
    return OrderStage.awaitingPayment;
  }
  if (deliveryStage == DeliveryStatus.pickedUp ||
      deliveryStage == DeliveryStatus.inTransit) {
    return OrderStage.onTheWay;
  }
  if (status == CommandeStatus.ready) return OrderStage.ready;
  if (status == CommandeStatus.preparing ||
      status == CommandeStatus.confirmed) {
    return OrderStage.preparing;
  }
  return OrderStage.received;
}

/// Encore modifiable par le client : avant le début de la préparation.
bool orderStageCancellableByCustomer(OrderStage stage) =>
    stage == OrderStage.awaitingPayment || stage == OrderStage.received;

/// Commande encore en cours (ni livrée ni annulée).
bool orderStageIsActive(OrderStage stage) =>
    stage != OrderStage.delivered && stage != OrderStage.cancelled;

String orderStageLabel(
  AppLocalizations l10n,
  OrderStage stage, {
  required bool pickup,
  bool refused = false,
}) {
  switch (stage) {
    case OrderStage.awaitingPayment:
      return l10n.order_stage_awaiting_payment;
    case OrderStage.received:
      return l10n.order_step_received;
    case OrderStage.preparing:
      return l10n.order_step_preparing;
    case OrderStage.ready:
      return pickup ? l10n.order_step_ready_pickup : l10n.order_step_ready;
    case OrderStage.onTheWay:
      return l10n.order_step_on_the_way;
    case OrderStage.delivered:
      return pickup ? l10n.order_step_picked_up : l10n.order_step_delivered;
    case OrderStage.cancelled:
      return refused ? l10n.order_stage_refused : l10n.order_stage_cancelled;
  }
}

Color orderStageColor(OrderStage stage) {
  switch (stage) {
    case OrderStage.awaitingPayment:
      return const Color(0xFFB7791F); // safran foncé, lisible sur fond clair
    case OrderStage.ready:
    case OrderStage.delivered:
      return AppColors.resolve(AppColors.success, AppDarkColors.success);
    case OrderStage.cancelled:
      return AppColors.resolve(AppColors.error, AppDarkColors.error);
    case OrderStage.received:
    case OrderStage.preparing:
    case OrderStage.onTheWay:
      return AppColors.resolve(AppColors.brand, AppDarkColors.brand);
  }
}

/// Commande refusée par le restaurant (et non annulée par le client).
bool orderWasRefused(Commande c) =>
    CommandeStatus.normalize(c.status) == CommandeStatus.refused;

/// Part du restaurant sur une commande : plats moins réductions, hors frais
/// de livraison. Même règle pour le tableau de bord et la page « Mes revenus ».
double orderFoodAmount(Commande c) {
  final subtotal = (c.subtotalAmount != null && c.subtotalAmount! > 0)
      ? c.subtotalAmount!
      : (c.totalAmount - c.fraisLivraison);
  return (subtotal - c.reduction).clamp(0.0, double.infinity).toDouble();
}
