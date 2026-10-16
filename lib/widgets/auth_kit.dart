import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../utils/country_util.dart';
import 'swirling_loader.dart';

// ═══════════════════════════════════════════════════════════
// Kit d'interface des écrans d'authentification (connexion,
// inscription). Tout repose sur les tokens de app_theme.dart :
// rayons AppRadius.md, terracotta de marque, fonds crème.
// ═══════════════════════════════════════════════════════════

/// Couleurs résolues selon le mode clair / sombre.
class AuthColors {
  const AuthColors._();

  static Color get brand =>
      AppColors.resolve(AppColors.brand, AppDarkColors.brand);
  static Color get brandDark =>
      AppColors.resolve(AppColors.brandDark, AppDarkColors.brandDark);
  static Color get brandSurface =>
      AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface);
  static Color get ink => AppColors.resolve(AppColors.ink, AppDarkColors.ink);
  static Color get inkMuted =>
      AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
  static Color get inkSubtle =>
      AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle);
  static Color get card => AppColors.resolve(AppColors.card, AppDarkColors.card);
  static Color get border =>
      AppColors.resolve(AppColors.border, AppDarkColors.border);
  static Color get surfaceWarm =>
      AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);
  static Color get error =>
      AppColors.resolve(AppColors.error, AppDarkColors.error);
  static Color get errorLight =>
      AppColors.resolve(AppColors.errorLight, AppDarkColors.errorLight);
  static Color get success =>
      AppColors.resolve(AppColors.success, AppDarkColors.success);
}

// ── Voile de chargement bloquant ───────────────────────────

/// Affiche un voile plein écran non fermable. Retourne la fonction qui le
/// referme (sans effet si elle est appelée plusieurs fois).
VoidCallback showAuthLoader(BuildContext context) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final brand = AuthColors.brand;
  final card = AuthColors.card;
  var removed = false;
  final entry = OverlayEntry(
    builder: (_) => TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: Stack(
        children: [
          ModalBarrier(
            dismissible: false,
            color: Colors.black.withValues(alpha: 0.45),
          ),
          Center(
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppShadows.floatingList,
              ),
              child: Center(child: Swirling(size: 60, color: brand)),
            ),
          ),
        ],
      ),
    ),
  );
  overlay.insert(entry);
  return () {
    if (removed) return;
    removed = true;
    entry.remove();
  };
}

// ── Champs de saisie ───────────────────────────────────────

/// Décoration commune : carte claire, rayon md, icône qui prend la couleur
/// de marque au focus et la couleur d'erreur en cas d'erreur.
InputDecoration authInputDecoration({
  String? hint,
  IconData? icon,
  Widget? prefix,
  Widget? suffix,
}) {
  OutlineInputBorder outline(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: color, width: width),
      );

  final brand = AuthColors.brand;
  final error = AuthColors.error;
  final inkSubtle = AuthColors.inkSubtle;
  final border = AuthColors.border;

  return InputDecoration(
    hintText: hint,
    hintStyle: AppTypography.bodyLarge(color: inkSubtle).copyWith(fontSize: 15),
    errorStyle: AppTypography.bodySmall(color: error)
        .copyWith(fontWeight: FontWeight.w600),
    errorMaxLines: 2,
    prefixIcon: prefix ?? (icon == null ? null : Icon(icon, size: 20)),
    prefixIconConstraints: prefix == null
        ? null
        : const BoxConstraints(minWidth: 0, minHeight: 48),
    prefixIconColor: WidgetStateColor.resolveWith((states) {
      if (states.contains(WidgetState.error)) return error;
      if (states.contains(WidgetState.focused)) return brand;
      return inkSubtle;
    }),
    suffixIcon: suffix,
    suffixIconColor: AuthColors.inkMuted,
    filled: true,
    fillColor: AuthColors.card,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
    border: outline(border, 1),
    enabledBorder: outline(border, 1),
    focusedBorder: outline(brand, 1.6),
    errorBorder: outline(error, 1.2),
    focusedErrorBorder: outline(error, 1.6),
  );
}

/// Libellé au-dessus d'un champ, avec un élément optionnel aligné à droite
/// (lien « Mot de passe oublié ? » par exemple).
class AuthFieldLabel extends StatelessWidget {
  const AuthFieldLabel({super.key, required this.text, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: AppTypography.labelMedium(color: AuthColors.ink)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Champ de formulaire avec libellé au-dessus.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.icon,
    this.prefix,
    this.suffix,
    this.labelTrailing,
    this.focusNode,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.autofillHints,
    this.inputFormatters,
    this.onChanged,
    this.onFieldSubmitted,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final Widget? prefix;
  final Widget? suffix;
  final Widget? labelTrailing;
  final FocusNode? focusNode;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool autocorrect;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthFieldLabel(text: label, trailing: labelTrailing),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          autocorrect: autocorrect,
          autofillHints: autofillHints,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
          cursorColor: AuthColors.brand,
          style: AppTypography.bodyLarge(color: AuthColors.ink),
          decoration: authInputDecoration(
            hint: hint,
            icon: icon,
            prefix: prefix,
            suffix: suffix,
          ),
        ),
      ],
    );
  }
}

/// Bouton œil pour afficher / masquer un mot de passe.
class AuthObscureToggle extends StatelessWidget {
  const AuthObscureToggle({
    super.key,
    required this.obscured,
    required this.onPressed,
  });

  final bool obscured;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      splashRadius: 20,
      onPressed: onPressed,
      icon: AnimatedSwitcher(
        duration: AppMotion.fast,
        child: Icon(
          obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          key: ValueKey(obscured),
          size: 20,
        ),
      ),
    );
  }
}

// ── Boutons ────────────────────────────────────────────────

/// Bouton principal : dégradé terracotta, rayon md, ombre chaude.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon = Icons.arrow_forward_rounded,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final brand = AuthColors.brand;
    final deep = Color.lerp(brand, AuthColors.brandDark, 0.45)!;
    final radius = BorderRadius.circular(AppRadius.md);
    final disabled = onPressed == null && !isLoading;

    return AnimatedOpacity(
      duration: AppMotion.fast,
      opacity: disabled ? 0.5 : 1,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [brand, deep],
          ),
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: brand.withValues(alpha: disabled ? 0.0 : 0.30),
              blurRadius: 20,
              spreadRadius: -4,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            splashColor: Colors.white.withValues(alpha: 0.14),
            highlightColor: Colors.white.withValues(alpha: 0.06),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isLoading
                    ? const Swirling(
                        key: ValueKey('loading'),
                        size: 32,
                        color: Colors.white,
                      )
                    : Padding(
                        key: const ValueKey('label'),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelLarge(
                                  color: Colors.white,
                                ).copyWith(fontSize: 16),
                              ),
                            ),
                            if (icon != null) ...[
                              const SizedBox(width: 10),
                              Icon(icon, color: Colors.white, size: 20),
                            ],
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

/// Bouton carré secondaire (retour d'étape), même hauteur que le principal.
class AuthSquareButton extends StatelessWidget {
  const AuthSquareButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AuthColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: AuthColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(icon, color: AuthColors.ink, size: 22),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Lien texte compact en couleur de marque.
class AuthTextLink extends StatelessWidget {
  const AuthTextLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          label,
          style: AppTypography.labelMedium(color: AuthColors.brand)
              .copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Pied de page « Pas encore de compte ? S'inscrire ».
class AuthFooterPrompt extends StatelessWidget {
  const AuthFooterPrompt({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        Text(prompt, style: AppTypography.bodyMedium(color: AuthColors.inkMuted)),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              action,
              style: AppTypography.bodyMedium(color: AuthColors.brand)
                  .copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sélecteur segmenté ─────────────────────────────────────

class AuthSegment<T> {
  const AuthSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Contrôle segmenté avec pastille glissante.
class AuthSegmentedControl<T> extends StatelessWidget {
  const AuthSegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final List<AuthSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final index = segments.indexWhere((s) => s.value == value);
    final count = segments.length;
    final x = count == 1 ? 0.0 : -1 + 2 * index / (count - 1);

    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AuthColors.border.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: AppMotion.normal,
            curve: AppMotion.standard,
            alignment: Alignment(x, 0),
            child: FractionallySizedBox(
              widthFactor: 1 / count,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AuthColors.card,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [AppShadows.subtle],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final segment in segments)
                Expanded(
                  child: _SegmentLabel(
                    segment: segment,
                    selected: segment.value == value,
                    onTap: () => onChanged(segment.value),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentLabel<T> extends StatelessWidget {
  const _SegmentLabel({
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  final AuthSegment<T> segment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AuthColors.ink : AuthColors.inkMuted;
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (segment.icon != null) ...[
                Icon(
                  segment.icon,
                  size: 17,
                  color: selected ? AuthColors.brand : AuthColors.inkSubtle,
                ),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: AnimatedDefaultTextStyle(
                  duration: AppMotion.fast,
                  style: AppTypography.labelMedium(color: color).copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                  child: Text(
                    segment.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bannière d'erreur ──────────────────────────────────────

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message, this.onDismiss});

  final String message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final error = AuthColors.error;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: AuthColors.errorLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: error.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.labelMedium(color: error)
                  .copyWith(height: 1.35),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              splashRadius: 18,
              onPressed: onDismiss,
              icon: Icon(Icons.close_rounded, color: error, size: 18),
            ),
        ],
      ),
    );
  }
}

// ── Pays & indicatifs ──────────────────────────────────────

class AuthCountries {
  const AuthCountries._();

  static const _dialCodes = {
    CountryUtil.rdc: '+243',
    CountryUtil.benin: '+229',
  };

  static const _flags = {
    CountryUtil.rdc: '🇨🇩',
    CountryUtil.benin: '🇧🇯',
  };

  static String dialCode(String country) =>
      _dialCodes[CountryUtil.canonical(country)] ?? '+243';

  static String flag(String country) =>
      _flags[CountryUtil.canonical(country)] ?? '🌍';

  static String name(AppLocalizations l10n, String country) =>
      CountryUtil.isBenin(country)
          ? l10n.signup_country_benin
          : l10n.signup_country_drc;
}

/// Préfixe cliquable (drapeau + indicatif) placé dans un champ téléphone.
class AuthPhonePrefix extends StatelessWidget {
  const AuthPhonePrefix({
    super.key,
    required this.country,
    required this.onTap,
    this.isDetecting = false,
  });

  final String country;
  final VoidCallback onTap;
  final bool isDetecting;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.sm + 2),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDetecting)
                    Swirling(size: 22, color: AuthColors.brand)
                  else
                    Text(
                      AuthCountries.flag(country),
                      style: const TextStyle(fontSize: 20),
                    ),
                  const SizedBox(width: 6),
                  Text(
                    AuthCountries.dialCode(country),
                    style: AppTypography.labelLarge(color: AuthColors.ink),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: AuthColors.inkMuted,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(width: 1, height: 24, color: AuthColors.border),
        ],
      ),
    );
  }
}

/// Feuille de sélection du pays. Retourne le pays choisi, ou null.
Future<String?> showAuthCountryPicker(
  BuildContext context, {
  required String selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AuthColors.card,
    showDragHandle: true,
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext)!;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.signup_choose_country,
                style: AppTypography.titleMedium(color: AuthColors.ink),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final country in CountryUtil.selectableCountries) ...[
                _CountryOption(
                  country: country,
                  selected: CountryUtil.canonical(country) ==
                      CountryUtil.canonical(selected),
                  onTap: () => Navigator.of(sheetContext).pop(country),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _CountryOption extends StatelessWidget {
  const _CountryOption({
    required this.country,
    required this.selected,
    required this.onTap,
  });

  final String country;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = AuthColors.brand;

    return Material(
      color: selected ? AuthColors.brandSurface : AuthColors.surfaceWarm,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: selected ? brand : AuthColors.border,
          width: selected ? 1.4 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(
                AuthCountries.flag(country),
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  AuthCountries.name(l10n, country),
                  style: AppTypography.titleSmall(color: AuthColors.ink),
                ),
              ),
              Text(
                AuthCountries.dialCode(country),
                style: AppTypography.labelLarge(color: AuthColors.inkMuted),
              ),
              const SizedBox(width: 12),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? brand : AuthColors.border,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
