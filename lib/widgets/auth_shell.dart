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

  @override
  Widget build(BuildContext context) {
    final bgSurface =
        AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);
    final inkColor = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
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
                // Gauche : uniquement l'image, aucun texte dessus
                Expanded(
                  flex: 5,
                  child: Image(image: defaultImage, fit: BoxFit.cover),
                ),
                // Droite : Titre (centré) + Formulaire
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

          // ══════════════════════════════════════════════════════════
          // DESIGN MOBILE : l'image reste fixe en fond ; la carte est
          // dans le SEUL scroll de l'écran, donc au défilement elle
          // remonte et finit par couvrir entièrement l'image. Titre
          // et sous-titre sont centrés, le formulaire reste aligné
          // à gauche pour rester lisible.
          // ══════════════════════════════════════════════════════════
          final size = MediaQuery.of(context).size;
          final imageHeight = size.height * 0.46;
          final cardTop = size.height * 0.30;

          return Stack(
            children: [
              // 1. Image de fond, fixe, sans texte ni filtre
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: imageHeight,
                child: Image(image: defaultImage, fit: BoxFit.cover),
              ),

              // 2. Un seul scroll pour tout l'écran : un espace transparent
              // (qui laisse voir l'image) puis la carte, qui remonte et
              // couvre progressivement l'image quand on défile.
              Positioned.fill(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: size.height),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: cardTop),
                        Container(
                          constraints: BoxConstraints(
                            minHeight: size.height - cardTop,
                          ),
                          decoration: BoxDecoration(
                            color: bgSurface,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(40)),
                            border: Border.all(
                              color: inkColor.withValues(alpha: 0.1),
                              width: 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: inkColor.withValues(alpha: 0.1),
                                blurRadius: 20,
                                offset: const Offset(0, -5),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Petit grabber décoratif, centré
                              Center(
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  margin: const EdgeInsets.only(bottom: 18),
                                  decoration: BoxDecoration(
                                    color: inkColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: double.infinity,
                                child: Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.displayMedium(
                                          color: inkColor)
                                      .copyWith(
                                          fontWeight: FontWeight.w800,
                                          height: 1.08),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: Text(
                                  subtitle,
                                  textAlign: TextAlign.center,
                                  style:
                                      AppTypography.bodyLarge(color: inkColor)
                                          .copyWith(height: 1.4),
                                ),
                              ),
                              const SizedBox(height: 24),
                              form,
                              if (footer != null) ...[
                                const SizedBox(height: 32),
                                Center(child: footer!),
                              ],
                            ],
                          ),
                        ),
                      ],
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
