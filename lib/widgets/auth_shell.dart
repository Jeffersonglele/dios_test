import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'brand_avatar_logo.dart';

/// Coque d'authentification Dios Délices
/// Mobile : formulaire pleine largeur
/// Tablette/Desktop : split screen (illustration | formulaire)
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.form,
    this.footer,
    this.heroImage,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final Widget? footer;
  final Widget? heroImage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // Fond dégradé signature
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.surface,
                    AppColors.gradientEnd,
                    AppColors.surface,
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 980;
                final hPad = isWide ? 48.0 : 20.0;

                final content = isWide
                    ? Row(
                        children: [
                          Expanded(
                            child: _AuthHero(
                              title: title,
                              subtitle: subtitle,
                              heroImage: heroImage,
                            ),
                          ),
                          const SizedBox(width: 36),
                          Expanded(
                            child: _AuthCard(
                              title: title,
                              subtitle: subtitle,
                              form: form,
                              footer: footer,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _AuthHero(
                            title: title,
                            subtitle: subtitle,
                            compact: true,
                            heroImage: heroImage,
                          ),
                          const SizedBox(height: 22),
                          _AuthCard(
                            title: title,
                            subtitle: subtitle,
                            form: form,
                            footer: footer,
                            compact: true,
                          ),
                        ],
                      );

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(hPad, 18, hPad, 18),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height - 36,
                    ),
                    child: content,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthHero extends StatelessWidget {
  const _AuthHero({
    required this.title,
    required this.subtitle,
    this.compact = false,
    this.heroImage,
  });

  final String title;
  final String subtitle;
  final bool compact;
  final Widget? heroImage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (compact) ...[
          const SizedBox(height: 46),
          // Logo circulaire avec ombre chaude
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandDark.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/logo_circulaire.png',
                width: 200,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 30),
        ] else ...[
          const SizedBox(height: 24),
          ClipOval(
            child: Image.asset(
              'assets/images/logo_circulaire.png',
              width: 116,
              height: 116,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 28),
          // Badge marque pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.card.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              'Dios Délices',
              style: AppTypography.labelLarge(color: AppColors.brandDark),
            ),
          ),
          const SizedBox(height: 20),
          // Illustration ou espace visuel
          if (heroImage != null) ...[
            heroImage!,
            const SizedBox(height: 24),
          ],
        ],
        Text(
          compact ? title : 'Neighborhood cooking,\nwarmer and simpler.',
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: AppTypography.displayMedium().copyWith(
            fontSize: compact ? 36 : 44,
            height: 1.08,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          compact
              ? subtitle
              : 'Connectez-vous pour découvrir les meilleurs plats faits maison près de chez vous.',
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: AppTypography.bodyLarge(color: AppColors.inkMuted),
        ),
      ],
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.title,
    required this.subtitle,
    required this.form,
    this.footer,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final Widget? footer;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.all(compact ? 4 : 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact) ...[
            Text(title, style: AppTypography.headlineMedium()),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: AppTypography.bodyLarge(color: AppColors.inkMuted),
            ),
            const SizedBox(height: 24),
          ],
          form,
          if (footer != null) ...[
            const SizedBox(height: 22),
            Align(alignment: Alignment.center, child: footer!),
          ],
        ],
      ),
    );

    if (compact) return content;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: content,
    );
  }
}
