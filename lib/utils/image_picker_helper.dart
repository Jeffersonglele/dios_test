import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import '../l10n/app_localizations.dart';

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
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    },
  );
}

/// Shows a full-size preview of [image] with a close (X) button and a
/// "Valider" button. Returns the [XFile] if confirmed, or null if cancelled.
Future<XFile?> showImageConfirmDialog(BuildContext context, XFile image) {
  return showDialog<XFile>(
    context: context,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx)!;
      return Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  InteractiveViewer(
                    child: pickedImagePreview(image,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: 400),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.black45,
                      child: IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(ctx, null),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle, size: 20),
                    label: Text(l10n.validate_this_image),
                    onPressed: () => Navigator.pop(ctx, image),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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

/// Shows a bottom sheet to choose gallery/camera, picks an image, and
/// displays a preview with confirm/cancel. Returns the confirmed [XFile]
/// or null if the user cancelled at any step.
Future<XFile?> pickAndConfirmImage(BuildContext context) async {
  final picker = ImagePicker();

  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (_) => SafeArea(
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: Text(AppLocalizations.of(context)!.gallery),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: Text(AppLocalizations.of(context)!.camera),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
        ]),
      ),
    ),
  );

  if (source == null) return null;

  final XFile? picked = await picker.pickImage(source: source);
  if (picked == null) return null;

  return showImageConfirmDialog(context, picked);
}
