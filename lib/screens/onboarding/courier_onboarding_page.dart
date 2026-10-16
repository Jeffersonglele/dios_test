import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_localizations.dart';
import '../../services/courier_application_service.dart';
import '../../services/node_auth_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/image_picker_helper.dart';
import '../../utils/toast.dart';
import '../splash/animated_splash_screen.dart';
import 'wait_identity_validation.dart';

/// Dossier livreur : photo du visage (obligatoire, prise avec la caméra),
/// pièce d'identité et permis de conduire (sauf à vélo). Le livreur ne peut
/// pas livrer avant la validation de ce dossier par l'administration.
class CourierOnboardingPage extends StatefulWidget {
  const CourierOnboardingPage({super.key});

  @override
  State<CourierOnboardingPage> createState() => _CourierOnboardingPageState();
}

/// Justificatif choisi : photo ou PDF présent sur l'appareil.
class _PickedDocument {
  const _PickedDocument({required this.path, required this.name, this.image});
  final String path;
  final String name;

  /// Aperçu quand le document est une photo.
  final XFile? image;
}

class _CourierOnboardingPageState extends State<CourierOnboardingPage> {
  static const _maxBytes = 5 * 1024 * 1024;

  final _picker = ImagePicker();
  final _plateCtrl = TextEditingController();
  XFile? _photo;
  _PickedDocument? _identity;
  _PickedDocument? _license;
  String _vehicle = 'moto';
  String _rejectionRemark = '';
  bool _wasRejected = false;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _plateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final state = await SessionService.fetchServerAccountState();
    if (!mounted) return;
    setState(() {
      if (state != null) {
        if (CourierApplicationService.vehicleTypes
            .contains(state.vehicleType)) {
          _vehicle = state.vehicleType;
        }
        if (_plateCtrl.text.isEmpty) _plateCtrl.text = state.vehiclePlate;
        _wasRejected = state.identity.toLowerCase() == 'rejected';
        _rejectionRemark = state.identityRemark.trim();
      }
      _loading = false;
    });
  }

  // ── Photo du visage : caméra frontale ─────────────────────
  Future<void> _takePhoto() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final canUseCamera =
          await _picker.supportsImageSource(ImageSource.camera);
      final picked = await _picker.pickImage(
        source: canUseCamera ? ImageSource.camera : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1080,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      if (await picked.length() > _maxBytes) {
        if (mounted) Toast(context, l10n.courier_onb_file_too_big, false);
        return;
      }
      setState(() => _photo = picked);
    } catch (_) {
      if (mounted) Toast(context, l10n.identity_camera_error, false);
    }
  }

  // ── Justificatifs : photo ou PDF ──────────────────────────
  Future<_PickedDocument?> _pickDocument() async {
    final l10n = AppLocalizations.of(context)!;
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.identity_take_photo),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.identity_choose_gallery),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(l10n.identity_choose_file),
              subtitle: Text(l10n.courier_onb_formats),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return null;

    try {
      if (source == 'file') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        );
        final file = result?.files.single;
        if (file == null) return null;
        if (file.path == null) {
          if (mounted) Toast(context, l10n.pro_request_error_file_access, false);
          return null;
        }
        if (file.size > _maxBytes) {
          if (mounted) Toast(context, l10n.courier_onb_file_too_big, false);
          return null;
        }
        final isPdf = file.extension?.toLowerCase() == 'pdf';
        return _PickedDocument(
          path: file.path!,
          name: file.name,
          image: isPdf ? null : XFile(file.path!),
        );
      }
      final picked = await _picker.pickImage(
        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) return null;
      if (await picked.length() > _maxBytes) {
        if (mounted) Toast(context, l10n.courier_onb_file_too_big, false);
        return null;
      }
      return _PickedDocument(path: picked.path, name: picked.name, image: picked);
    } catch (_) {
      if (mounted) Toast(context, l10n.identity_gallery_error, false);
      return null;
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final needsLicense = CourierApplicationService.needsLicense(_vehicle);
    if (_photo == null) {
      Toast(context, l10n.courier_onb_photo_required, false);
      return;
    }
    if (_identity == null) {
      Toast(context, l10n.courier_onb_identity_required, false);
      return;
    }
    if (needsLicense && _license == null) {
      Toast(context, l10n.courier_onb_license_required, false);
      return;
    }
    final plate = _plateCtrl.text.trim();
    if (needsLicense && plate.length < 3) {
      Toast(context, l10n.courier_onb_plate_required, false);
      return;
    }
    setState(() => _submitting = true);
    try {
      await CourierApplicationService.submit(
        photoPath: _photo!.path,
        identityPath: _identity!.path,
        licensePath: needsLicense ? _license?.path : null,
        vehicleType: _vehicle,
        vehiclePlate: needsLicense ? plate : null,
      );
      if (!mounted) return;
      Toast(context, l10n.courier_onb_sent, true);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WaitIdentityValidation()),
        (route) => false,
      );
    } on NodeAuthException catch (e) {
      if (mounted) Toast(context, e.message, false);
    } catch (_) {
      if (mounted) Toast(context, l10n.error, false);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _logout() async {
    await SessionService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AnimatedSplashScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final surface = AppColors.resolve(AppColors.surface, AppDarkColors.surface);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final error = AppColors.resolve(AppColors.error, AppDarkColors.error);
    final needsLicense = CourierApplicationService.needsLicense(_vehicle);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: surface,
        appBar: AppBar(
          backgroundColor: surface,
          automaticallyImplyLeading: false,
          title: Text(l10n.courier_onb_title,
              style: AppTypography.titleSmall(color: ink)),
          actions: [
            TextButton(
              onPressed: _submitting ? null : _logout,
              child: Text(l10n.logout,
                  style: AppTypography.labelMedium(color: error)),
            ),
          ],
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: brand))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Text(l10n.courier_onb_intro,
                      style: AppTypography.bodyLarge(color: muted)
                          .copyWith(height: 1.45)),
                  if (_wasRejected) ...[
                    const SizedBox(height: AppSpacing.md),
                    _Notice(
                      color: error,
                      icon: Icons.error_outline_rounded,
                      text: _rejectionRemark.isEmpty
                          ? l10n.courier_onb_rejected
                          : l10n.courier_onb_rejected_reason(_rejectionRemark),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _SectionTitle(
                      number: 1, text: l10n.courier_onb_photo_title, ink: ink),
                  const SizedBox(height: AppSpacing.sm),
                  _PhotoCapture(
                    photo: _photo,
                    hint: l10n.courier_onb_photo_hint,
                    actionLabel: _photo == null
                        ? l10n.courier_onb_take_photo
                        : l10n.courier_onb_retake_photo,
                    onTap: _submitting ? null : _takePhoto,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SectionTitle(
                      number: 2, text: l10n.courier_onb_vehicle_title, ink: ink),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _VehicleChip(
                        label: l10n.signup_vehicle_motorcycle,
                        icon: Icons.two_wheeler_rounded,
                        selected: _vehicle == 'moto',
                        onTap: () => setState(() => _vehicle = 'moto'),
                      ),
                      _VehicleChip(
                        label: l10n.signup_vehicle_bicycle,
                        icon: Icons.pedal_bike_rounded,
                        selected: _vehicle == 'velo',
                        onTap: () => setState(() => _vehicle = 'velo'),
                      ),
                      _VehicleChip(
                        label: l10n.signup_vehicle_car,
                        icon: Icons.directions_car_rounded,
                        selected: _vehicle == 'voiture',
                        onTap: () => setState(() => _vehicle = 'voiture'),
                      ),
                    ],
                  ),
                  if (needsLicense) ...[
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _plateCtrl,
                      enabled: !_submitting,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9 -]')),
                        LengthLimitingTextInputFormatter(15),
                      ],
                      style: AppTypography.bodyLarge(color: ink)
                          .copyWith(letterSpacing: 1.2),
                      decoration: InputDecoration(
                        labelText: l10n.courier_onb_plate_label,
                        hintText: l10n.courier_onb_plate_hint,
                        prefixIcon: const Icon(Icons.pin_outlined),
                        filled: true,
                        fillColor: AppColors.resolve(
                            AppColors.card, AppDarkColors.card),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _SectionTitle(
                      number: 3,
                      text: l10n.courier_onb_documents_title,
                      ink: ink),
                  const SizedBox(height: AppSpacing.sm),
                  _DocumentTile(
                    label: l10n.identity_id_document,
                    document: _identity,
                    emptyText: l10n.courier_onb_add_document,
                    onTap: _submitting
                        ? null
                        : () async {
                            final doc = await _pickDocument();
                            if (doc != null && mounted) {
                              setState(() => _identity = doc);
                            }
                          },
                  ),
                  if (needsLicense) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _DocumentTile(
                      label: l10n.livreur_license,
                      document: _license,
                      emptyText: l10n.courier_onb_add_document,
                      onTap: _submitting
                          ? null
                          : () async {
                              final doc = await _pickDocument();
                              if (doc != null && mounted) {
                                setState(() => _license = doc);
                              }
                            },
                    ),
                  ] else ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(l10n.courier_onb_no_license_bike,
                        style: AppTypography.bodySmall(color: muted)),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(l10n.courier_onb_submit,
                              style:
                                  AppTypography.labelLarge(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.courier_onb_privacy,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall(color: muted)),
                ],
              ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(
      {required this.number, required this.text, required this.ink});
  final int number;
  final String text;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    return Row(children: [
      Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: brand.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Text('$number',
            style: AppTypography.labelMedium(color: brand)
                .copyWith(fontWeight: FontWeight.w800)),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(text,
            style: AppTypography.titleSmall(color: ink)
                .copyWith(fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}

class _PhotoCapture extends StatelessWidget {
  const _PhotoCapture({
    required this.photo,
    required this.hint,
    required this.actionLabel,
    required this.onTap,
  });
  final XFile? photo;
  final String hint;
  final String actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final surface =
        AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: photo != null ? brand.withValues(alpha: 0.5) : border),
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 84,
              height: 84,
              child: photo != null
                  ? pickedImagePreview(photo!, width: 84, height: 84)
                  : Container(
                      color: surface,
                      child: Icon(Icons.face_retouching_natural_rounded,
                          color: brand, size: 38),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hint,
                    style: AppTypography.bodySmall(color: muted)
                        .copyWith(height: 1.4)),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onTap,
                  icon: Icon(Icons.photo_camera_rounded, color: brand, size: 18),
                  label: Text(actionLabel,
                      style: AppTypography.labelMedium(color: brand)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: brand.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleChip extends StatelessWidget {
  const _VehicleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? brand.withValues(alpha: 0.10) : card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? brand.withValues(alpha: 0.6) : border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: selected ? brand : muted),
          const SizedBox(width: 8),
          Text(label,
              style: AppTypography.labelMedium(color: selected ? brand : muted)
                  .copyWith(
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500)),
        ]),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.label,
    required this.document,
    required this.emptyText,
    required this.onTap,
  });
  final String label;
  final _PickedDocument? document;
  final String emptyText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final success = AppColors.resolve(AppColors.success, AppDarkColors.success);
    final doc = document;

    return Material(
      color: card,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
                color: doc != null ? brand.withValues(alpha: 0.5) : border),
          ),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(
                width: 48,
                height: 48,
                child: doc?.image != null
                    ? pickedImagePreview(doc!.image!, width: 48, height: 48)
                    : Container(
                        color: brand.withValues(alpha: 0.08),
                        child: Icon(
                          doc != null
                              ? Icons.picture_as_pdf_rounded
                              : Icons.badge_outlined,
                          color: brand,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTypography.labelMedium(color: ink)
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(doc?.name ?? emptyText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall(color: muted)),
                ],
              ),
            ),
            Icon(
              doc != null
                  ? Icons.check_circle_rounded
                  : Icons.add_circle_outline_rounded,
              color: doc != null ? success : brand,
            ),
          ]),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.color, required this.icon, required this.text});
  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: AppTypography.bodyMedium(color: color)),
          ),
        ],
      ),
    );
  }
}
