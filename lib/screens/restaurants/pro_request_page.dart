import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/models/pro_document.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/toast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:path/path.dart' as p;

class ProRequestPage extends StatefulWidget {
  const ProRequestPage({super.key});

  @override
  State<ProRequestPage> createState() => _ProRequestPageState();
}

class _ProRequestPageState extends State<ProRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  XFile? _identityFile;
  XFile? _proDocFile;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickIdentityFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    final file = result?.files.single;
    if (file?.bytes != null) {
      setState(() => _identityFile = XFile.fromData(file!.bytes!, name: file.name));
    }
  }

  Future<void> _pickProDocFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    final file = result?.files.single;
    if (file?.bytes != null) {
      setState(() => _proDocFile = XFile.fromData(file!.bytes!, name: file.name));
    }
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

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final identityFile = ParseXFile(
        _identityFile!,
        name: 'identity_${session.userId}_$timestamp${p.extension(_identityFile!.name)}',
      );
      final proDocFile = ParseXFile(
        _proDocFile!,
        name: 'prodoc_${session.userId}_$timestamp${p.extension(_proDocFile!.name)}',
      );

      final result = await ProDocument.submitDocuments(
        userID: session.userId,
        restaurantID: session.restaurantId ?? 0,
        pieceIdentite: identityFile,
        kbis: proDocFile,
        description: _descriptionController.text.trim(),
      );

      if (!mounted) return;

      if (result == 'success') {
        Toast(context, l10n.pro_request_success, true);
        Navigator.pop(context, true);
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

    return Scaffold(
      backgroundColor:
          AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      appBar: AppBar(
        title: Text(l10n.pro_request_title,
            style: AppTypography.titleSmall()),
        backgroundColor:
            AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.pro_request_subtitle,
                  style: AppTypography.bodyLarge()),
              const SizedBox(height: 24),

              // ── Identity document ──────────────────────────
              _DocumentPicker(
                label: l10n.pro_request_identity_doc,
                file: _identityFile,
                onPick: _pickIdentityFile,
                l10n: l10n,
              ),
              const SizedBox(height: 20),

              // ── Professional document ──────────────────────
              _DocumentPicker(
                label: l10n.pro_request_pro_doc,
                file: _proDocFile,
                onPick: _pickProDocFile,
                l10n: l10n,
              ),
              const SizedBox(height: 24),

              // ── Description ────────────────────────────────
              Text(l10n.pro_request_description_label,
                  style: AppTypography.labelMedium()),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 6,
                maxLength: 1000,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.pro_request_error_description : null,
                decoration: InputDecoration(
                  hintText: l10n.pro_request_description_hint,
                  hintStyle: AppTypography.bodyMedium(color: AppColors.inkSubtle),
                  filled: true,
                  fillColor: AppColors.resolve(AppColors.card, AppDarkColors.card),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Submit ─────────────────────────────────────
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
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
                          style: AppTypography.labelLarge()),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentPicker extends StatelessWidget {
  final String label;
  final XFile? file;
  final VoidCallback onPick;
  final AppLocalizations l10n;

  const _DocumentPicker({
    required this.label,
    required this.file,
    required this.onPick,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelMedium()),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onPick,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.resolve(AppColors.card, AppDarkColors.card),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: file != null ? AppColors.brand : AppColors.border,
                width: file != null ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  file != null
                      ? Icons.check_circle_rounded
                      : Icons.upload_file_rounded,
                  color: file != null ? AppColors.success : AppColors.inkMuted,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    file != null
                        ? '${l10n.pro_request_file_selected} (${file!.name})'
                        : l10n.pro_request_no_file,
                    style: AppTypography.bodyMedium(
                      color: file != null ? AppColors.ink : AppColors.inkSubtle,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.pro_request_pick_file,
                  style: AppTypography.labelMedium(color: AppColors.brand),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
