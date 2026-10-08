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
  const WalletData({required this.balance, required this.transactions});
  final double balance;
  final List<WalletTransaction> transactions;
}

class TopUpResult {
  const TopUpResult({required this.message, this.newBalance});
  final String message;
  final double? newBalance;
}

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

  static Future<Map<String, dynamic>?> topUpWallet({
    required double amount,
    required String referenceId,
  }) async {
    try {
      final token = await SessionService.readNodeToken();
      if (token == null) return null;

      final response = await http.post(
        _uri('/wallet/top-up'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amount': amount,
          'referenceId': referenceId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Error topping up wallet: $e');
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
        final m = body['message'] ?? body['error'];
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
            balance: _toDouble(wallet['balance']), transactions: txs);
      });

  /// POST /wallet/top-up  { amount, referenceId }
  /// referenceId : identifiant unique de la demande, généré ici
  /// (votre backend l'exige déjà dans l'ancienne version).
  static Future<TopUpResult> requestTopUp({
    required double amount,
    String? phone, // non envoyé : l'API actuelle ne lit que amount + referenceId
    String? referenceId,
  }) =>
      _guard(() async {
        final res = await http
            .post(
              _uri('/wallet/top-up'),
              headers: await _authHeaders(),
              body: jsonEncode({
                'amount': amount,
                'referenceId': referenceId ??
                    'MOBILE_MONEY_${DateTime.now().millisecondsSinceEpoch}',
              }),
            )
            .timeout(const Duration(seconds: 60));
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw WalletException(
            _errorMessage(res, 'La recharge a échoué. Réessayez.'),
            statusCode: res.statusCode,
          );
        }
        String message = 'Recharge effectuée avec succès.';
        try {
          final body = jsonDecode(res.body);
          if (body is Map && body['message'] != null) {
            message = body['message'].toString();
          }
        } catch (_) {}
        final j = _dataOf(res);
        final wallet = j['wallet'] is Map ? j['wallet'] as Map : j;
        return TopUpResult(
          message: message,
          newBalance:
              wallet['balance'] == null ? null : _toDouble(wallet['balance']),
        );
      });
}