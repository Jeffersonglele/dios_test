import 'package:cached_network_image/cached_network_image.dart';
import 'package:dios_delices/services/node_admin_service.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_role.dart';
import '../../l10n/app_localizations.dart';
import '../../services/node_auth_service.dart';
import '../../utils/currency_util.dart';
import '../../utils/toast.dart';
import '../../widgets/courier_card.dart';
import 'livreur_list_page.dart';

/// Fiche admin d'un livreur : profil, véhicule, dossier (photo, pièce
/// d'identité, permis) et validation ou refus du dossier.
class LivreurFichePage extends StatefulWidget {
  final int userID;
  const LivreurFichePage({super.key, required this.userID});

  @override
  State<LivreurFichePage> createState() => _LivreurFichePageState();
}

class _LivreurFichePageState extends State<LivreurFichePage> {
  Map<String, dynamic>? _courier;
  bool _isLoading = true;
  bool _busy = false;
  bool _canValidate = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final session = await SessionService.readSession();
      final token = await SessionService.readNodeToken();
      final courier = token == null
          ? null
          : await NodeAdminService.getCourier(token, widget.userID);
      if (!mounted) return;
      setState(() {
        _courier = courier;
        // Un admin valide les livreurs de son pays ; le super admin, tous.
        _canValidate = session.role == AppRole.superAdmin ||
            (session.role.isAdmin &&
                (courier?['country']?.toString() ?? '') == session.country);
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic>? get _file => _courier?['file'] is Map
      ? Map<String, dynamic>.from(_courier!['file'] as Map)
      : null;

  CourierFileStatus get _status => courierFileStatusOf(_courier?['fileStatus']);

  void _openDocument(String url, String title) {
    final isPdf = url.toLowerCase().split('?').first.endsWith('.pdf');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          backgroundColor: Colors.black,
          body: isPdf
              ? SfPdfViewer.network(url)
              : InteractiveViewer(
                  maxScale: 5,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: url,
                      placeholder: (_, __) =>
                          const CircularProgressIndicator(),
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.broken_image, color: Colors.white),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _decide({required bool approve}) async {
    final l10n = AppLocalizations.of(context)!;
    final file = _file;
    if (file == null) return;
    final remarkCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(approve
            ? l10n.courier_admin_validate_file
            : l10n.livreur_document_reject_title),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                approve
                    ? l10n.courier_admin_validate_confirm(courierName(_courier!))
                    : l10n.livreur_document_reject_hint,
                style: AppTypography.bodyMedium(),
              ),
              if (!approve) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: remarkCtrl,
                  maxLines: 3,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? l10n.required : null,
                  decoration: InputDecoration(
                    hintText: l10n.livreur_document_reject_hint,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? AppColors.success : AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (approve || formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: Text(approve ? l10n.validate : l10n.reject),
          ),
        ],
      ),
    );
    final remark = remarkCtrl.text;
    remarkCtrl.dispose();
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final token = await SessionService.readNodeToken();
      if (token == null) return;
      await NodeAdminService.validateDeliveryDocuments(
        file['id']?.toString() ?? '',
        approve ? 'VALIDATED' : 'REJECTED',
        token,
        remark: approve ? null : remark,
      );
      if (!mounted) return;
      Toast(
          context,
          approve
              ? l10n.courier_admin_file_validated
              : l10n.courier_admin_file_rejected,
          true);
      await _load();
    } on NodeAuthException catch (e) {
      if (mounted) Toast(context, e.message, false);
    } catch (_) {
      if (mounted) Toast(context, l10n.error, false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final surface = AppColors.resolve(AppColors.surface, AppDarkColors.surface);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: surface,
        title: Text(l10n.livreur_fiche_title,
            style: AppTypography.titleSmall(color: ink)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _courier == null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.person_off_rounded, size: 56, color: muted),
                    const SizedBox(height: 10),
                    Text(l10n.livreur_not_found,
                        style: AppTypography.bodyLarge(color: muted)),
                  ]),
                )
              : Stack(children: [
                  RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 14),
                        _buildStats(),
                        const SizedBox(height: 14),
                        _buildFile(),
                        if (_canValidate &&
                            _status == CourierFileStatus.pending) ...[
                          const SizedBox(height: 16),
                          _buildDecision(),
                        ],
                      ],
                    ),
                  ),
                  if (_busy)
                    const ColoredBox(
                      color: Colors.black26,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ]),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: AppColors.resolve(AppColors.border, AppDarkColors.border),
            width: 0.6),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text.toUpperCase(),
            style: AppTypography.labelMedium(
                    color: AppColors.resolve(
                        AppColors.inkMuted, AppDarkColors.inkMuted))
                .copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.8)),
      );

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    final c = _courier!;
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final photo = c['image']?.toString();
    final phone = c['telephone']?.toString() ?? '';
    final email = c['email']?.toString() ?? '';
    final plate = c['vehiclePlate']?.toString() ?? '';
    final vehicle = c['vehicleType']?.toString();
    final online = c['isOnline'] == true;

    return _card(
      child: Column(children: [
        GestureDetector(
          onTap: photo == null || photo.isEmpty
              ? null
              : () => _openDocument(photo, l10n.courier_admin_photo),
          child: CourierPhotoAvatar(
            photoUrl: photo,
            initials: courierInitials(c),
            online: online,
            radius: 46,
          ),
        ),
        const SizedBox(height: 12),
        Text(courierName(c),
            textAlign: TextAlign.center,
            style: AppTypography.headlineMedium(color: ink)
                .copyWith(fontSize: 22)),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            CourierFileStatusPill(status: _status),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (online ? AppColors.success : muted)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                  online ? l10n.livreur_filter_online : l10n.livreur_filter_offline,
                  style: AppTypography.labelMedium(
                          color: online ? AppColors.success : muted)
                      .copyWith(fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(courierVehicleIcon(vehicle), size: 18, color: brand),
              const SizedBox(width: 6),
              Text(courierVehicleLabel(vehicle, l10n),
                  style: AppTypography.bodyMedium(color: ink)),
            ]),
            if (plate.isNotEmpty) VehiclePlateBadge(plate: plate),
          ],
        ),
        const SizedBox(height: 14),
        Divider(
            height: 1,
            color: AppColors.resolve(AppColors.border, AppDarkColors.border)),
        if (phone.isNotEmpty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(Icons.phone_rounded, color: brand),
            title: Text(phone, style: AppTypography.bodyMedium(color: ink)),
            onTap: () => launchUrl(
                Uri(scheme: 'tel', path: phone.replaceAll(' ', '')),
                mode: LaunchMode.externalApplication),
          ),
        if (email.isNotEmpty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(Icons.mail_outline_rounded, color: muted),
            title: Text(email, style: AppTypography.bodyMedium(color: ink)),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: Icon(Icons.public_rounded, color: muted),
          title: Text(c['country']?.toString() ?? '—',
              style: AppTypography.bodyMedium(color: ink)),
        ),
      ]),
    );
  }

  Widget _buildStats() {
    final l10n = AppLocalizations.of(context)!;
    final stats = _courier?['stats'] is Map
        ? Map<String, dynamic>.from(_courier!['stats'] as Map)
        : const <String, dynamic>{};
    final country = _courier?['country']?.toString() ?? 'RDC';
    final fees = double.tryParse('${stats['deliveryFees']}') ?? 0;
    return Row(children: [
      _statBox(Icons.check_circle_outline_rounded,
          '${stats['deliveredCount'] ?? 0}', l10n.myDeliveries),
      const SizedBox(width: 10),
      _statBox(Icons.payments_outlined, CurrencyUtil.formatPrice(fees, country),
          l10n.courier_admin_delivery_fees),
      const SizedBox(width: 10),
      _statBox(Icons.route_rounded, '${stats['activeCount'] ?? 0}',
          l10n.courier_admin_active_orders),
    ]);
  }

  Widget _statBox(IconData icon, String value, String label) {
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    return Expanded(
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: brand),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: AppTypography.titleSmall(color: ink)
                      .copyWith(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 2,
                style: AppTypography.bodySmall(color: muted)
                    .copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildFile() {
    final l10n = AppLocalizations.of(context)!;
    final file = _file;
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final error = AppColors.resolve(AppColors.error, AppDarkColors.error);
    final remark = file?['remark']?.toString().trim() ?? '';
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(l10n.livreur_documents),
          if (file == null)
            Text(l10n.courier_admin_no_file_body,
                style: AppTypography.bodyMedium(color: muted))
          else ...[
            _docTile(l10n.courier_admin_photo, file['photoUrl']?.toString(),
                Icons.face_rounded),
            const SizedBox(height: 10),
            _docTile(l10n.livreur_id_card, file['identityFileUrl']?.toString(),
                Icons.badge_outlined),
            if (file['vehicleType']?.toString() != 'velo') ...[
              const SizedBox(height: 10),
              _docTile(l10n.livreur_license, file['licenseUrl']?.toString(),
                  Icons.credit_card_rounded),
            ],
            if (_status == CourierFileStatus.rejected && remark.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(l10n.courier_admin_rejection_reason(remark),
                    style: AppTypography.bodyMedium(color: error)),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _docTile(String title, String? url, IconData icon) {
    final l10n = AppLocalizations.of(context)!;
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final warm =
        AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);
    final has = url != null && url.isNotEmpty;
    final isPdf = has && url.toLowerCase().split('?').first.endsWith('.pdf');
    return Material(
      color: warm,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: has ? () => _openDocument(url, title) : null,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(
                width: 52,
                height: 52,
                child: has && !isPdf
                    ? CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Icon(icon, color: brand),
                      )
                    : ColoredBox(
                        color: brand.withValues(alpha: 0.10),
                        child: Icon(
                            isPdf ? Icons.picture_as_pdf_rounded : icon,
                            color: brand),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTypography.labelLarge(color: ink)),
                  Text(has ? l10n.courier_admin_tap_to_view : l10n.livreur_not_provided,
                      style: AppTypography.bodySmall(color: muted)),
                ],
              ),
            ),
            if (has) Icon(Icons.open_in_full_rounded, color: brand, size: 20),
          ]),
        ),
      ),
    );
  }

  Widget _buildDecision() {
    final l10n = AppLocalizations.of(context)!;
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: _busy ? null : () => _decide(approve: false),
          icon: const Icon(Icons.close_rounded, size: 18),
          label: Text(l10n.reject),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: ElevatedButton.icon(
          onPressed: _busy ? null : () => _decide(approve: true),
          icon: const Icon(Icons.check_rounded, size: 18),
          label: Text(l10n.validate),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md)),
          ),
        ),
      ),
    ]);
  }
}
