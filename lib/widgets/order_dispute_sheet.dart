import 'dart:io';

import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/widgets/order_otp_widgets.dart'
    show OtpGradientButton;
import 'package:dios_delices/widgets/swirling_loader.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/order_dispute_service.dart';

// ═══════════════════════════════════════════════════════════
// Réclamation client (fenêtre de 60 min après la livraison)
//   • DisputeButton          → bouton rouge « Signaler un problème… »
//   • showOrderDisputeSheet  → BottomSheet : motif + photo + envoi
// ═══════════════════════════════════════════════════════════

/// Bouton rouge pleine largeur (coins nets, appui visible).
class DisputeButton extends StatelessWidget {
  const DisputeButton({
    super.key,
    required this.onPressed,
    this.label = 'Signaler un problème avec ma commande',
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    return Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.error,
          AppColors.error.withValues(alpha: 0.85),
        ]),
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 7),
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
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.report_gmailerrorred_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Ouvre la feuille de réclamation. Retourne `true` si elle a été envoyée.
///
///  uploadPhoto : votre service d'upload (File → URL de la photo)
///  deadline    : fin de la fenêtre de litige ; passé ce délai, l'envoi est refusé
Future<bool?> showOrderDisputeSheet(
  BuildContext context, {
  required int orderId,
  required Future<String> Function(File photo) uploadPhoto,
  DateTime? deadline,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DisputeSheet(
      orderId: orderId,
      uploadPhoto: uploadPhoto,
      deadline: deadline,
    ),
  );
}

class _DisputeSheet extends StatefulWidget {
  const _DisputeSheet({
    required this.orderId,
    required this.uploadPhoto,
    this.deadline,
  });

  final int orderId;
  final Future<String> Function(File photo) uploadPhoto;
  final DateTime? deadline;

  @override
  State<_DisputeSheet> createState() => _DisputeSheetState();
}

class _DisputeSheetState extends State<_DisputeSheet> {
  final _reasonCtrl = TextEditingController();
  final _picker = ImagePicker();

  File? _photo;
  String? _photoUrl;
  bool _uploading = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_submitting &&
      !_uploading &&
      _photoUrl != null &&
      _reasonCtrl.text.trim().isNotEmpty;

  Future<void> _takePhoto() async {
    if (_uploading || _submitting) return;
    XFile? shot;
    try {
      shot = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1600,
      );
    } catch (_) {
      setState(() =>
          _error = "Impossible d'ouvrir la caméra. Vérifiez l'autorisation.");
      return;
    }
    if (shot == null || !mounted) return;

    final file = File(shot.path);
    setState(() {
      _photo = file;
      _photoUrl = null;
      _uploading = true;
      _error = null;
    });
    try {
      final url = await widget.uploadPhoto(file);
      if (!mounted) return;
      setState(() => _photoUrl = url);
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Échec de l'envoi de la photo. Reprenez-la.");
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    FocusManager.instance.primaryFocus?.unfocus();

    final deadline = widget.deadline;
    if (deadline != null && DateTime.now().isAfter(deadline)) {
      setState(() => _error =
          'Le délai de 60 minutes pour signaler un problème est dépassé.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await OrderDisputeService.submitDispute(
        widget.orderId.toString(),
        reason: _reasonCtrl.text,
        proofPhotoUrl: _photoUrl!,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DisputeException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'La réclamation n\'a pas pu être envoyée. Réessayez.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);

    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c, width: w),
        );

    return PopScope(
      canPop: !_submitting,
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Material(
            color: card,
            child: Stack(children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: muted.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.report_gmailerrorred_rounded,
                            color: AppColors.error),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Signaler un problème',
                            style: AppTypography.titleMedium(color: ink)
                                .copyWith(
                                    fontWeight: FontWeight.w800, fontSize: 19)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      'Décrivez le problème et joignez une photo comme preuve. '
                      'Notre équipe étudiera votre réclamation.',
                      style: AppTypography.bodyMedium(color: muted)
                          .copyWith(height: 1.4),
                    ),
                    const SizedBox(height: 20),

                    // Motif
                    TextField(
                      controller: _reasonCtrl,
                      enabled: !_submitting,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() => _error = null),
                      decoration: InputDecoration(
                        labelText: 'Motif de la réclamation *',
                        alignLabelWithHint: true,
                        enabledBorder: b(border),
                        focusedBorder: b(brand, 1.6),
                        disabledBorder: b(border),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Photo de preuve
                    _photoBox(card, border, muted, brand),

                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.error, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: const TextStyle(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 20),
                    OtpGradientButton(
                      label: 'Envoyer la réclamation',
                      icon: Icons.send_rounded,
                      isLoading: _submitting,
                      onPressed: _canSubmit ? _submit : null,
                    ),
                  ],
                ),
              ),
              if (_submitting)
                Positioned.fill(
                  child: ColoredBox(
                    color: card.withValues(alpha: 0.65),
                    child: Center(
                        child: Swirling(size: 52, color: AppColors.brand)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _photoBox(Color card, Color border, Color muted, Color brand) {
    final canShoot = !_uploading && !_submitting;

    if (_photo == null) {
      return GestureDetector(
        onTap: canShoot ? _takePhoto : null,
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: brand.withValues(alpha: 0.5), width: 1.4),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.photo_camera_rounded,
                size: 30, color: canShoot ? brand : muted),
            const SizedBox(height: 6),
            Text('Prendre une photo de preuve *',
                style: TextStyle(
                    color: canShoot ? brand : muted,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 0.6),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(_photo!, width: 88, height: 88, fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_uploading)
              Row(children: [
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Text('Envoi en cours…', style: TextStyle(color: muted)),
              ])
            else if (_photoUrl != null)
              const Row(children: [
                Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 18),
                SizedBox(width: 6),
                Text('Photo envoyée',
                    style: TextStyle(
                        color: AppColors.success, fontWeight: FontWeight.w700)),
              ])
            else
              const Row(children: [
                Icon(Icons.error_outline_rounded,
                    color: AppColors.error, size: 18),
                SizedBox(width: 6),
                Expanded(
                  child: Text('Envoi échoué : reprenez la photo',
                      style: TextStyle(
                          color: AppColors.error, fontWeight: FontWeight.w700)),
                ),
              ]),
            TextButton.icon(
              onPressed: canShoot ? _takePhoto : null,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reprendre'),
            ),
          ]),
        ),
      ]),
    );
  }
}
