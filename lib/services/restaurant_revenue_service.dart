import '../core/order_stage.dart';
import '../models/commande.dart';
import '../models/restaurant.dart';
import 'session_service.dart';

/// Revenus d'une journée (pour les graphiques).
class RevenueDay {
  const RevenueDay({
    required this.date,
    required this.revenue,
    required this.orders,
  });

  /// AAAA-MM-JJ (date locale).
  final String date;
  final double revenue;
  final int orders;
}

/// Synthèse des revenus du restaurant sur une période.
class RevenueSummary {
  const RevenueSummary({
    required this.deliveredOrders,
    required this.revenue,
    required this.inProgress,
    required this.toProcess,
    required this.country,
    required this.days,
  });

  /// Commandes livrées sur la période.
  final int deliveredOrders;

  /// Plats des commandes livrées, réductions déduites, hors livraison.
  final double revenue;

  /// Montant des commandes acceptées mais pas encore livrées.
  final double inProgress;

  /// Commandes en attente d'une réponse du restaurant (toutes dates).
  final int toProcess;

  /// Pays du restaurant (devise d'affichage).
  final String country;

  final List<RevenueDay> days;

  static const empty = RevenueSummary(
    deliveredOrders: 0,
    revenue: 0,
    inProgress: 0,
    toProcess: 0,
    country: 'RDC',
    days: [],
  );
}

/// Calcul des revenus restaurateur depuis les commandes synchronisées avec
/// le backend Node. Même règle partout : tableau de bord, « Mon espace »,
/// page « Mes revenus ».
class RestaurantRevenueService {
  const RestaurantRevenueService._();

  static String isoDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// [start] et [end] : dates locales, fin incluse.
  static Future<RevenueSummary> compute({
    required DateTime start,
    required DateTime end,
    bool refresh = true,
  }) async {
    final session = await SessionService.readSession();
    final restaurantId = session.restaurantId;
    if (restaurantId == null) return RevenueSummary.empty;

    if (refresh) {
      try {
        await Commande.refreshLocalCommandes();
      } catch (_) {
        // Hors ligne : calcul sur le cache local.
      }
    }
    final all = await Commande.fetchCommandesFromDB();
    final restaurants = await Restaurant.fetchRestaurantsFromDB();
    final restaurant =
        Restaurant.getRestaurantByRestaurantId(restaurants, restaurantId);
    final restoCountry = (restaurant?.country ?? '').trim();
    final country = restoCountry.isNotEmpty ? restoCountry : session.country;

    final mine = all.where((c) {
      final ownsRestaurant = c.restauID == restaurantId && c.restauID != 0;
      final ownsOrder =
          c.restaurateurID == session.userId && c.restaurateurID != 0;
      return ownsRestaurant || ownsOrder;
    }).toList();

    final from = DateTime(start.year, start.month, start.day);
    final to = DateTime(end.year, end.month, end.day).add(const Duration(days: 1));

    final perDay = <String, RevenueDay>{};
    for (var d = from; d.isBefore(to); d = d.add(const Duration(days: 1))) {
      final key = isoDay(d);
      perDay[key] = RevenueDay(date: key, revenue: 0, orders: 0);
    }

    var delivered = 0;
    var revenue = 0.0;
    var inProgress = 0.0;
    var toProcess = 0;
    for (final c in mine) {
      final stage = orderStageOf(c);
      if (stage == OrderStage.received) toProcess++;
      final date = c.dateCommande.toLocal();
      if (date.isBefore(from) || !date.isBefore(to)) continue;
      if (stage == OrderStage.cancelled || stage == OrderStage.awaitingPayment) {
        continue;
      }
      final amount = orderFoodAmount(c);
      if (stage != OrderStage.delivered) {
        inProgress += amount;
        continue;
      }
      delivered++;
      revenue += amount;
      final key = isoDay(date);
      final day = perDay[key];
      if (day != null) {
        perDay[key] = RevenueDay(
          date: key,
          revenue: day.revenue + amount,
          orders: day.orders + 1,
        );
      }
    }

    return RevenueSummary(
      deliveredOrders: delivered,
      revenue: revenue,
      inProgress: inProgress,
      toProcess: toProcess,
      country: country,
      days: perDay.values.toList(),
    );
  }

  /// Mois en cours (du 1er à aujourd'hui).
  static Future<RevenueSummary> currentMonth({bool refresh = true}) {
    final now = DateTime.now();
    return compute(
      start: DateTime(now.year, now.month, 1),
      end: now,
      refresh: refresh,
    );
  }
}
