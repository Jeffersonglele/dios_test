import 'dart:convert';

class RestaurantOpeningStatus {
  const RestaurantOpeningStatus({
    required this.isOpen,
    this.opensAt,
    this.opensOn,
    this.isClosedManually = false,
  });

  final bool isOpen;
  final String? opensAt;
  final String? opensOn;
  final bool isClosedManually;

  bool get opensLaterToday => opensAt != null && opensOn == null;
}

class RestaurantOpeningHoursService {
  const RestaurantOpeningHoursService._();

  static RestaurantOpeningStatus status({
    required String openingDays,
    required String openingHours,
    String openingHoursByDay = '',
    int manualStatus = 1,
    DateTime? now,
  }) {
    if (manualStatus == 0) {
      return const RestaurantOpeningStatus(
        isOpen: false,
        isClosedManually: true,
      );
    }

    final schedules = _parseSchedules(
      openingDays,
      openingHours,
      openingHoursByDay,
    );
    if (schedules.isEmpty) {
      // Compatibilité avec les anciennes fiches sans horaires exploitables.
      return const RestaurantOpeningStatus(isOpen: true);
    }

    final current = now ?? DateTime.now();
    final currentMinutes = current.hour * 60 + current.minute;

    // Un créneau qui traverse minuit appartient aussi aux premières heures
    // du jour suivant (ex. 18:00 - 02:00).
    final previousDay = current.weekday == DateTime.monday
        ? DateTime.sunday
        : current.weekday - 1;
    final previousRange = schedules[previousDay];
    if (previousRange != null &&
        previousRange.isOvernight &&
        currentMinutes < previousRange.end) {
      return const RestaurantOpeningStatus(isOpen: true);
    }

    final todayRange = schedules[current.weekday];
    if (todayRange != null) {
      if (todayRange.contains(currentMinutes)) {
        return const RestaurantOpeningStatus(isOpen: true);
      }
      if (todayRange.isOvernight && currentMinutes >= todayRange.end) {
        return RestaurantOpeningStatus(
          isOpen: false,
          opensAt: _formatMinutes(todayRange.start),
        );
      }
      if (!todayRange.isOvernight && currentMinutes < todayRange.start) {
        return RestaurantOpeningStatus(
          isOpen: false,
          opensAt: _formatMinutes(todayRange.start),
        );
      }
    }

    // Cherche le prochain jour ouvert dans les 7 jours à venir.
    for (var offset = 1; offset <= 7; offset++) {
      final weekday = ((current.weekday - 1 + offset) % 7) + 1;
      final range = schedules[weekday];
      if (range != null) {
        return RestaurantOpeningStatus(
          isOpen: false,
          opensAt: _formatMinutes(range.start),
          opensOn: _dayShortName(weekday),
        );
      }
    }

    return const RestaurantOpeningStatus(isOpen: false);
  }

  static Map<int, _TimeRange> _parseSchedules(
    String openingDays,
    String openingHours,
    String openingHoursByDay,
  ) {
    final globalRange = _parseRange(openingHours);
    final days = <int>{};
    for (final value in openingDays.split(RegExp(r'[,;|]'))) {
      final day = _parseDay(value);
      if (day != null) days.add(day);
    }

    final schedules = <int, _TimeRange>{};
    Map<String, dynamic> perDay = {};
    if (openingHoursByDay.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(openingHoursByDay);
        if (decoded is Map) {
          perDay = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    for (final entry in perDay.entries) {
      final day = _parseDay(entry.key);
      final range = _parseRangeValue(entry.value) ?? globalRange;
      if (day != null && range != null) schedules[day] = range;
    }

    if (globalRange != null) {
      for (final day in days) {
        schedules.putIfAbsent(day, () => globalRange);
      }
    }
    return schedules;
  }

  static _TimeRange? _parseRangeValue(dynamic value) {
    if (value is String) return _parseRange(value);
    if (value is Map) {
      final start = value['open'] ?? value['start'] ?? value['from'];
      final end = value['close'] ?? value['end'] ?? value['to'];
      if (start != null && end != null) {
        return _parseRange('$start - $end');
      }
    }
    return null;
  }

  static _TimeRange? _parseRange(String value) {
    final matches = RegExp(
      r'(\d{1,2})\s*(?::|h)\s*(\d{2})\s*(?:-|–|—|à|a)\s*'
      r'(\d{1,2})\s*(?::|h)\s*(\d{2})',
      caseSensitive: false,
    ).firstMatch(value);
    if (matches == null) return null;
    final startHour = int.tryParse(matches.group(1)!);
    final startMinute = int.tryParse(matches.group(2)!);
    final endHour = int.tryParse(matches.group(3)!);
    final endMinute = int.tryParse(matches.group(4)!);
    if (startHour == null ||
        startMinute == null ||
        endHour == null ||
        endMinute == null ||
        startHour > 23 ||
        endHour > 23 ||
        startMinute > 59 ||
        endMinute > 59) {
      return null;
    }
    return _TimeRange(
      startHour * 60 + startMinute,
      endHour * 60 + endMinute,
    );
  }

  static int? _parseDay(String value) {
    final day = _withoutAccents(value.trim().toLowerCase());
    const names = {
      'lun': 1,
      'lundi': 1,
      'mon': 1,
      'monday': 1,
      'mar': 2,
      'mardi': 2,
      'tue': 2,
      'tuesday': 2,
      'mer': 3,
      'mercredi': 3,
      'wed': 3,
      'wednesday': 3,
      'jeu': 4,
      'jeudi': 4,
      'thu': 4,
      'thursday': 4,
      'ven': 5,
      'vendredi': 5,
      'fri': 5,
      'friday': 5,
      'sam': 6,
      'samedi': 6,
      'sat': 6,
      'saturday': 6,
      'dim': 7,
      'dimanche': 7,
      'sun': 7,
      'sunday': 7,
    };
    return names[day] ?? int.tryParse(day);
  }

  static String _withoutAccents(String value) => value
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ë', 'e')
      .replaceAll('à', 'a')
      .replaceAll('ù', 'u');

  static String _formatMinutes(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  static String _dayShortName(int weekday) => const [
        '',
        'Lun',
        'Mar',
        'Mer',
        'Jeu',
        'Ven',
        'Sam',
        'Dim',
      ][weekday];
}

class _TimeRange {
  const _TimeRange(this.start, this.end);

  final int start;
  final int end;

  bool get isOvernight => end < start;

  bool contains(int minutes) {
    if (isOvernight) return minutes >= start || minutes < end;
    return minutes >= start && minutes < end;
  }
}
