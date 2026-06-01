import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BrandAvatarLogo extends StatelessWidget {
  const BrandAvatarLogo({
    super.key,
    this.radius = 50,
    this.glow = true,
    this.elevation = 8,
  });

  final double radius;
  final bool glow;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: AppColors.brand,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.brandDark.withValues(alpha: 0.25),
            blurRadius: elevation * 2,
            offset: Offset(0, elevation * 0.6),
          ),
        ],
        gradient: const LinearGradient(
          colors: [AppColors.brandLight, AppColors.brandDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.all(radius * 0.22),
      child: Image.asset(
        'assets/images/logo-without-bg.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );

    if (!glow) return logo;

    return AvatarGlow(
      duration: const Duration(seconds: 2),
      glowColor: AppColors.accent.withValues(alpha: 0.28),
      repeat: true,
      startDelay: const Duration(seconds: 1),
      child: logo,
    );
  }
}
