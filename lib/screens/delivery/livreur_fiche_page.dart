import 'package:cached_network_image/cached_network_image.dart';
import 'package:dios_delices/models/identity.dart';
import 'package:dios_delices/models/users.dart';
import 'package:dios_delices/services/livreur_api.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../core/app_role.dart';
import '../../utils/toast.dart';
import '../../widgets/dios_image.dart';
import '../../l10n/app_localizations.dart';

class LivreurFichePage extends StatefulWidget {
  final int userID;
  const LivreurFichePage({super.key, required this.userID});

  @override
  State<LivreurFichePage> createState() => _LivreurFichePageState();
}

class _LivreurFichePageState extends State<LivreurFichePage> {
  Users? _livreur;
  Identity? _identity;
  bool _isLoading = true;
  bool _isAdmin = false;
  bool _isSuperAdmin = false;
  bool _canValidate = false;

  int _totalLivraisons = 0;
  double _totalGains = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final session = await SessionService.readSession();
      _isAdmin = session.role.isAdmin;
      _isSuperAdmin = session.role == AppRole.superAdmin;

      final users = await Users.fetchUsersFromDB();
      final livreur = Users.getUsersByUserId(users, widget.userID);

      final identities = await Identity.fetchIdentitiesFromDB();
      final identity = Identity.getIdentityByUserId(identities, widget.userID);

      if (_isSuperAdmin) {
        _canValidate = true;
      } else if (_isAdmin && livreur != null) {
        _canValidate = session.country == livreur.country;
      }

      final earnings = await LivreurApi.getLivreurEarnings(widget.userID);
      if (earnings['success'] == true) {
        _totalLivraisons = (earnings['totalLivraisons'] as num?)?.toInt() ?? 0;
        _totalGains = (earnings['totalGains'] as num?)?.toDouble() ?? 0.0;
      }

      if (mounted) {
        setState(() {
          _livreur = livreur;
          _identity = identity;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _vehicleIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'moto':
        return Icons.motorcycle_rounded;
      case 'velo':
        return Icons.pedal_bike_rounded;
      case 'voiture':
        return Icons.directions_car_rounded;
      default:
        return Icons.delivery_dining_rounded;
    }
  }

  String _vehicleLabel(String? type) {
    final l10n = AppLocalizations.of(context)!;
    switch (type?.toLowerCase()) {
      case 'moto':
        return l10n.livreur_vehicle_moto;
      case 'velo':
        return l10n.livreur_vehicle_bike;
      case 'voiture':
        return l10n.livreur_vehicle_car;
      default:
        return l10n.livreur_vehicle_unspecified;
    }
  }

  void _handleFilePreview(String fileUrl) {
    if (fileUrl.toLowerCase().endsWith('.pdf')) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _PDFViewerScreen(fileUrl: fileUrl)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => _FullScreenImageViewer(imageUrl: fileUrl)),
      );
    }
  }

  Future<void> _validateDocument(String type) async {
    final cloud = ParseCloudFunction('validateLivreurIdentity');
    try {
      final response = await cloud.execute(parameters: {
        'userID': widget.userID,
        'valid': true,
        'type': type,
      });
      if (response.success && mounted) {
        setState(() {
          if (type == 'permis') {
            _livreur?.permisVerified = true;
          } else if (type == 'identity') {
            _livreur?.identity = 'Verified';
          }
        });
        Toast(context, AppLocalizations.of(context)!.livreur_document_validated,
            true);
        _load();
      }
    } catch (_) {
      if (mounted)
        Toast(
            context,
            AppLocalizations.of(context)!.livreur_document_validate_error,
            false);
    }
  }

  void _showRejectDialog(String type) {
    final remarkCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.resolve(
                  AppColors.errorLight, AppDarkColors.errorLight),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.error_rounded,
                color: AppColors.error, size: 18),
          ),
          const SizedBox(width: 10),
          Text(AppLocalizations.of(context)!.livreur_document_reject_title,
              style: AppTypography.titleMedium(
                  color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.livreur_document_reject_hint,
                style: AppTypography.bodyLarge(
                    color:
                        AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
            const SizedBox(height: 12),
            TextField(
              controller: remarkCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    AppLocalizations.of(context)!.livreur_document_reject_hint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(
                      color: AppColors.resolve(
                          AppColors.border, AppDarkColors.border)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.cancel,
                style: AppTypography.labelMedium(
                    color: AppColors.resolve(
                        AppColors.inkMuted, AppDarkColors.inkMuted))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _rejectDocument(type, remarkCtrl.text);
            },
            child: Text(
                '${AppLocalizations.of(context)!.confirm} ${AppLocalizations.of(context)!.reject}'),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectDocument(String type, String remark) async {
    final cloud = ParseCloudFunction('validateLivreurIdentity');
    try {
      final response = await cloud.execute(parameters: {
        'userID': widget.userID,
        'valid': false,
        'type': type,
        'remark': remark,
      });
      if (response.success && mounted) {
        setState(() {
          if (type == 'permis') {
            _livreur?.permisVerified = false;
          } else if (type == 'identity') {
            _livreur?.identity = 'Rejected';
          }
        });
        Toast(context, AppLocalizations.of(context)!.livreur_document_rejected,
            false);
        _load();
      }
    } catch (_) {
      if (mounted)
        Toast(context,
            AppLocalizations.of(context)!.livreur_document_reject_error, false);
    }
  }

  void _showValidateDialog(String type, String label) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.resolve(
                  AppColors.successLight, AppDarkColors.successLight),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.verified_rounded,
                color: AppColors.success, size: 18),
          ),
          const SizedBox(width: 10),
          Text('${l10n.validate} $label',
              style: AppTypography.titleMedium(
                  color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
        ]),
        content: Text(
          '${l10n.confirm} ${l10n.livreur_document_validated.toLowerCase()} $label ${_livreur?.firstname} ${_livreur?.lastname} ?',
          style: AppTypography.bodyLarge(
              color: AppColors.resolve(AppColors.ink, AppDarkColors.ink)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx)!.cancel,
                style: AppTypography.labelMedium(
                    color: AppColors.resolve(
                        AppColors.inkMuted, AppDarkColors.inkMuted))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _validateDocument(type);
            },
            child: Text(AppLocalizations.of(ctx)!.validate),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return Scaffold(
        backgroundColor:
            AppColors.resolve(AppColors.surface, AppDarkColors.surface),
        appBar: AppBar(title: Text(l10n.livreur_fiche_title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_livreur == null) {
      return Scaffold(
        backgroundColor:
            AppColors.resolve(AppColors.surface, AppDarkColors.surface),
        appBar: AppBar(title: Text(l10n.livreur_fiche_title)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_rounded,
                  size: 64,
                  color: AppColors.resolve(
                      AppColors.inkSubtle, AppDarkColors.inkSubtle)),
              const SizedBox(height: 12),
              Text(l10n.livreur_not_found,
                  style: AppTypography.bodyLarge(
                      color: AppColors.resolve(
                          AppColors.inkMuted, AppDarkColors.inkMuted))),
            ],
          ),
        ),
      );
    }

    final livreur = _livreur!;
    final isOnline = livreur.isOnline == true;
    final permisOk = livreur.permisVerified == true;
    final identityOk = livreur.identity == 'Verified';
    final identityPending = !identityOk && livreur.identity != 'Rejected';

    return Scaffold(
      backgroundColor:
          AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.livreur_fiche_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildHeader(livreur),
              const SizedBox(height: 16),
              _buildStatusBadges(livreur),
              const SizedBox(height: 16),
              _buildStatsSection(),
              const SizedBox(height: 16),
              _buildDocumentsSection(livreur),
              const SizedBox(height: 16),
              if (_canValidate) _buildValidationActions(livreur),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Users livreur) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.resolve(
                    AppColors.brandSurface, AppDarkColors.brandSurface),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  _vehicleIcon(livreur.permisType),
                  color:
                      AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${livreur.firstname} ${livreur.lastname}',
              style: AppTypography.titleLarge(
                  color: AppColors.resolve(AppColors.ink, AppDarkColors.ink)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.email_outlined,
                    size: 14,
                    color: AppColors.resolve(
                        AppColors.inkMuted, AppDarkColors.inkMuted)),
                const SizedBox(width: 4),
                Text(livreur.email,
                    style: AppTypography.bodyMedium(
                            color: AppColors.resolve(
                                AppColors.ink, AppDarkColors.ink))
                        .copyWith(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.phone_outlined,
                    size: 14,
                    color: AppColors.resolve(
                        AppColors.inkMuted, AppDarkColors.inkMuted)),
                const SizedBox(width: 4),
                Text(livreur.telephone,
                    style: AppTypography.bodyMedium(
                            color: AppColors.resolve(
                                AppColors.ink, AppDarkColors.ink))
                        .copyWith(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.public_outlined,
                    size: 14,
                    color: AppColors.resolve(
                        AppColors.inkMuted, AppDarkColors.inkMuted)),
                const SizedBox(width: 4),
                Text(livreur.country,
                    style: AppTypography.bodyMedium(
                            color: AppColors.resolve(
                                AppColors.ink, AppDarkColors.ink))
                        .copyWith(fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadges(Users livreur) {
    final l10n = AppLocalizations.of(context)!;
    final isOnline = livreur.isOnline == true;
    final permisOk = livreur.permisVerified == true;
    final identityOk = livreur.identity == 'Verified';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.livreur_stats,
                style: AppTypography.titleMedium(
                    color:
                        AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statusChip(
                  icon: isOnline ? Icons.circle : Icons.circle_outlined,
                  label:
                      isOnline ? l10n.delivery_online : l10n.delivery_offline,
                  color: isOnline
                      ? AppColors.resolve(
                          AppColors.success, AppDarkColors.success)
                      : AppColors.resolve(
                          AppColors.inkSubtle, AppDarkColors.inkSubtle),
                  bgColor: isOnline
                      ? AppColors.resolve(
                          AppColors.successLight, AppDarkColors.successLight)
                      : AppColors.resolve(
                          AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
                ),
                _statusChip(
                  icon: permisOk
                      ? Icons.check_circle_rounded
                      : Icons.schedule_rounded,
                  label:
                      '${l10n.livreur_license} ${permisOk ? l10n.livreur_validated : l10n.livreur_pending}',
                  color: permisOk
                      ? AppColors.resolve(
                          AppColors.success, AppDarkColors.success)
                      : AppColors.accent,
                  bgColor: permisOk
                      ? AppColors.resolve(
                          AppColors.successLight, AppDarkColors.successLight)
                      : AppColors.resolve(
                          AppColors.accentLight, AppDarkColors.accentLight),
                ),
                _statusChip(
                  icon: identityOk
                      ? Icons.check_circle_rounded
                      : Icons.schedule_rounded,
                  label:
                      '${l10n.livreur_id_card} ${identityOk ? l10n.livreur_validated : l10n.livreur_pending}',
                  color: identityOk
                      ? AppColors.resolve(
                          AppColors.success, AppDarkColors.success)
                      : AppColors.resolve(
                          AppColors.accent, AppDarkColors.accent),
                  bgColor: identityOk
                      ? AppColors.resolve(
                          AppColors.successLight, AppDarkColors.successLight)
                      : AppColors.resolve(
                          AppColors.accentLight, AppDarkColors.accentLight),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              )),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.livreur_stats,
                style: AppTypography.titleMedium(
                    color:
                        AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.resolve(
                          AppColors.brandSurface, AppDarkColors.brandSurface),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.delivery_dining_rounded,
                            color: AppColors.brand, size: 32),
                        const SizedBox(height: 8),
                        Text('$_totalLivraisons',
                            style: AppTypography.titleLarge(
                                    color: AppColors.resolve(
                                        AppColors.ink, AppDarkColors.ink))
                                .copyWith(color: AppColors.brand)),
                        const SizedBox(height: 2),
                        Text(l10n.myDeliveries,
                            style: AppTypography.bodyMedium(
                                    color: AppColors.resolve(
                                        AppColors.ink, AppDarkColors.ink))
                                .copyWith(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.resolve(
                          AppColors.successLight, AppDarkColors.successLight),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.monetization_on_rounded,
                            color: AppColors.success, size: 32),
                        const SizedBox(height: 8),
                        Text('${_totalGains.toStringAsFixed(0)} CFA',
                            style: AppTypography.titleLarge(
                                    color: AppColors.resolve(
                                        AppColors.ink, AppDarkColors.ink))
                                .copyWith(color: AppColors.success)),
                        const SizedBox(height: 2),
                        Text(l10n.store_my_earnings,
                            style: AppTypography.bodyMedium(
                                    color: AppColors.resolve(
                                        AppColors.ink, AppDarkColors.ink))
                                .copyWith(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsSection(Users livreur) {
    final l10n = AppLocalizations.of(context)!;
    final identityUrl = _identity?.piece_identite ?? '';
    final permisUrl = ''; // Placeholder – set from data if available

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.livreur_documents,
                style: AppTypography.titleMedium(
                    color:
                        AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
            const SizedBox(height: 16),
            _buildDocumentTile(
              title: l10n.livreur_license,
              url: permisUrl,
              verified: livreur.permisVerified,
              type: 'permis',
            ),
            const SizedBox(height: 12),
            _buildDocumentTile(
              title: l10n.livreur_id_card,
              url: identityUrl,
              verified: livreur.identity == 'Verified',
              type: 'identity',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentTile({
    required String title,
    required String url,
    required bool verified,
    required String type,
  }) {
    final hasUrl = url.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: verified
                  ? AppColors.resolve(
                      AppColors.successLight, AppDarkColors.successLight)
                  : hasUrl
                      ? AppColors.resolve(
                          AppColors.brandSurface, AppDarkColors.brandSurface)
                      : AppColors.resolve(
                          AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Center(
              child: Icon(
                verified
                    ? Icons.check_circle_rounded
                    : hasUrl
                        ? Icons.description_rounded
                        : Icons.cloud_off_rounded,
                color: verified
                    ? AppColors.success
                    : hasUrl
                        ? AppColors.brand
                        : AppColors.inkSubtle,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.labelLarge(
                        color: AppColors.resolve(
                            AppColors.ink, AppDarkColors.ink))),
                const SizedBox(height: 2),
                Text(
                  verified
                      ? AppLocalizations.of(context)!.livreur_validated
                      : hasUrl
                          ? AppLocalizations.of(context)!.livreur_pending
                          : AppLocalizations.of(context)!.livreur_not_provided,
                  style: AppTypography.bodyMedium(
                          color: AppColors.resolve(
                              AppColors.ink, AppDarkColors.ink))
                      .copyWith(
                    fontSize: 12,
                    color: verified
                        ? AppColors.success
                        : hasUrl
                            ? AppColors.accent
                            : AppColors.inkSubtle,
                  ),
                ),
              ],
            ),
          ),
          if (hasUrl)
            IconButton(
              icon: const Icon(Icons.remove_red_eye_outlined),
              color: AppColors.brand,
              onPressed: () => _handleFilePreview(url),
            ),
        ],
      ),
    );
  }

  Widget _buildValidationActions(Users livreur) {
    final l10n = AppLocalizations.of(context)!;
    final permisOk = livreur.permisVerified == true;
    final identityOk = livreur.identity == 'Verified';
    final identityPending = !identityOk && livreur.identity != 'Rejected';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.livreur_validation_actions,
                style: AppTypography.titleMedium(
                    color:
                        AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
            const SizedBox(height: 16),
            if (!permisOk) ...[
              Text(l10n.livreur_license,
                  style: AppTypography.labelLarge(
                      color:
                          AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text('${l10n.validate} ${l10n.livreur_license}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () =>
                          _showValidateDialog('permis', l10n.livreur_license),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: Text(l10n.reject),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => _showRejectDialog('permis'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (identityPending) ...[
              Text(l10n.livreur_id_card,
                  style: AppTypography.labelLarge(
                      color:
                          AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text('${l10n.validate} ${l10n.livreur_id_card}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () =>
                          _showValidateDialog('identity', l10n.livreur_id_card),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: Text(l10n.reject),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => _showRejectDialog('identity'),
                    ),
                  ),
                ],
              ),
            ],
            if (!identityPending && identityOk)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.resolve(
                      AppColors.successLight, AppDarkColors.successLight),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(children: [
                  Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 20),
                  const SizedBox(width: 8),
                  Text('${l10n.livreur_id_card} ${l10n.livreur_validated}',
                      style:
                          AppTypography.labelMedium(color: AppColors.success)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class _PDFViewerScreen extends StatelessWidget {
  final String fileUrl;
  const _PDFViewerScreen({required this.fileUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(AppLocalizations.of(context)!.livreur_documents)),
      body: SfPdfViewer.network(fileUrl),
    );
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  const _FullScreenImageViewer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(AppLocalizations.of(context)!.livreur_documents)),
      body: Center(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          placeholder: (_, __) => const CircularProgressIndicator(),
          errorWidget: (_, __, ___) => const Icon(Icons.error),
        ),
      ),
    );
  }
}
