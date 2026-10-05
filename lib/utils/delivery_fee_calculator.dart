import 'dart:math';
import '../models/restaurant.dart';
import 'country_util.dart';
import 'currency_util.dart';

class DeliveryFeeEstimate {
  const DeliveryFeeEstimate({
    required this.fee,
    required this.formattedFee,
    required this.distanceKm,
    required this.distanceString,
    required this.isOutOfRange,
  });

  final double fee;
  final String formattedFee;
  final double distanceKm;
  final String distanceString;
  final bool isOutOfRange;

  /// Libellé combiné utile pour les cartes et détails (ex: "2 500 CDF • 3.2 km")
  String get summaryLabel => '$formattedFee • $distanceString';
}

class DeliveryFeeCalculator {
  const DeliveryFeeCalculator._();

  /// Facteur multiplicateur pour convertir la distance à vol d'oiseau (Haversine)
  /// en distance routière estimée (identique au backend).
  static const double roadFactor = 1.25;

  /// Calcule la distance Haversine en kilomètres.
  static double haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * (pi / 180.0);
    final dLon = (lon2 - lon1) * (pi / 180.0);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) *
            cos(lat2 * pi / 180.0) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  /// Estime les frais de livraison pour un restaurant donné en fonction de la position client.
  static DeliveryFeeEstimate estimateFeeForRestaurant({
    required double userLat,
    required double userLng,
    required Restaurant restaurant,
  }) {
    final restLat = restaurant.latitude;
    final restLng = restaurant.longitude;

    // Si les coordonnées du restaurant sont indisponibles, fallback sur tarif fixe ou défaut
    if (restLat == null || restLng == null) {
      final defaultFee = _getDefaultBaseFee(restaurant);
      final formatted = _formatFeeForRestaurant(defaultFee, restaurant);
      return DeliveryFeeEstimate(
        fee: defaultFee,
        formattedFee: formatted,
        distanceKm: 0.0,
        distanceString: '-- km',
        isOutOfRange: false,
      );
    }

    final birdDistance = haversineDistance(userLat, userLng, restLat, restLng);
    final roadDistance = birdDistance * roadFactor;
    final maxRadius =
        restaurant.deliveryRadius > 0 ? restaurant.deliveryRadius : 10.0;
    final isOutOfRange = birdDistance > maxRadius;

    double calculatedFee;
    if (restaurant.deliveryFee > 0) {
      // Tarif fixe défini par le restaurateur
      calculatedFee = restaurant.deliveryFee;
    } else {
      // Formule d'estimation par défaut selon le pays
      if (CountryUtil.isRdc(restaurant.country)) {
        // RDC : base 2000 CDF + (max(0, km - 2) * 500 CDF)
        const basePrice = 2000.0;
        const extraPerKm = 500.0;
        final extraKm = max(0.0, roadDistance - 2.0);
        calculatedFee = basePrice + (extraKm * extraPerKm);
      } else if (CountryUtil.isBenin(restaurant.country)) {
        // Bénin : base 500 XOF + (max(0, km - 2) * 150 XOF)
        const basePrice = 500.0;
        const extraPerKm = 150.0;
        final extraKm = max(0.0, roadDistance - 2.0);
        calculatedFee = basePrice + (extraKm * extraPerKm);
      } else {
        // Autres pays (défaut XOF)
        const basePrice = 500.0;
        const extraPerKm = 150.0;
        final extraKm = max(0.0, roadDistance - 2.0);
        calculatedFee = basePrice + (extraKm * extraPerKm);
      }
    }

    final formattedFee = _formatFeeForRestaurant(calculatedFee, restaurant);
    final distanceStr = '${roadDistance.toStringAsFixed(1)} km';

    return DeliveryFeeEstimate(
      fee: calculatedFee,
      formattedFee: formattedFee,
      distanceKm: roadDistance,
      distanceString: distanceStr,
      isOutOfRange: isOutOfRange,
    );
  }

  /// Retourne le libellé harmonisé lorsque la position client est inconnue (ex: "Dès 2 000 CDF")
  static String getStartingFeeLabel(Restaurant restaurant) {
    if (restaurant.deliveryFee > 0) {
      return _formatFeeForRestaurant(restaurant.deliveryFee, restaurant);
    }
    final base = _getDefaultBaseFee(restaurant);
    final formatted = _formatFeeForRestaurant(base, restaurant);
    return 'Dès $formatted';
  }

  static double _getDefaultBaseFee(Restaurant restaurant) {
    if (restaurant.deliveryFee > 0) return restaurant.deliveryFee;
    if (CountryUtil.isRdc(restaurant.country)) return 2000.0;
    return 500.0;
  }

  static String _formatFeeForRestaurant(double amount, Restaurant restaurant) {
    if (CountryUtil.isRdc(restaurant.country)) {
      return CurrencyUtil.formatConvertedPrice(
        amount,
        targetCurrency: 'CDF',
        sourceCurrency: 'CDF',
      );
    }
    return CurrencyUtil.formatConvertedPrice(
      amount,
      sourceCurrency: 'XOF',
    );
  }
}
