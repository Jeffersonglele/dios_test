import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/restaurant_opening_hours_service.dart';
import '../theme/app_theme.dart';

Future<void> showDeliveryUnavailableSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE4E4E4),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.delivery_unavailable_title,
              textAlign: TextAlign.center,
              style: AppTypography.titleLarge().copyWith(
                fontSize: 22,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.delivery_unavailable_close),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> showRestaurantClosedSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE4E4E4),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.restaurant_closed_detail,
              textAlign: TextAlign.center,
              style: AppTypography.titleLarge().copyWith(
                fontSize: 21,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.delivery_unavailable_close),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class DeliveryUnavailableBanner extends StatelessWidget {
  const DeliveryUnavailableBanner({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final child = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off_rounded, size: 20, color: AppColors.inkMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.delivery_unavailable_detail,
              style: AppTypography.bodyMedium(color: AppColors.inkMuted),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.inkMuted),
          ],
        ],
      ),
    );
    return onTap == null ? child : GestureDetector(onTap: onTap, child: child);
  }
}

class RestaurantClosedBanner extends StatelessWidget {
  const RestaurantClosedBanner({
    super.key,
    required this.status,
    this.onTap,
  });

  final RestaurantOpeningStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final message = status.isClosedManually
        ? l10n.restaurant_closed_manually
        : status.opensLaterToday
            ? l10n.restaurant_opens_at(status.opensAt!)
            : status.opensOn != null
                ? l10n.restaurant_opens_on(
                    status.opensOn!, status.opensAt ?? '')
                : l10n.restaurant_closed_today;
    final child = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentLight.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, size: 20, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMedium(color: AppColors.ink),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.info_outline_rounded,
                size: 18, color: AppColors.inkMuted),
          ],
        ],
      ),
    );
    return onTap == null ? child : GestureDetector(onTap: onTap, child: child);
  }
}
