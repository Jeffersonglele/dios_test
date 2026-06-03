import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class AuditLogPage extends StatefulWidget {
  final String country;
  const AuditLogPage({super.key, required this.country});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  List<ParseObject> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final q = QueryBuilder<ParseObject>(ParseObject('AuditLog'))
        ..whereEqualTo('country', widget.country)
        ..orderByDescending('createdAt')
        ..setLimit(200);

      final resp = await q.query();
      if (resp.success && resp.results != null && mounted) {
        setState(() => _logs = resp.results!.cast<ParseObject>());
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      appBar: AppBar(
        title: Text('Audit Log — ${widget.country}',
            style: AppTypography.titleMedium()),
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
                              Text('Aucun log pour ce pays.',
                                  style: AppTypography.bodyMedium()),
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
                      final action = log.get<String>('action') ?? '';
                      final details = log.get<String>('details') ?? '';
                      final userName = log.get<String>('userName') ?? '';
                      final date = log.createdAt;
                      final dateStr = date != null
                          ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
                          : '';

                      IconData icon;
                      Color iconColor;
                      if (action.toLowerCase().contains('suppr') || action.toLowerCase().contains('delete')) {
                        icon = Icons.delete_rounded;
                        iconColor = AppColors.resolve(AppColors.error, AppDarkColors.error);
                      } else if (action.toLowerCase().contains('create') || action.toLowerCase().contains('ajout')) {
                        icon = Icons.add_circle_rounded;
                        iconColor = AppColors.resolve(AppColors.success, AppDarkColors.success);
                      } else if (action.toLowerCase().contains('update') || action.toLowerCase().contains('modif')) {
                        icon = Icons.edit_rounded;
                        iconColor = AppColors.resolve(AppColors.accent, AppDarkColors.accent);
                      } else if (action.toLowerCase().contains('login') || action.toLowerCase().contains('connexion')) {
                        icon = Icons.login_rounded;
                        iconColor = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
                      } else {
                        icon = Icons.info_rounded;
                        iconColor = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.resolve(AppColors.card, AppDarkColors.card),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(
                              color: AppColors.resolve(AppColors.border, AppDarkColors.border),
                              width: 0.5),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                              ),
                              child: Icon(icon, color: iconColor, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(action,
                                      style: AppTypography.bodyLarge().copyWith(fontSize: 14)),
                                  if (details.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(details,
                                          style: AppTypography.bodyMedium().copyWith(fontSize: 12)),
                                    ),
                                  if (userName.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Row(children: [
                                        Icon(Icons.person_rounded, size: 12,
                                            color: AppColors.resolve(
                                                AppColors.inkSubtle, AppDarkColors.inkSubtle)),
                                        const SizedBox(width: 4),
                                        Text(userName,
                                            style: AppTypography.bodyMedium().copyWith(fontSize: 11)),
                                      ]),
                                    ),
                                ],
                              ),
                            ),
                            if (dateStr.isNotEmpty)
                              Text(dateStr,
                                  style: AppTypography.bodyMedium().copyWith(
                                      fontSize: 10,
                                      color: AppColors.resolve(
                                          AppColors.inkSubtle, AppDarkColors.inkSubtle))),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
