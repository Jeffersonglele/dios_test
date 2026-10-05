import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.form,
    this.footer,
    this.backgroundImage,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final Widget? footer;
  final ImageProvider? backgroundImage;

  /// Rapport hauteur/largeur de l'illustration (1536 × 1024).
  static const double _imageRatio = 1024 / 1536;

  /// Blanc de l'illustration : sert de fond derrière l'en-tête pour que
  /// rien ne « sorte » en tirant la page vers le bas.
  static const Color _imageBg = Colors.white;

  @override
  Widget build(BuildContext context) {
    final bgSurface =
        AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);
    final inkColor = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final defaultImage = backgroundImage ??
        const AssetImage(
          'assets/images/background2.png',
        );

    return Scaffold(
      backgroundColor: bgSurface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 980;

          if (isWide) {
            return Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Image(image: defaultImage, fit: BoxFit.cover),
                ),
                Expanded(
                  flex: 6,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 60, vertical: 40),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: 44,
                              height: 4,
                              alignment: Alignment.center,
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: brand,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style:
                                  AppTypography.displayMedium(color: inkColor)
                                      .copyWith(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 36,
                                          height: 1.08),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              style: AppTypography.bodySmall(color: inkColor)
                                  .copyWith(height: 1.4),
                            ),
                            const SizedBox(height: 36),
                            form,
                            if (footer != null) ...[
                              const SizedBox(height: 28),
                              Center(child: footer!),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // ── Mobile ─────────────────────────────────────────────
          // Tout est calculé à partir de la zone RÉELLEMENT disponible
          // (constraints) et non de MediaQuery : plus de décalage quand le
          // clavier ou les barres système changent la hauteur.
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final headerH = math.min(w * _imageRatio, h * 0.40);
          const overlap = 34.0; // la feuille mord un peu sur l'illustration
          final cardTop = headerH - overlap;
          final bottomInset = MediaQuery.of(context).padding.bottom;

          return Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: bgSurface)),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: headerH + 240,
                child: const ColoredBox(color: _imageBg),
              ),

              // 1. Illustration fixe
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: headerH,
                child: Image(
                  image: defaultImage,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  gaplessPlayback: true,
                ),
              ),

              // 2. Contenu défilant : espace + feuille qui remplit le reste
              Positioned.fill(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  padding: EdgeInsets.only(top: cardTop),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: bgSurface,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(36)),
                      // Ombre légère, uniquement vers le haut.
                      boxShadow: [
                        BoxShadow(
                          color: inkColor.withValues(alpha: 0.06),
                          blurRadius: 22,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.fromLTRB(
                        24, 30, 24, 32 + bottomInset),
                    child: _Reveal(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              style: AppTypography.displayMedium(
                                      color: inkColor)
                                  .copyWith(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 30,
                                      height: 1.1),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyLarge(
                                      color: inkMuted)
                                  .copyWith(fontSize: 15, height: 1.4),
                            ),
                          ),
                          const SizedBox(height: 26),
                          form,
                          if (footer != null) ...[
                            const SizedBox(height: 28),
                            Center(child: footer!),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}