import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/swirling_loader.dart';

// ═══════════════════════════════════════════════════════════
// Raccourcis couleurs (mêmes tokens que le reste de l'app)
// ═══════════════════════════════════════════════════════════
class _IC {
  static Color get brand =>
      AppColors.resolve(AppColors.brand, AppDarkColors.brand);
  static Color get brandSurface =>
      AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface);
  static Color get surface =>
      AppColors.resolve(AppColors.surface, AppDarkColors.surface);
  static Color get card => AppColors.resolve(AppColors.card, AppDarkColors.card);
  static Color get border =>
      AppColors.resolve(AppColors.border, AppDarkColors.border);
  static Color get ink => AppColors.resolve(AppColors.ink, AppDarkColors.ink);
  static Color get inkMuted =>
      AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
}

/// Génère un nom compatible avec les services de stockage Parse.
/// Les noms saisis par l'utilisateur peuvent contenir des espaces, accents ou
/// caractères réservés par Parse ; ils ne doivent jamais être utilisés tels quels.
String safeUploadFileName({required String prefix, required XFile file}) {
  final sourceName = file.name.trim().isNotEmpty ? file.name : p.basename(file.path);
  final sourceExtension = p.extension(sourceName).toLowerCase();
  const allowedExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'heic'};
  final extension = allowedExtensions.contains(sourceExtension.replaceFirst('.', ''))
      ? sourceExtension
      : '.jpg';
  final safePrefix = prefix
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^[_-]+|[_-]+$'), '');
  final normalizedPrefix = safePrefix.isEmpty ? 'image' : safePrefix;
  return '${normalizedPrefix}_${DateTime.now().millisecondsSinceEpoch}$extension';
}

/// Builds an image from bytes instead of [Image.file].
///
/// `Image.file` is unavailable on Flutter Web, while [XFile] can expose its
/// bytes on Android, iOS, desktop and Web.
Widget pickedImagePreview(
  XFile image, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget Function(BuildContext context, Object error, StackTrace? stackTrace)?
      errorBuilder,
}) {
  return FutureBuilder<Uint8List>(
    future: image.readAsBytes(),
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return Image.memory(
          snapshot.data!,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: errorBuilder,
        );
      }
      if (snapshot.hasError && errorBuilder != null) {
        return errorBuilder(context, snapshot.error!, snapshot.stackTrace);
      }
      return SizedBox(
        width: width,
        height: height,
        child: Center(
          child: Swirling(size: 36, color: _IC.brand),
        ),
      );
    },
  );
}

// ═══════════════════════════════════════════════════════════
// Écran bloqué avec Swirling
// ═══════════════════════════════════════════════════════════

/// Voile plein écran non fermable avec [Swirling]. Retourne la fonction
/// qui le referme.
VoidCallback _showBlockingLoader(BuildContext context) {
  final nav = Navigator.of(context, rootNavigator: true);
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: '',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
    pageBuilder: (_, __, ___) => PopScope(
      canPop: false,
      child: Center(
        child: Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            color: _IC.card,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Center(child: Swirling(size: 64, color: _IC.brand)),
        ),
      ),
    ),
  );
  return () {
    if (nav.canPop()) nav.pop();
  };
}

/// Décodage + ré-encodage JPEG dans un isolate (ne bloque plus l'interface).
/// Retourne null si l'image ne peut pas être décodée.
Uint8List? _toJpeg(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return null;
  return Uint8List.fromList(img.encodeJpg(image, quality: 85));
}

// ═══════════════════════════════════════════════════════════
// Dialogue de confirmation
// ═══════════════════════════════════════════════════════════

/// Shows a full-size preview of [image] with a close (X) button and a
/// "Valider" button. Returns the [XFile] if confirmed, or null if cancelled.
Future<XFile?> showImageConfirmDialog(BuildContext context, XFile image) {
  return showDialog<XFile>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx)!;
      final maxImgH = MediaQuery.of(ctx).size.height * 0.58;
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: _IC.card,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 32,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Aperçu ──
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: maxImgH,
                    color: Colors.black,
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: pickedImagePreview(
                        image,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: maxImgH,
                      ),
                    ),
                  ),
                  // dégradé haut pour la lisibilité du bouton fermer
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.5),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, null),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35)),
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Bouton Valider (dégradé de marque) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Material(
                  color: Colors.transparent,
                  child: Ink(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_IC.brand, _IC.brand.withValues(alpha: 0.82)],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: [
                        BoxShadow(
                          color: _IC.brand.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      onTap: () => Navigator.pop(ctx, image),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 22),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              l10n.validate_this_image,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelLarge(
                                      color: Colors.white)
                                  .copyWith(fontSize: 16),
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
        ),
      );
    },
  );
}

// ═══════════════════════════════════════════════════════════
// Choix de la source (galerie / appareil photo)
// ═══════════════════════════════════════════════════════════

Widget _sourceTile({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return Expanded(
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: _IC.card,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: _IC.border, width: 0.6),
          boxShadow: [
            BoxShadow(
              color: _IC.ink.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: _IC.brandSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _IC.brand, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: AppTypography.labelLarge(color: _IC.ink),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shows a bottom sheet to choose gallery/camera, picks an image, and
/// displays a preview with confirm/cancel. Returns the confirmed [XFile]
/// or null if the user cancelled at any step.
Future<XFile?> pickAndConfirmImage(BuildContext context) async {
  final picker = ImagePicker();
  final l10n = AppLocalizations.of(context)!;

  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: _IC.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: _IC.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                _sourceTile(
                  icon: Icons.photo_library_rounded,
                  label: l10n.gallery,
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
                const SizedBox(width: 14),
                _sourceTile(
                  icon: Icons.photo_camera_rounded,
                  label: l10n.camera,
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );

  if (source == null) return null;

  final XFile? picked = await picker.pickImage(
    source: source,
    imageQuality: 85,
    preferredCameraDevice: CameraDevice.rear,
  );
  if (picked == null) return null;
  if (!context.mounted) return null;

  // Écran bloqué (Swirling) pendant la conversion en JPEG
  final closeLoader = _showBlockingLoader(context);
  XFile xFile;
  try {
    final results = await Future.wait<dynamic>([
      () async {
        final bytes = await picked.readAsBytes();
        // Conversion dans un isolate pour ne pas figer l'animation
        final jpegBytes = await compute(_toJpeg, bytes);
        if (jpegBytes == null) return picked; // format illisible → original
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final newPath = '${tempDir.path}/dish_$timestamp.jpg';
        await File(newPath).writeAsBytes(jpegBytes);
        return XFile(newPath);
      }(),
      // Durée minimale pour un rendu posé
      Future<void>.delayed(const Duration(milliseconds: 600)),
    ]);
    xFile = results[0] as XFile;
  } finally {
    closeLoader();
  }

  if (!context.mounted) return null;
  return showImageConfirmDialog(context, xFile);
}

/// Pick image directly from camera (for delivery proof)
Future<File?> pickImageFromCamera(BuildContext context) async {
  final picker = ImagePicker();
  final XFile? picked = await picker.pickImage(source: ImageSource.camera);
  if (picked == null) return null;
  return File(picked.path);
}