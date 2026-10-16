import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/models/pro_document.dart';
import 'package:dios_delices/providers/theme_provider.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/toast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class ProRequestPage extends StatefulWidget {
  const ProRequestPage({super.key});

  @override
  State<ProRequestPage> createState() => _ProRequestPageState();
}

class _ProRequestPageState extends State<ProRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  /// Taille maximale acceptée par le serveur pour un justificatif.
  static const _maxBytes = 5 * 1024 * 1024;

  PlatformFile? _identityFile;
  PlatformFile? _proDocFile;
  bool _isSubmitting = false;

  /// État de la demande lu sur le serveur (null pendant le chargement).
  ServerAccountState? _state;
  bool _loadingState = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final state = await SessionService.fetchServerAccountState();
    if (!mounted) return;
    setState(() {
      _state = state;
      _loadingState = false;
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  /// Fichier réel sur l'appareil : son chemin sert à l'envoi multipart.
  Future<PlatformFile?> _pickDocument() async {
    final l10n = AppLocalizations.of(context)!;
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
      if (mounted) Toast(context, l10n.pro_request_error_file_size, false);
      return null;
    }
    return file;
  }

  Future<void> _pickIdentityFile() async {
    final file = await _pickDocument();
    if (file != null && mounted) setState(() => _identityFile = file);
  }

  Future<void> _pickProDocFile() async {
    final file = await _pickDocument();
    if (file != null && mounted) setState(() => _proDocFile = file);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;

    if (_identityFile == null) {
      Toast(context, l10n.pro_request_error_identity, false);
      return;
    }
    if (_proDocFile == null) {
      Toast(context, l10n.pro_request_error_pro_doc, false);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final session = await SessionService.readSession();

      final result = await ProDocument.submitDocuments(
        userID: session.userId,
        restaurantID: session.restaurantId ?? _state?.restaurantId ?? 0,
        pieceIdentitePath: _identityFile!.path!,
        kbisPath: _proDocFile!.path!,
        description: _descriptionController.text.trim(),
      );

      if (!mounted) return;

      if (result == 'success') {
        Toast(context, l10n.pro_request_success, true);
        await _loadState();
      } else {
        Toast(context, result, false);
      }
    } catch (e) {
      if (mounted) {
        Toast(context, '${l10n.error}: $e', false);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AnimatedBuilder(
      animation: darkModeNotifier,
      builder: (context, _) {
        final surface =
            AppColors.resolve(AppColors.surface, AppDarkColors.surface);
        final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
        final inkMuted =
            AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
        final inkSubtle =
            AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle);
        final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
        final border =
            AppColors.resolve(AppColors.border, AppDarkColors.border);
        final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
        final success =
            AppColors.resolve(AppColors.success, AppDarkColors.success);

        return Scaffold(
          backgroundColor: surface,
          appBar: AppBar(
            title: Text(l10n.pro_request_title,
                style: AppTypography.titleSmall(color: ink)),
            backgroundColor: surface,
          ),
          body: _loadingState
              ? Center(child: CircularProgressIndicator(color: brand))
              : _statusOnly(l10n, ink, inkMuted, card, border, brand, success) ??
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_state?.proRequestStatus == 'rejected') ...[
                    _StatusCard(
                      icon: Icons.error_outline_rounded,
                      color: AppColors.resolve(
                          AppColors.error, AppDarkColors.error),
                      title: l10n.pro_request_rejected_title,
                      body: _state!.proRequestRemark.trim().isEmpty
                          ? l10n.pro_request_rejected_body
                          : l10n.pro_request_rejected_reason(
                              _state!.proRequestRemark.trim()),
                      card: card,
                      ink: ink,
                      inkMuted: inkMuted,
                    ),
                    const SizedBox(height: 20),
                  ],
                  Text(l10n.pro_request_subtitle,
                      style: AppTypography.bodyLarge(color: ink)),
                  const SizedBox(height: 24),
                  _DocumentPicker(
                    label: l10n.pro_request_identity_doc,
                    file: _identityFile,
                    onPick: _pickIdentityFile,
                    l10n: l10n,
                    ink: ink,
                    inkMuted: inkMuted,
                    inkSubtle: inkSubtle,
                    card: card,
                    border: border,
                    brand: brand,
                    success: success,
                  ),
                  const SizedBox(height: 20),
                  _DocumentPicker(
                    label: l10n.pro_request_pro_doc,
                    file: _proDocFile,
                    onPick: _pickProDocFile,
                    l10n: l10n,
                    ink: ink,
                    inkMuted: inkMuted,
                    inkSubtle: inkSubtle,
                    card: card,
                    border: border,
                    brand: brand,
                    success: success,
                  ),
                  const SizedBox(height: 24),
                  Text(l10n.pro_request_description_label,
                      style: AppTypography.labelMedium(color: inkMuted)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 6,
                    maxLength: 1000,
                    style: AppTypography.bodyLarge(color: ink),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.pro_request_error_description
                        : null,
                    decoration: InputDecoration(
                      hintText: l10n.pro_request_description_hint,
                      hintStyle: AppTypography.bodyMedium(color: inkSubtle),
                      counterStyle: AppTypography.bodySmall(color: inkMuted),
                      filled: true,
                      fillColor: card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(color: border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(color: border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(color: brand, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        surfaceTintColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(l10n.pro_request_submit,
                              style: AppTypography.labelLarge(
                                  color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

extension on _ProRequestPageState {
  /// Écran d'état quand aucune demande ne peut être envoyée : restaurant
  /// déjà Pro, demande en cours d'examen ou restaurant pas encore validé.
  Widget? _statusOnly(AppLocalizations l10n, Color ink, Color inkMuted,
      Color card, Color border, Color brand, Color success) {
    final state = _state;
    if (state == null) return null;
    final (IconData icon, Color color, String title, String body)? status =
        state.restaurantIsPro
            ? (
                Icons.workspace_premium_rounded,
                success,
                l10n.pro_request_already_pro_title,
                l10n.pro_request_already_pro_body
              )
            : state.proRequestStatus == 'pending'
                ? (
                    Icons.hourglass_top_rounded,
                    brand,
                    l10n.pro_request_pending_title,
                    l10n.pro_request_pending_body
                  )
                : state.restaurantValid != 1
                    ? (
                        Icons.storefront_rounded,
                        inkMuted,
                        l10n.pro_request_needs_validation_title,
                        l10n.pro_request_needs_validation_body
                      )
                    : null;
    if (status == null) return null;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _StatusCard(
          icon: status.$1,
          color: status.$2,
          title: status.$3,
          body: status.$4,
          card: card,
          ink: ink,
          inkMuted: inkMuted,
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.card,
    required this.ink,
    required this.inkMuted,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final Color card;
  final Color ink;
  final Color inkMuted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleSmall(color: ink)),
                const SizedBox(height: 4),
                Text(body,
                    style: AppTypography.bodyMedium(color: inkMuted)
                        .copyWith(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentPicker extends StatelessWidget {
  final String label;
  final PlatformFile? file;
  final VoidCallback onPick;
  final AppLocalizations l10n;
  final Color ink;
  final Color inkMuted;
  final Color inkSubtle;
  final Color card;
  final Color border;
  final Color brand;
  final Color success;

  const _DocumentPicker({
    required this.label,
    required this.file,
    required this.onPick,
    required this.l10n,
    required this.ink,
    required this.inkMuted,
    required this.inkSubtle,
    required this.card,
    required this.border,
    required this.brand,
    required this.success,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelMedium(color: inkMuted)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onPick,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: file != null ? brand : border,
                width: file != null ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  file != null
                      ? Icons.check_circle_rounded
                      : Icons.upload_file_rounded,
                  color: file != null ? success : inkMuted,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    file != null
                        ? '${l10n.pro_request_file_selected} (${file!.name})'
                        : l10n.pro_request_no_file,
                    style: AppTypography.bodyMedium(
                      color: file != null ? ink : inkSubtle,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.pro_request_pick_file,
                  style: AppTypography.labelMedium(color: brand),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
