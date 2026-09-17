import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

enum CartConflictChoice { keep, replace, cancel }

Future<CartConflictChoice> showCartConflictSheet(
  BuildContext context, {
  required String restaurantName,
}) async {
  final choice = await showModalBottomSheet<CartConflictChoice>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) {
      final l10n = AppLocalizations.of(context)!;
      return SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
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
              const SizedBox(height: 22),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.brandSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  size: 34,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.cart_leave_restaurant_title,
                textAlign: TextAlign.center,
                style: AppTypography.titleLarge().copyWith(
                  fontSize: 21,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.cart_leave_restaurant_message(restaurantName),
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge(color: AppColors.inkMuted),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(
                    context,
                    CartConflictChoice.keep,
                  ),
                  child: Text(l10n.cart_keep_cart),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(
                    context,
                    CartConflictChoice.replace,
                  ),
                  child: Text(l10n.cart_empty_cart),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(
                  context,
                  CartConflictChoice.cancel,
                ),
                child: Text(l10n.cancel),
              ),
            ],
          ),
        ),
      );
    },
  );
  return choice ?? CartConflictChoice.cancel;
}
