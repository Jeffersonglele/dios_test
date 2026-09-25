import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Spinner Dios Délices : rotation continue et longueur d'arc animée.
///
/// Le composant reste indépendant du contexte d'utilisation afin de pouvoir
/// être placé dans une page, un bouton ou un overlay de chargement.
class Swirling extends StatefulWidget {
  const Swirling({
    super.key,
    this.duration = const Duration(milliseconds: 1500),
    this.size = 48,
    this.color,
    this.semanticLabel = 'Chargement',
  });

  final Duration duration;
  final double size;
  final Color? color;
  final String semanticLabel;

  @override
  State<Swirling> createState() => _SwirlingState();
}

class _SwirlingState extends State<Swirling>
    with TickerProviderStateMixin {
  late AnimationController _dashController;
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _createControllers();
  }

  void _createControllers() {
    _dashController = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);
    _spinController = AnimationController(
      duration: _spinDuration(widget.duration),
      vsync: this,
    )..repeat();
  }

  Duration _spinDuration(Duration duration) {
    final milliseconds = (duration.inMilliseconds * 1.333333).round();
    return Duration(
      milliseconds: milliseconds.clamp(1, 60000).toInt(),
    );
  }

  @override
  void didUpdateWidget(covariant Swirling oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _dashController
        ..duration = widget.duration
        ..reset()
        ..repeat(reverse: true);
      _spinController
        ..duration = _spinDuration(widget.duration)
        ..reset()
        ..repeat();
    }
  }

  @override
  void dispose() {
    _dashController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.brand;

    return Semantics(
      label: widget.semanticLabel,
      liveRegion: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_dashController, _spinController]),
          builder: (context, child) {
            return Transform.rotate(
              angle: _spinController.value * 2 * math.pi,
              child: CustomPaint(
                painter: _SwirlPainter(
                  progress: _dashController.value,
                  color: color,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SwirlPainter extends CustomPainter {
  const _SwirlPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.34;
    final strokeWidth = math.max(2.5, math.min(size.width, size.height) * 0.075);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweep = 2 * math.pi * (0.05 + 0.90 * progress);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, paint);
  }

  @override
  bool shouldRepaint(covariant _SwirlPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
