import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'brand_avatar_logo.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.form,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          const _AuthBackdrop(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 980;
                final horizontalPadding = isWide ? 48.0 : 20.0;

                final content = isWide
                    ? IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              child: _AuthHero(
                                title: title,
                                subtitle: subtitle,
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
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _AuthHero(
                            title: title,
                            subtitle: subtitle,
                            compact: true,
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
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    18,
                    horizontalPadding,
                    18,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: size.height - 36,
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

class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white,
                Color(0xFFFFFCFA),
                Color(0xFFFFF4EE),
              ],
            ),
          ),
          child: SizedBox.expand(),
        ),
      ],
    );
  }
}

class _AuthHero extends StatelessWidget {
  const _AuthHero({
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment:
          compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (compact) ...[
          const SizedBox(height: 46),
          const Center(child: BrandAvatarLogo(radius: 58)),
          const SizedBox(height: 30),
        ] else ...[
          const SizedBox(height: 24),
          const BrandAvatarLogo(radius: 58),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Dios Délices',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.brandDark,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        Text(
          compact
              ? title
              : 'Une expérience plus chaleureuse pour commander et vendre.',
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.displayMedium?.copyWith(
            fontSize: compact ? 36 : 44,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          compact
              ? subtitle
              : 'Refonte progressive de l’application avec une interface plus claire, plus gourmande et plus premium.',
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppColors.inkMuted,
            height: 1.45,
          ),
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
    final theme = Theme.of(context);

    final content = Padding(
      padding: EdgeInsets.all(compact ? 4 : 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact) ...[
            Text(title, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 24),
          ],
          form,
          if (footer != null) ...[
            const SizedBox(height: 22),
            footer!,
          ],
        ],
      ),
    );

    if (compact) {
      return content;
    }

    return Card(child: content);
  }
}
