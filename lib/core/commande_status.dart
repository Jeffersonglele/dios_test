import 'package:flutter/material.dart';

class CommandeStatus {
  const CommandeStatus._();

  static const pending = 'En attente';
  static const paid = 'Payée';
  static const confirmed = 'Confirmée';
  static const cancelled = 'Annulée';

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
