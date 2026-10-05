import 'dart:math' as math;

import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../splash/animated_splash_screen.dart';

class PasswordChangeSuccessScreen extends StatefulWidget {
  const PasswordChangeSuccessScreen({super.key});

  @override
  State<PasswordChangeSuccessScreen> createState() =>
      _PasswordChangeSuccessScreenState();
}

class _PasswordChangeSuccessScreenState
    extends State<PasswordChangeSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Apparition (fondu + montée) d'un bloc sur une portion de l'animation.
  Widget _reveal(double begin, double end, Widget child) {
    final anim = CurvedAnimation(
      parent: _ctrl,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position:
            Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(anim),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final surface =
        AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);

    return Scaffold(
      backgroundColor: surface,
      body: Stack(
        children: [
          // Lueur douce derrière le badge
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.35),
                    radius: 0.9,
                    colors: [
                      brand.withValues(alpha: 0.10),
                      brand.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Badge animé ──────────────────────────
                      AnimatedBuilder(
                        animation: _ctrl,
                        builder: (_, __) => SizedBox(
                          width: 220,
                          height: 220,
                          child: CustomPaint(
                            painter: _BadgePainter(
                              color: brand,
                              card: card,
                              t: _ctrl.value,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Textes ───────────────────────────────
                      _reveal(
                        0.45,
                        0.80,
                        Column(
                          children: [
                            Text(
                              loc.password_reset_success_title,
                              style: AppTypography.headlineMedium(color: ink)
                                  .copyWith(fontWeight: FontWeight.w800),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              loc.password_reset_success_body,
                              style: AppTypography.bodyLarge(color: inkMuted)
                                  .copyWith(height: 1.45),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),

                      // ── Bouton ───────────────────────────────
                      _reveal(
                        0.62,
                        1.0,
                        _PrimaryButton(
                          label: loc.login,
                          onPressed: () => Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AnimatedSplashScreen(),
                            ),
                            (_) => false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _PrimaryButton — pilule en dégradé (coins nets, appui visible)
// ═══════════════════════════════════════════════════════════
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final radius = BorderRadius.circular(999);

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [brand, brand.withValues(alpha: 0.85)],
        ),
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: brand.withValues(alpha: 0.32),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _BadgePainter — badge à 12 lobes en relief + coche blanche tracée
//   t : 0 → 1 sur toute l'animation
//     0.00–0.40  le badge gonfle (petit rebond)
//     0.30–0.62  la coche se trace
// Pour un badge VERT « succès » : passez AppColors.success à `color`.
// ═══════════════════════════════════════════════════════════
class _BadgePainter extends CustomPainter {
  _BadgePainter({required this.color, required this.card, required this.t});

  final Color color;
  final Color card;
  final double t;

  static Path _badgePath(double r, {int lobes = 12, double amp = 0.05}) {
    final p = Path();
    const steps = 360;
    for (var i = 0; i <= steps; i++) {
      final a = i / steps * 2 * math.pi;
      final rr = r * (1 + amp * math.cos(lobes * a));
      final x = rr * math.cos(a);
      final y = rr * math.sin(a);
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = Curves.easeOutBack
        .transform(const Interval(0.0, 0.40).transform(t).clamp(0.0, 1.0));
    final check = Curves.easeInOutCubic
        .transform(const Interval(0.30, 0.62).transform(t).clamp(0.0, 1.0));

    final r = size.shortestSide * 0.40;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);

    final path = _badgePath(r);

    // 1. Halo
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.40)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.30),
    );

    // 2. Ombre portée
    canvas.drawPath(
      path.shift(Offset(0, r * 0.08)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.20)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.09),
    );

    // 3. Corps : dégradé de la couleur de marque
    final rect = Rect.fromCircle(center: Offset.zero, radius: r * 1.1);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(Colors.white, color, 0.78)!,
            color,
          ],
        ).createShader(rect),
    );

    // 4. Relief « gonflé » : reflet en haut à gauche + liseré intérieur
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.45, -0.55),
          radius: 0.95,
          colors: [
            Colors.white.withValues(alpha: 0.42),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(rect),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.16
        ..color = Colors.white.withValues(alpha: 0.30)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.05),
    );
    // ombre intérieure en bas à droite
    canvas.drawPath(
      path.shift(Offset(-r * 0.03, -r * 0.03)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.14
        ..color = Colors.black.withValues(alpha: 0.10)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.05),
    );
    canvas.restore();

    // 5. Coche blanche (tracée progressivement)
    final tick = Path()
      ..moveTo(-r * 0.36, r * 0.02)
      ..lineTo(-r * 0.10, r * 0.28)
      ..lineTo(r * 0.38, -r * 0.24);
    final metric = tick.computeMetrics().first;
    final part = metric.extractPath(0, metric.length * check);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = r * 0.27;

    canvas.drawPath(
      part.shift(Offset(0, r * 0.06)),
      stroke
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.045),
    );
    canvas.drawPath(
      part,
      stroke
        ..maskFilter = null
        ..color = Colors.white,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BadgePainter old) =>
      old.t != t || old.color != color || old.card != card;
}