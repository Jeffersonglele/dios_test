import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/order_tracking_service.dart';
import '../theme/app_theme.dart';

IconData courierVehicleIcon(String? type) {
  switch (type) {
    case 'moto':
      return Icons.two_wheeler_rounded;
    case 'velo':
      return Icons.pedal_bike_rounded;
    case 'voiture':
      return Icons.directions_car_rounded;
    default:
      return Icons.delivery_dining_rounded;
  }
}

String courierVehicleLabel(String? type, AppLocalizations l10n) {
  switch (type) {
    case 'moto':
      return l10n.livreur_vehicle_moto;
    case 'velo':
      return l10n.livreur_vehicle_bike;
    case 'voiture':
      return l10n.livreur_vehicle_car;
    default:
      return l10n.livreur_vehicle_unspecified;
  }
}

/// Plaque d'immatriculation dessinée comme une vraie plaque, pour que le
/// client et le restaurant la reconnaissent d'un coup d'œil.
class VehiclePlateBadge extends StatelessWidget {
  const VehiclePlateBadge({super.key, required this.plate});
  final String plate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFF1F2937), width: 1.4),
      ),
      child: Text(
        plate,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: Color(0xFF111827),
        ),
      ),
    );
  }
}

/// Photo du livreur (initiales en repli).
class CourierAvatar extends StatelessWidget {
  const CourierAvatar({super.key, required this.courier, this.radius = 28});
  final CourierProfile courier;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final photo = courier.photoUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: brand.withValues(alpha: 0.12),
      foregroundImage:
          photo == null || photo.isEmpty ? null : NetworkImage(photo),
      child: Text(
        courier.initials,
        style: AppTypography.titleSmall(color: brand)
            .copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Carte « Votre livreur » : photo, nom, véhicule et plaque, avec les
/// actions Appeler et Suivre sur la carte.
class CourierCard extends StatelessWidget {
  const CourierCard({
    super.key,
    required this.courier,
    this.onCall,
    this.onTrack,
    this.title,
  });

  final CourierProfile courier;
  final VoidCallback? onCall;
  final VoidCallback? onTrack;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final plate = courier.vehiclePlate;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border, width: 0.6),
        boxShadow: [AppShadows.subtle],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text((title ?? l10n.courier_card_title).toUpperCase(),
              style: AppTypography.labelMedium(color: muted)
                  .copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          const SizedBox(height: 12),
          Row(
            children: [
              CourierAvatar(courier: courier),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(courier.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleSmall(color: ink)
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(courierVehicleIcon(courier.vehicleType),
                              size: 16, color: muted),
                          const SizedBox(width: 4),
                          Text(courierVehicleLabel(courier.vehicleType, l10n),
                              style: AppTypography.bodySmall(color: muted)),
                        ]),
                        if (plate != null && plate.isNotEmpty)
                          VehiclePlateBadge(plate: plate),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onCall != null || onTrack != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (onCall != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCall,
                      icon: Icon(Icons.call_rounded, size: 18, color: brand),
                      label: Text(l10n.courier_card_call,
                          style: AppTypography.labelMedium(color: brand)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        side: BorderSide(color: brand.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                    ),
                  ),
                if (onCall != null && onTrack != null) const SizedBox(width: 10),
                if (onTrack != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onTrack,
                      icon: const Icon(Icons.map_rounded, size: 18),
                      label: Text(l10n.courier_card_track,
                          style: AppTypography.labelMedium(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        backgroundColor: brand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// En attente d'un livreur (commande prête, recherche en cours).
class CourierSearchingCard extends StatelessWidget {
  const CourierSearchingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border, width: 0.6),
      ),
      child: Row(children: [
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: brand),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.courier_card_searching_title,
                  style: AppTypography.titleSmall(color: ink)),
              const SizedBox(height: 2),
              Text(l10n.courier_card_searching_body,
                  style: AppTypography.bodySmall(color: muted)),
            ],
          ),
        ),
      ]),
    );
  }
}
