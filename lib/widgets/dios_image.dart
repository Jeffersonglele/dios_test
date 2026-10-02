import 'package:flutter/material.dart';

import '../config/app_config.dart';

String? resolveImageUrl(String? value) {
  if (value == null) return null;
  final raw = value.trim();
  if (raw.isEmpty) return null;
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  if (raw.startsWith('file://') || raw.startsWith('/data/') || raw.startsWith('/storage/')) return raw;
  final base = AppConfig.nodeBackendUrl.replaceFirst(RegExp(r'/+$'), '');
  if (raw.startsWith('/')) return '$base$raw';
  return '$base/$raw';
}

String? _resolveImageUrl(String? value) => resolveImageUrl(value);

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
    final resolved = _resolveImageUrl(url);
    final validUrl = resolved != null && resolved.isNotEmpty;

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
      resolved!,
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
