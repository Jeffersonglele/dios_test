import 'package:dios_delices/services/restaurant_opening_hours_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RestaurantOpeningHoursService', () {
    const days = 'Lun,Mar,Mer,Jeu,Ven,Sam';

    test('opens and closes according to the configured hours', () {
      final beforeOpening = RestaurantOpeningHoursService.status(
        openingDays: days,
        openingHours: '12:00 - 20:00',
        now: DateTime(2026, 9, 14, 11, 59),
      );
      final duringService = RestaurantOpeningHoursService.status(
        openingDays: days,
        openingHours: '12:00 - 20:00',
        now: DateTime(2026, 9, 14, 12),
      );

      expect(beforeOpening.isOpen, isFalse);
      expect(beforeOpening.opensAt, '12:00');
      expect(duringService.isOpen, isTrue);
    });

    test('returns the next configured day when today is closed', () {
      final status = RestaurantOpeningHoursService.status(
        openingDays: days,
        openingHours: '12:00 - 20:00',
        now: DateTime(2026, 9, 13, 12),
      );

      expect(status.isOpen, isFalse);
      expect(status.opensOn, 'Lun');
      expect(status.opensAt, '12:00');
    });

    test('supports overnight hours', () {
      final afterMidnight = RestaurantOpeningHoursService.status(
        openingDays: 'Dim,Lun',
        openingHours: '18:00 - 02:00',
        now: DateTime(2026, 9, 14, 1),
      );
      final beforeOpening = RestaurantOpeningHoursService.status(
        openingDays: 'Lun',
        openingHours: '18:00 - 02:00',
        now: DateTime(2026, 9, 14, 3),
      );

      expect(afterMidnight.isOpen, isTrue);
      expect(beforeOpening.isOpen, isFalse);
      expect(beforeOpening.opensAt, '18:00');
    });

    test('manual closure takes precedence over the schedule', () {
      final status = RestaurantOpeningHoursService.status(
        openingDays: days,
        openingHours: '00:00 - 23:59',
        manualStatus: 0,
        now: DateTime(2026, 9, 14, 12),
      );

      expect(status.isOpen, isFalse);
      expect(status.isClosedManually, isTrue);
    });
  });
}
