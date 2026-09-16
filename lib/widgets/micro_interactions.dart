import 'dart:math';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Effet de rebond pour l'ajout au panier
class AddToCartBounce extends StatefulWidget {
  const AddToCartBounce({super.key, required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<AddToCartBounce> createState() => _AddToCartBounceState();
}

class _AddToCartBounceState extends State<AddToCartBounce>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.88), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.06), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onTap();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { _ctrl.reset(); _ctrl.forward(); },
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}

/// Animation de like organique (pas juste toggle binaire)
class AnimatedLikeButton extends StatefulWidget {
  const AnimatedLikeButton({
    super.key,
    required this.isLiked,
    required this.onTap,
    this.size = 24,
  });

  final bool isLiked;
  final VoidCallback onTap;
  final double size;

  @override
  State<AnimatedLikeButton> createState() => _AnimatedLikeButtonState();
}

class _AnimatedLikeButtonState extends State<AnimatedLikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.7), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.35), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.9), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 25),
    // TweenSequence exige une progression comprise entre 0 et 1. Les courbes
    // élastiques peuvent dépasser 1, ce qui faisait planter le rendu Web.
    // Le rebond visuel est déjà porté par les valeurs de la séquence.
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onTap();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { _ctrl.reset(); _ctrl.forward(); },
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, __) => Transform.scale(
          scale: _scale.value,
          child: Icon(
            widget.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: widget.isLiked ? AppColors.error : AppColors.inkMuted,
            size: widget.size,
          ),
        ),
      ),
    );
  }
}

/// Particule décorative pour les validations (explosion de petites étoiles)
class CompletionParticles extends StatefulWidget {
  const CompletionParticles({super.key});

  @override
  State<CompletionParticles> createState() => _CompletionParticlesState();
}

class _CompletionParticlesState extends State<CompletionParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final _particles = <_Particle>[];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    for (int i = 0; i < 12; i++) {
      _particles.add(_Particle(index: i));
    }
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => SizedBox(
        width: 200,
        height: 200,
        child: Stack(
          children: _particles.map((p) {
            final progress = Curves.easeOutCubic.transform(
              (_ctrl.value - p.index * 0.06).clamp(0.0, 1.0));
            final angle = p.index * (3.14159 * 2 / 12);
            final radius = 40 + 50 * progress;
            final opacity = (1 - progress).clamp(0.0, 1.0);
            return Positioned(
              left: 100 + cos(angle) * radius - 8,
              top: 100 + sin(angle) * radius - 8,
              child: Opacity(
                opacity: opacity,
                child: Icon(
                  p.icon,
                  size: 14 + 8 * (1 - progress),
                  color: Color.lerp(AppColors.accent, AppColors.brand, progress),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _Particle {
  final int index;
  final IconData icon;
  _Particle({required this.index})
      : icon = [Icons.star_rounded, Icons.favorite_rounded, Icons.circle_rounded][index % 3];
}
