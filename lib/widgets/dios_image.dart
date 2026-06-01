import 'package:flutter/material.dart';

/// Affiche une image réseau avec fallback automatique si l'URL est vide.
/// Évite l'erreur NetworkImage("") quand l'image est null ou vide.
class DiosImage extends StatelessWidget {
  const DiosImage({
    super.key,
    this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final double? width, height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final validUrl = url != null && url!.trim().isNotEmpty;

    if (!validUrl) {
      return Container(
        width: width,
        height: height,
        color: const Color(0xFFF5EAE0),
        child: const Icon(Icons.restaurant_rounded,
            color: Color(0xFFD4C4B2), size: 28),
      );
    }

    return Image.network(
      url!,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => Container(
        width: width,
        height: height,
        color: const Color(0xFFF5EAE0),
        child: const Icon(Icons.restaurant_rounded,
            color: Color(0xFFD4C4B2), size: 28),
      ),
    );
  }
}
