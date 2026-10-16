import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'session_service.dart';

// ═══════════════════════════════════════════════════════════
// Modèles + erreur lisible pour l'écran du portefeuille
// ═══════════════════════════════════════════════════════════
class WalletException implements Exception {
  WalletException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString().replaceAll(',', '.') ?? '') ?? 0;
}

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.createdAt,
    this.status,
  });

  final String id;
  final String type;
  final double amount;
  final String description;
  final DateTime? createdAt;
  final String? status;

  /// Vrai pour une entrée d'argent (recharge, remboursement…).
  bool get isCredit {
    final t = type.toUpperCase();
    const debit = ['DEBIT', 'PAYMENT', 'PURCHASE', 'WITHDRAW', 'ORDER', 'SPEND'];
    const credit = ['CREDIT', 'TOP', 'DEPOSIT', 'REFUND', 'RECHARGE', 'GAIN'];
    if (debit.any(t.contains)) return false;
    if (credit.any(t.contains)) return true;
    return amount >= 0;
  }

  bool get isPending {
    final s = (status ?? '').toUpperCase();
    return s == 'PENDING' || s == 'PROCESSING';
  }

  bool get isFailed {
    final s = (status ?? '').toUpperCase();
    return s == 'FAILED' || s == 'CANCELLED' || s == 'REJECTED';
  }

  factory WalletTransaction.fromJson(Map<String, dynamic> j) {
    return WalletTransaction(
      id: (j['id'] ?? j['transactionId'] ?? '').toString(),
      type: (j['direction'] ?? j['type'] ?? j['kind'] ?? '').toString(),
      amount: _toDouble(j['amount']).abs(),
      description:
          (j['description'] ?? j['label'] ?? j['reason'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((j['createdAt'] ?? j['date'] ?? '').toString())
              ?.toLocal(),
      status: j['status']?.toString(),
    );
  }
}

class WalletData {
  const WalletData({
    required this.balance,
    required this.transactions,
    this.currency = 'CDF',
  });
  final double balance;
  final List<WalletTransaction> transactions;

  /// Devise dans laquelle le solde est tenu côté serveur (CDF ou USD).
  final String currency;
}

/// Session Nyole ouverte pour une recharge du portefeuille.
class TopUpSession {
  const TopUpSession({
    required this.transactionId,
    required this.paymentUrl,
    required this.amount,
    required this.currency,
  });
  final String transactionId;
  final String paymentUrl;
  final double amount;
  final String currency;
}

/// Statut d'un paiement Nyole tel que vérifié par le serveur.
enum TopUpStatus { paid, pending, failed }

class WalletService {
  static Uri _uri(String path) {
    final base = AppConfig.nodeBackendUrl.replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base/api/v1$path');
  }

  static Future<Map<String, dynamic>?> getWallet() async {
    try {
      final token = await SessionService.readNodeToken();
      if (token == null) return null;

      final response = await http.get(
        _uri('/wallet'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Error fetching wallet: $e');
      return null;
    }
  }

  /// POST /orders/{orderId}/pay-wallet
  /// Lève une WalletException : statusCode == 400 → solde insuffisant.
  static Future<Map<String, dynamic>?> payOrderWithWallet(String orderId) =>
      _guard(() async {
        final res = await http
            .post(
              _uri('/orders/$orderId/pay-wallet'),
              headers: await _authHeaders(),
            )
            .timeout(const Duration(seconds: 30));
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final d = _dataOf(res);
          return d.isEmpty ? null : d;
        }
        throw WalletException(
          _errorMessage(
            res,
            res.statusCode == 400
                ? 'Solde insuffisant'
                : 'Le paiement par portefeuille a échoué.',
          ),
          statusCode: res.statusCode,
        );
      });

  // ═════════════════════════════════════════════════════════
  // Variantes pour WalletScreen : mêmes routes, mais elles LÈVENT une
  // WalletException (message clair) au lieu de renvoyer null.
  // Les trois méthodes ci-dessus restent inchangées pour vos autres écrans.
  // ═════════════════════════════════════════════════════════
  static Future<Map<String, String>> _authHeaders() async {
    final token = await SessionService.readNodeToken();
    if (token == null || token.isEmpty) {
      throw WalletException('Session expirée. Reconnectez-vous.',
          statusCode: 401);
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static String _errorMessage(http.Response res, String fallback) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map) {
        // Le backend répond { error: { message } }.
        final error = body['error'];
        final m = body['message'] ??
            (error is Map ? error['message'] : error);
        if (m != null && m.toString().trim().isNotEmpty) return m.toString();
      }
    } catch (_) {}
    return fallback;
  }

  static Map<String, dynamic> _dataOf(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map) {
        final data = body['data'];
        return Map<String, dynamic>.from(data is Map ? data : body);
      }
    } catch (_) {}
    return {};
  }

  static Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on WalletException {
      rethrow;
    } on TimeoutException {
      throw WalletException('Le serveur met trop de temps à répondre.');
    } on SocketException {
      throw WalletException('Connexion impossible. Vérifiez votre réseau.');
    } on http.ClientException {
      throw WalletException('Connexion impossible. Vérifiez votre réseau.');
    }
  }

  /// GET /wallet → solde + historique (trié du plus récent au plus ancien).
  static Future<WalletData> fetchWallet() => _guard(() async {
        final res = await http
            .get(_uri('/wallet'), headers: await _authHeaders())
            .timeout(const Duration(seconds: 30));
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw WalletException(
            _errorMessage(res, 'Impossible de charger le portefeuille.'),
            statusCode: res.statusCode,
          );
        }
        final j = _dataOf(res);
        final wallet = j['wallet'] is Map ? j['wallet'] as Map : j;
        final rawTx = j['ledgerEntries'] ??
            wallet['ledgerEntries'] ??
            j['transactions'] ??
            wallet['transactions'];
        final txs = <WalletTransaction>[
          if (rawTx is List)
            for (final t in rawTx)
              if (t is Map)
                WalletTransaction.fromJson(Map<String, dynamic>.from(t)),
        ]..sort((a, b) {
            final da = a.createdAt, db = b.createdAt;
            if (da == null || db == null) return 0;
            return db.compareTo(da);
          });
        return WalletData(
          balance: _toDouble(wallet['balance']),
          transactions: txs,
          currency: (wallet['currency'] ?? 'CDF').toString().toUpperCase(),
        );
      });

  /// POST /wallet/top-ups { amount, currency } → session Nyole.
  /// Le solde n'est crédité qu'après confirmation du paiement côté serveur.
  static Future<TopUpSession> startTopUp({
    required int amount,
    required String currency,
  }) =>
      _guard(() async {
        final res = await http
            .post(
              _uri('/wallet/top-ups'),
              headers: await _authHeaders(),
              body: jsonEncode({'amount': amount, 'currency': currency}),
            )
            .timeout(const Duration(seconds: 45));
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw WalletException(
            _errorMessage(res, 'Impossible de lancer la recharge. Réessayez.'),
            statusCode: res.statusCode,
          );
        }
        final j = _dataOf(res);
        final url = j['paymentUrl']?.toString() ?? '';
        final id = j['transactionId']?.toString() ?? '';
        if (url.isEmpty || id.isEmpty) {
          throw WalletException('Page de paiement introuvable. Réessayez.');
        }
        return TopUpSession(
          transactionId: id,
          paymentUrl: url,
          amount: _toDouble(j['amount']),
          currency: j['currency']?.toString() ?? currency,
        );
      });

  /// GET /payments/nyole/{transactionId} : le serveur interroge Nyole si
  /// le paiement n'est pas encore tranché.
  static Future<TopUpStatus> fetchPaymentStatus(String transactionId) =>
      _guard(() async {
        final res = await http
            .get(
              _uri('/payments/nyole/${Uri.encodeComponent(transactionId)}'),
              headers: await _authHeaders(),
            )
            .timeout(const Duration(seconds: 30));
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw WalletException(
            _errorMessage(res, 'Impossible de vérifier le paiement.'),
            statusCode: res.statusCode,
          );
        }
        final status = _dataOf(res)['status']?.toString().toUpperCase() ?? '';
        if (status == 'PAID') return TopUpStatus.paid;
        if (status == 'FAILED' || status == 'CANCELLED') {
          return TopUpStatus.failed;
        }
        return TopUpStatus.pending;
      });

  /// Attend la confirmation serveur d'une recharge (webhook ou vérification
  /// Nyole), au plus [timeout]. Retourne `pending` si rien n'est tranché.
  static Future<TopUpStatus> waitForTopUp(
    String transactionId, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      try {
        final status = await fetchPaymentStatus(transactionId);
        if (status != TopUpStatus.pending) return status;
      } on WalletException {
        // Réseau instable : on réessaie jusqu'à l'échéance.
      }
      if (DateTime.now().isAfter(deadline)) return TopUpStatus.pending;
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }
}