import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_theme.dart';
import 'package:confetti/confetti.dart' as confetti_pkg;

/// Widget d'animation Lottie pour pull-to-refresh (animation de cuisson)
class CookingAnimation extends StatelessWidget {
  const CookingAnimation({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 80,
        height: 80,
        child: LottieBuilder.asset(
          'assets/animations/cooking.json',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const _FallbackCookingIndicator(),
        ),
      ),
    );
  }
}

/// Fallback si le fichier Lottie n'existe pas
class _FallbackCookingIndicator extends StatefulWidget {
  const _FallbackCookingIndicator();

  @override
  State<_FallbackCookingIndicator> createState() => _FallbackCookingIndicatorState();
}

class _FallbackCookingIndicatorState extends State<_FallbackCookingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final color = Color.lerp(AppColors.brand, AppColors.accent, _controller.value);
        return Icon(Icons.restaurant_rounded, color: color, size: 48);
      },
    );
  }
}

/// Célébration de commande avec confettis chauds
class OrderConfettiCelebration extends StatefulWidget {
  const OrderConfettiCelebration({super.key, required this.child});
  final Widget child;

  @override
  State<OrderConfettiCelebration> createState() => _OrderConfettiCelebrationState();
}

class _OrderConfettiCelebrationState extends State<OrderConfettiCelebration> {
  late confetti_pkg.ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = confetti_pkg.ConfettiController(duration: const Duration(seconds: 2));
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: confetti_pkg.ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: confetti_pkg.BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              AppColors.brand,
              AppColors.accent,
              AppColors.brandLight,
              AppColors.success,
              Color(0xFFFFD700),
              // orange chaud
              Color(0xFFE8A14B),
            ],
            numberOfParticles: 15,
            maxBlastForce: 8,
            minBlastForce: 3,
            gravity: 0.15,
            emissionFrequency: 0.3,
            particleDrag: 0.05,
            canvas: const Size(double.infinity, 200),
          ),
        ),
      ],
    );
  }
}

/// Animation de succès (coche animée) pour les écrans de confirmation
class AnimatedSuccessCheck extends StatefulWidget {
  const AnimatedSuccessCheck({super.key, this.size = 100});
  final double size;

  @override
  State<AnimatedSuccessCheck> createState() => _AnimatedSuccessCheckState();
}

class _AnimatedSuccessCheckState extends State<AnimatedSuccessCheck>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(
        scale: _scale.value,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.successLight,
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.check_rounded, color: AppColors.success, size: 48),
        ),
      ),
    );
  }
}
