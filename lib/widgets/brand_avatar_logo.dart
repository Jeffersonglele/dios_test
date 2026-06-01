import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BrandAvatarLogo extends StatelessWidget {
  const BrandAvatarLogo({
    super.key,
    this.radius = 50,
    this.glow = true,
    this.elevation = 8,
    this.backgroundColor = AppColors.brand,
  });

  final double radius;
  final bool glow;
  final double elevation;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final logo = Material(
      elevation: elevation,
      shape: const CircleBorder(),
      shadowColor: AppColors.ink.withValues(alpha: 0.18),
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        padding: EdgeInsets.all(radius * 0.22),
        child: Image.asset(
          'assets/images/logo-without-bg.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );

    if (!glow) {
      return logo;
    }

    return AvatarGlow(
      duration: const Duration(seconds: 2),
      glowColor: Colors.white24,
      repeat: true,
      startDelay: const Duration(seconds: 1),
      child: logo,
    );
  }
}
