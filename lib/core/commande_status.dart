import 'package:flutter/material.dart';

class CommandeStatus {
  const CommandeStatus._();

  static const pending = 'En attente';
  static const paid = 'Payée';
  static const confirmed = 'Confirmée';
  static const cancelled = 'Annulée';
  static const delivered = 'Livrée';

  static String normalize(String? status) {
    final value = (status ?? '').trim();
    if (value.isEmpty) {
      return pending;
    }
    return value;
  }

  static bool isPending(String? status) => normalize(status) == pending;
  static bool isConfirmed(String? status) => normalize(status) == confirmed;
  static bool isCancelled(String? status) => normalize(status) == cancelled;

  static Color color(String? status) {
    switch (normalize(status)) {
      case paid:
        return Colors.blue;
      case confirmed:
        return Colors.green;
      case cancelled:
        return Colors.red;
      case pending:
      default:
        return Colors.orange;
    }
  }
}

class DeliveryStatus {
  const DeliveryStatus._();

  static const assigned = 'assigned';
  static const pickedUp = 'picked_up';
  static const inTransit = 'in_transit';
  static const delivered = 'delivered';

  static String normalize(String? status) {
    final raw = (status ?? '').trim().toLowerCase();
    if (raw.isEmpty) return assigned;

    const assignedVariants = {
      'assigned', 'assigne', 'assigné', 'assigner', 'a assigner',
      'driver_assigned', 'driverassigned', 'nouvelle', 'new',
    };
    const pickedUpVariants = {
      'picked_up', 'pickedup', 'picked', 'recupere', 'récupéré',
      'récupérée', 'recuperee', 'collected', 'pickup',
    };
    const inTransitVariants = {
      'in_transit', 'intransit', 'transit', 'en route', 'enroute',
      'en_cours', 'encours', 'on the way', 'ontheway', 'shipping',
      'en livraison', 'enlivraison', 'delivery_in_progress',
    };
    const deliveredVariants = {
      'delivered', 'deliver', 'livre', 'livré', 'livrée', 'completed',
      'complete', 'termine', 'terminé', 'terminée', 'finie',
    };

    if (assignedVariants.contains(raw)) return assigned;
    if (pickedUpVariants.contains(raw)) return pickedUp;
    if (inTransitVariants.contains(raw)) return inTransit;
    if (deliveredVariants.contains(raw)) return delivered;

    if (raw.contains('assign') || raw.contains('nouvell') || raw == 'new') {
      return assigned;
    }
    if (raw.contains('recuper') || raw.contains('pick') || raw.contains('collect')) {
      return pickedUp;
    }
    if (raw.contains('transit') || raw.contains('route') || raw.contains('cours') || raw.contains('way') || raw.contains('ship')) {
      return inTransit;
    }
    if (raw.contains('deliv') || raw.contains('livr') || raw.contains('termin') || raw.contains('complet') || raw.contains('fini')) {
      return delivered;
    }

    return assigned;
  }

  static bool isAssigned(String? status) => normalize(status) == assigned;
  static bool isPickedUp(String? status) => normalize(status) == pickedUp;
  static bool isInTransit(String? status) => normalize(status) == inTransit;
  static bool isDelivered(String? status) => normalize(status) == delivered;
}
