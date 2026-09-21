import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class SuperAdminDashboard extends StatefulWidget {
  final String? country;
  const SuperAdminDashboard({super.key, this.country});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard>
    with SingleTickerProviderStateMixin {
  double _weeklyCommissions = 0.0;
  int _paymentsCompleted = 0;
  int _paymentsPending = 0;
  int _disputesOpen = 0;
  int _disputesInProgress = 0;
  int _disputesResolved = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final fnStats = ParseCloudFunction('getSuperAdminDashboardStats');
      final resStats = await fnStats.execute(parameters: {
        if (widget.country != null && widget.country!.isNotEmpty)
          'country': widget.country,
      });

      if (resStats.success && resStats.result != null) {
        final data = resStats.result as Map<String, dynamic>;
        if (data['success'] == true && data['stats'] != null) {
          final stats = data['stats'] as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _weeklyCommissions =
                  (stats['weeklyCommissions'] as num?)?.toDouble() ?? 0.0;
              _paymentsCompleted =
                  (stats['paymentsCompleted'] as num?)?.toInt() ?? 0;
              _paymentsPending =
                  (stats['paymentsPending'] as num?)?.toInt() ?? 0;
              _disputesOpen = (stats['disputesOpen'] as num?)?.toInt() ?? 0;
              _disputesInProgress =
                  (stats['disputesInProgress'] as num?)?.toInt() ?? 0;
              _disputesResolved =
                  (stats['disputesResolved'] as num?)?.toInt() ?? 0;
              _loading = false;
            });
            return;
          }
        }
      }

      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final totalDisputes =
        _disputesOpen + _disputesInProgress + _disputesResolved;
    final disputeRate = totalDisputes > 0
        ? ((_disputesOpen + _disputesInProgress) / totalDisputes * 100)
        : 0.0;

    return Scaffold(
      backgroundColor:
          AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      appBar: AppBar(
        title: Text(l10n.superAdminDashboard ?? 'Super Admin Dashboard',
            style: AppTypography.titleSmall(
              color: AppColors.resolve(AppColors.ink, AppDarkColors.ink),
            )),
        backgroundColor:
            AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brand))
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Stats Grid
                  _StatsCard(
                    title: l10n.superAdminWeeklyCommissions ??
                        'Commissions hebdomadaires',
                    value: '\$${_weeklyCommissions.toStringAsFixed(2)}',
                    color: AppColors.brand,
                    icon: Icons.attach_money,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatsCard(
                          title: l10n.superAdminPaymentsCompleted ??
                              'Versements effectués',
                          value: _paymentsCompleted.toString(),
                          color: AppColors.success,
                          icon: Icons.check_circle,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatsCard(
                          title: l10n.superAdminPaymentsPending ??
                              'Versements en attente',
                          value: _paymentsPending.toString(),
                          color: AppColors.accent,
                          icon: Icons.pending_actions,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatsCard(
                          title:
                              l10n.superAdminDisputesOpen ?? 'Litiges ouverts',
                          value: _disputesOpen.toString(),
                          color: AppColors.error,
                          icon: Icons.report,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatsCard(
                          title: l10n.superAdminDisputesInProgress ??
                              'Litiges en cours',
                          value: _disputesInProgress.toString(),
                          color: AppColors.error ?? AppColors.accent,
                          icon: Icons.timelapse,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatsCard(
                          title: l10n.superAdminDisputesResolved ??
                              'Litiges résolus',
                          value: _disputesResolved.toString(),
                          color: AppColors.success,
                          icon: Icons.done_all,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _StatsCard(
                    title: l10n.superAdminDisputeRate ?? 'Taux de litige',
                    value: '${disputeRate.toStringAsFixed(1)}%',
                    color: AppColors.accent,
                    icon: Icons.bar_chart,
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _StatsCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: AppColors.resolve(AppColors.border, AppDarkColors.border),
            width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppTypography.labelMedium(
              color: AppColors.resolve(
                  AppColors.inkSubtle, AppDarkColors.inkSubtle),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.titleMedium(
              color: AppColors.resolve(AppColors.ink, AppDarkColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
