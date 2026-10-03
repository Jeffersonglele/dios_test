import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/currency_service.dart';
import '../utils/currency_util.dart';
import 'dios_image.dart';

/// Raccourcis couleurs (mêmes tokens que le reste de l'app, clair + sombre).
class CC {
  static Color get ink => AppColors.resolve(AppColors.ink, AppDarkColors.ink);
  static Color get inkMuted =>
      AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
  static Color get inkSubtle =>
      AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle);
  static Color get brand =>
      AppColors.resolve(AppColors.brand, AppDarkColors.brand);
  static Color get brandSurface =>
      AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface);
  static Color get card => AppColors.resolve(AppColors.card, AppDarkColors.card);
  static Color get border =>
      AppColors.resolve(AppColors.border, AppDarkColors.border);
  static Color get surface =>
      AppColors.resolve(AppColors.surface, AppDarkColors.surface);
  static Color get surfaceWarm =>
      AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);
  static Color get success =>
      AppColors.resolve(AppColors.success, AppDarkColors.success);
  static Color get successLight =>
      AppColors.resolve(AppColors.successLight, AppDarkColors.successLight);
  static Color get errorLight =>
      AppColors.resolve(AppColors.errorLight, AppDarkColors.errorLight);
}

/// Apparition douce (fondu + glissement) à l'affichage.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + index * 90),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}

/// Carte de section avec ombre douce.
class CartSectionCard extends StatelessWidget {
  const CartSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CC.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: CC.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: CC.ink.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: CC.brandSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 19, color: CC.brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.titleMedium(color: CC.ink)
                      .copyWith(fontSize: 17),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// En-tête du restaurant (bannière dégradée à la couleur de la marque).
class CartStoreHeader extends StatelessWidget {
  const CartStoreHeader({
    super.key,
    required this.name,
    required this.image,
    required this.subtitle,
  });
  final String name;
  final String image;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CC.brand, CC.brand.withValues(alpha: 0.78)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: CC.brand.withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: ClipOval(
              child: SizedBox(
                width: 54,
                height: 54,
                child: image.isEmpty
                    ? ColoredBox(
                        color: CC.brandSurface,
                        child: Icon(Icons.storefront_rounded, color: CC.brand),
                      )
                    : DiosImage(url: image, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium(color: Colors.white)
                      .copyWith(fontSize: 18),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined,
                        size: 15, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(subtitle,
                        style: AppTypography.labelMedium(
                            color: Colors.white.withValues(alpha: 0.92))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Stepper de quantité horizontal en forme de pilule.
class CartQtyStepper extends StatelessWidget {
  const CartQtyStepper({
    super.key,
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
  });
  final int quantity;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  Widget _btn(IconData icon, VoidCallback? onTap, {bool filled = false}) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: filled && enabled ? CC.brand : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: filled && enabled
              ? Colors.white
              : (enabled ? CC.brand : CC.border),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: CC.brandSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.remove_rounded, onMinus),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: SizedBox(
              key: ValueKey(quantity),
              width: 28,
              child: Text('$quantity',
                  textAlign: TextAlign.center,
                  style: AppTypography.titleMedium(color: CC.ink)
                      .copyWith(fontSize: 15)),
            ),
          ),
          _btn(Icons.add_rounded, onPlus, filled: true),
        ],
      ),
    );
  }
}

/// Ligne d'article du panier.
class CartItemTile extends StatelessWidget {
  const CartItemTile({
    super.key,
    required this.item,
    required this.country,
    required this.onDelete,
    required this.onQuantityChanged,
  });

  final Map<String, dynamic> item;
  final String country;
  final VoidCallback onDelete;
  final ValueChanged<int> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final meal = item['meal'] as Map<String, dynamic>;
    final quantity = (item['order']['quantity'] as num).toInt();
    final unitPrice = (meal['price'] as num).toDouble();
    final optionPrice = (item['optionPrice'] as num?)?.toDouble() ?? 0.0;
    final lineTotal = (unitPrice + optionPrice) * quantity;
    final maxQty = (meal['number_of_servings'] as num?)?.toInt() ?? 99;
    final options = item['optionDetails'] is Map
        ? (item['optionDetails'] as Map).entries.toList()
        : <MapEntry>[];

    return Dismissible(
      key: Key('cart_${item.hashCode}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: CC.errorLight,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.error, size: 26),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CC.card,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: CC.border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: CC.ink.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: DiosImage(url: meal['image'], width: 88, height: 88),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SizedBox(
                height: 88,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal['meal_name'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium(color: CC.ink)
                          .copyWith(fontSize: 15.5),
                    ),
                    if (options.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: options.take(3).map((e) {
                          final info = e.value is Map ? e.value as Map : {};
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: CC.surfaceWarm,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${info['name'] ?? e.key}',
                              style: AppTypography.labelMedium(
                                      color: CC.inkMuted)
                                  .copyWith(fontSize: 11),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: AnimatedBuilder(
                            animation: CurrencyService.instance,
                            builder: (_, __) => Text(
                              CurrencyUtil.formatConvertedPrice(lineTotal),
                              style: AppTypography.titleMedium(color: CC.brand)
                                  .copyWith(fontSize: 16),
                            ),
                          ),
                        ),
                        CartQtyStepper(
                          quantity: quantity,
                          onMinus: quantity > 1
                              ? () => onQuantityChanged(quantity - 1)
                              : null,
                          onPlus: quantity < maxQty
                              ? () => onQuantityChanged(quantity + 1)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CartSegment {
  const CartSegment(this.value, this.label, this.icon);
  final String value;
  final String label;
  final IconData icon;
}

/// Sélecteur segmenté animé (remplace le DropdownButton).
class CartSegmented extends StatelessWidget {
  const CartSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });
  final List<CartSegment> segments;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: CC.surfaceWarm,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: segments.map((s) {
          final selected = s.value == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(s.value),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? CC.brand : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: CC.brand.withValues(alpha: 0.30),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(s.icon,
                        size: 18, color: selected ? Colors.white : CC.inkMuted),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        s.label,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelLarge(
                            color: selected ? Colors.white : CC.inkMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Bloc adresse de livraison.
class CartAddressBox extends StatelessWidget {
  const CartAddressBox({
    super.key,
    required this.title,
    required this.address,
    required this.placeholder,
    required this.locating,
    required this.locateLabel,
    required this.onLocate,
    required this.onEdit,
    required this.editTooltip,
    this.savedLabel,
  });
  final String title;
  final String? address;
  final String placeholder;
  final bool locating;
  final String locateLabel;
  final VoidCallback? onLocate;
  final VoidCallback? onEdit;
  final String editTooltip;
  final String? savedLabel;

  @override
  Widget build(BuildContext context) {
    final has = address != null && address!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CC.brandSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: CC.card, shape: BoxShape.circle),
                child: Icon(Icons.location_on_rounded, color: CC.brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTypography.titleSmall(color: CC.ink)),
                    const SizedBox(height: 3),
                    Text(
                      has ? address! : placeholder,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium(
                          color: has ? CC.ink : CC.inkMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: editTooltip,
                onPressed: onEdit,
                icon: Icon(Icons.edit_location_alt_outlined, color: CC.brand),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onLocate,
              style: OutlinedButton.styleFrom(
                foregroundColor: CC.brand,
                side: BorderSide(color: CC.brand.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              icon: locating
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location_rounded, size: 18),
              label: Text(locateLabel),
            ),
          ),
          if (has && savedLabel != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 16, color: CC.success),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(savedLabel!,
                      style: AppTypography.labelMedium(color: CC.success)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Badge du code promo appliqué.
class CartPromoBadge extends StatelessWidget {
  const CartPromoBadge({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CC.successLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_rounded, color: CC.success, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: AppTypography.labelMedium(color: CC.success)),
          ),
        ],
      ),
    );
  }
}

/// Ligne de résumé.
class CartSummaryRow extends StatelessWidget {
  const CartSummaryRow(this.label, this.value,
      {super.key, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyLarge(color: CC.inkMuted)),
          Text(value,
              style: AppTypography.bodyLarge(color: valueColor ?? CC.ink)
                  .copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Séparateur pointillé façon ticket de caisse.
class CartDashedDivider extends StatelessWidget {
  const CartDashedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: LayoutBuilder(builder: (_, c) {
        final n = (c.maxWidth / 9).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            n,
            (_) => Container(width: 5, height: 1.2, color: CC.border),
          ),
        );
      }),
    );
  }
}

/// Total mis en valeur.
class CartTotalRow extends StatelessWidget {
  const CartTotalRow(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: CC.brandSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTypography.titleMedium(color: CC.ink)
                  .copyWith(fontSize: 16)),
          Text(value,
              style: AppTypography.titleMedium(color: CC.brand)
                  .copyWith(fontSize: 20)),
        ],
      ),
    );
  }
}

/// Option de paiement sélectionnable.
class CartPaymentOption extends StatelessWidget {
  const CartPaymentOption({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? CC.brandSurface : CC.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? CC.brand : CC.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Column(
                children: [
                  Icon(icon, size: 26, color: selected ? CC.brand : CC.inkMuted),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppTypography.labelMedium(
                        color: selected ? CC.brand : CC.inkMuted),
                  ),
                ],
              ),
            ),
            Positioned(
              top: -6,
              right: -2,
              child: AnimatedScale(
                scale: selected ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: Icon(Icons.check_circle_rounded,
                    size: 20, color: CC.brand),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton « Commander » collant, avec dégradé.
class CartCheckoutBar extends StatelessWidget {
  const CartCheckoutBar({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
  });
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      decoration: BoxDecoration(
        color: CC.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: CC.ink.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: enabled ? 1 : 0.55,
          child: Material(
            color: Colors.transparent,
            child: Ink(
              height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [CC.brand, CC.brand.withValues(alpha: 0.82)],
                ),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: [
                  BoxShadow(
                    color: CC.brand.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                onTap: onPressed,
                child: Center(
                  child: loading
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.2, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Text(label,
                                style: AppTypography.labelLarge(
                                    color: Colors.white)),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(label,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelLarge(
                                          color: Colors.white)
                                      .copyWith(fontSize: 16)),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 20),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// État panier vide.
class CartEmptyState extends StatelessWidget {
  const CartEmptyState({super.key, required this.title, required this.hint});
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: FadeSlideIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  color: CC.brandSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.shopping_basket_outlined,
                    size: 62, color: CC.brand),
              ),
              const SizedBox(height: 26),
              Text(title,
                  textAlign: TextAlign.center,
                  style: AppTypography.titleMedium(color: CC.ink)
                      .copyWith(fontSize: 20)),
              const SizedBox(height: 8),
              Text(hint,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium(color: CC.inkMuted)),
            ],
          ),
        ),
      ),
    );
  }
}