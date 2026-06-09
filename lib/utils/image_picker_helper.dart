import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/app_localizations.dart';

/// Shows a full-size preview of [file] with a close (X) button and a
/// "Valider" button. Returns the [File] if confirmed, or null if cancelled.
Future<File?> showImageConfirmDialog(BuildContext context, File file) {
  return showDialog<File>(
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
                  child: Image.file(file, fit: BoxFit.contain, width: double.infinity, height: 400),
                ),
                Positioned(
                  top: 8, right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
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
                  onPressed: () => Navigator.pop(ctx, file),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  },);
}

/// Shows a bottom sheet to choose gallery/camera, picks an image, and
/// displays a preview with confirm/cancel. Returns the confirmed [File]
/// or null if the user cancelled at any step.
Future<File?> pickAndConfirmImage(BuildContext context) async {
  final picker = ImagePicker();

  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (_) => SafeArea(
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
  );

  if (source == null) return null;

  final XFile? picked = await picker.pickImage(source: source);
  if (picked == null) return null;

  return showImageConfirmDialog(context, File(picked.path));
}
