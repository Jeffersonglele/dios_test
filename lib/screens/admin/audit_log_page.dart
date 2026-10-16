import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:dios_delices/services/node_admin_service.dart';
import 'package:dios_delices/services/session_service.dart';

class AuditLogPage extends StatefulWidget {
  final String country;
  const AuditLogPage({super.key, required this.country});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  List<Map<String, dynamic>> _logs = [];

  /// Libellé lisible des actions enregistrées par le serveur.
  static String _actionLabel(String action) {
    const labels = {
      'restaurant:approved': 'Restaurant validé',
      'restaurant:rejected': 'Restaurant refusé',
      'restaurant:pending': 'Restaurant remis en attente',
      'pro_document:approved': 'Demande Pro validée',
      'pro_document:rejected': 'Demande Pro refusée',
      'courier_file:approved': 'Dossier livreur validé',
      'courier_file:rejected': 'Dossier livreur refusé',
      'user:identity': 'Identité modifiée',
      'user:profile': 'Profil modifié',
      'user:deleted': 'Compte supprimé',
      'admin:created': 'Administrateur créé',
      'email:sent': 'Email envoyé',
    };
    return labels[action] ?? action;
  }
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      // Le serveur limite le journal au pays de l'admin (tous pour le super admin).
      final token = await SessionService.readNodeToken();
      if (token != null) {
        final logs = await NodeAdminService.getAuditLogs(token);
        if (mounted) setState(() => _logs = logs);
      }
    } catch (e, st) {
      debugPrint('[AuditLogPage] Exception while loading: $e');
      debugPrintStack(stackTrace: st);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      appBar: AppBar(
        title:
            Text(AppLocalizations.of(context)!.audit_log_title(widget.country),
                style: AppTypography.titleMedium(
                  color: AppColors.resolve(AppColors.ink, AppDarkColors.ink),
                )),
      ),
      body: RefreshIndicator(
        color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _logs.isEmpty
                ? ListView(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history_rounded,
                                  size: 64,
                                  color: AppColors.resolve(
                                      AppColors.border, AppDarkColors.border)),
                              const SizedBox(height: 16),
                              Text(
                                  AppLocalizations.of(context)!.audit_log_empty,
                                  style: AppTypography.bodyMedium(
                                    color: AppColors.resolve(
                                        AppColors.ink, AppDarkColors.ink),
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _logs.length,
                    itemBuilder: (_, i) {
                      final log = _logs[i];
                      final action = log['action']?.toString() ?? '';
                      final details = log['details']?.toString() ?? '';
                      final userName = log['userName']?.toString() ?? '';
                      final date =
                          DateTime.tryParse('${log['createdAt']}')?.toLocal();
                      final dateStr = date != null
                          ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
                          : '';

                      IconData icon;
                      Color iconColor;
                      if (action.contains('rejected')) {
                        icon = Icons.block_rounded;
                        iconColor = AppColors.resolve(
                            AppColors.error, AppDarkColors.error);
                      } else if (action.contains('approved')) {
                        icon = Icons.verified_rounded;
                        iconColor = AppColors.resolve(
                            AppColors.success, AppDarkColors.success);
                      } else if (action.toLowerCase().contains('suppr') ||
                          action.toLowerCase().contains('delete')) {
                        icon = Icons.delete_rounded;
                        iconColor = AppColors.resolve(
                            AppColors.error, AppDarkColors.error);
                      } else if (action.toLowerCase().contains('create') ||
                          action.toLowerCase().contains('ajout')) {
                        icon = Icons.add_circle_rounded;
                        iconColor = AppColors.resolve(
                            AppColors.success, AppDarkColors.success);
                      } else if (action.toLowerCase().contains('update') ||
                          action.toLowerCase().contains('modif')) {
                        icon = Icons.edit_rounded;
                        iconColor = AppColors.resolve(
                            AppColors.accent, AppDarkColors.accent);
                      } else if (action.toLowerCase().contains('login') ||
                          action.toLowerCase().contains('connexion')) {
                        icon = Icons.login_rounded;
                        iconColor = AppColors.resolve(
                            AppColors.brand, AppDarkColors.brand);
                      } else {
                        icon = Icons.info_rounded;
                        iconColor = AppColors.resolve(
                            AppColors.inkMuted, AppDarkColors.inkMuted);
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.resolve(
                              AppColors.card, AppDarkColors.card),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(
                              color: AppColors.resolve(
                                  AppColors.border, AppDarkColors.border),
                              width: 0.5),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: iconColor.withOpacity(0.12),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm),
                              ),
                              child: Icon(icon, color: iconColor, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_actionLabel(action),
                                      style: AppTypography.bodyLarge(
                                        color: AppColors.resolve(
                                            AppColors.ink, AppDarkColors.ink),
                                      ).copyWith(fontSize: 14)),
                                  if (details.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(details,
                                          style: AppTypography.bodyMedium(
                                            color: AppColors.resolve(
                                                AppColors.ink,
                                                AppDarkColors.ink),
                                          ).copyWith(fontSize: 12)),
                                    ),
                                  if (userName.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Row(children: [
                                        Icon(Icons.person_rounded,
                                            size: 12,
                                            color: AppColors.resolve(
                                                AppColors.inkSubtle,
                                                AppDarkColors.inkSubtle)),
                                        const SizedBox(width: 4),
                                        Text(userName,
                                            style: AppTypography.bodyMedium(
                                              color: AppColors.resolve(
                                                  AppColors.ink,
                                                  AppDarkColors.ink),
                                            ).copyWith(fontSize: 11)),
                                      ]),
                                    ),
                                ],
                              ),
                            ),
                            if (dateStr.isNotEmpty)
                              Text(dateStr,
                                  style: AppTypography.bodyMedium(
                                    color: AppColors.resolve(
                                        AppColors.ink, AppDarkColors.ink),
                                  ).copyWith(
                                      fontSize: 10,
                                      color: AppColors.resolve(
                                          AppColors.inkSubtle,
                                          AppDarkColors.inkSubtle))),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
