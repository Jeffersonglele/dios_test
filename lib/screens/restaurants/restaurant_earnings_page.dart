import 'package:fl_chart/fl_chart.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/currency_util.dart';
import 'package:flutter/material.dart';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class RestaurantEarningsPage extends StatefulWidget {
  const RestaurantEarningsPage({super.key});

  @override
  State<RestaurantEarningsPage> createState() => _RestaurantEarningsPageState();
}

class _RestaurantEarningsPageState extends State<RestaurantEarningsPage> {
  int _totalOrders = 0;
  double _totalRevenue = 0;
  String _period = 'week';
  bool _isLoading = true;
  List<_DailyPoint> _dailyData = [];
  String _country = 'France';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final session = await SessionService.readSession();
      _country = session.country;
      final restauID = session.restaurantId;
      if (restauID == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final fn = ParseCloudFunction('getRestaurantEarnings');
      final response = await fn.execute(parameters: {
        'restauID': restauID,
        'period': _period,
      });
      if (mounted && response.success && response.result != null) {
        final data = response.result as Map<String, dynamic>;
        final raw = (data['dailyData'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        setState(() {
          _totalOrders = (data['totalOrders'] as num?)?.toInt() ?? 0;
          _totalRevenue = (data['totalRevenue'] as num?)?.toDouble() ?? 0;
          _dailyData = raw.map((m) => _DailyPoint(
            date: m['date']?.toString() ?? '',
            gains: (m['gains'] as num?)?.toDouble() ?? 0,
            deliveries: (m['deliveries'] as num?)?.toInt() ?? 0,
          )).toList();
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setPeriod(String p) {
    setState(() => _period = p);
    _load();
  }

  String _shortDate(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    return '${parts[1]}/${parts[2]}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final periodLabel = _period == 'today' ? l10n.delivery_today : _period == 'week' ? l10n.delivery_this_week : l10n.delivery_this_month;
    final hasData = _dailyData.any((d) => d.gains > 0);
    return Scaffold(
      backgroundColor: AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      appBar: AppBar(
        title: Text(l10n.store_my_earnings),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.resolve(AppColors.card, AppDarkColors.card),
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(
                        color: AppColors.resolve(AppColors.border, AppDarkColors.border),
                      ),
                      boxShadow: [AppShadows.subtle],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: Icon(Icons.insights_rounded,
                                  color: AppColors.resolve(AppColors.brand, AppDarkColors.brand)),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.delivery_earnings(periodLabel),
                                    style: AppTypography.titleSmall(
                                        color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _StatColumn(
                                icon: Icons.receipt_long_rounded,
                                label: 'Commandes',
                                value: '$_totalOrders',
                                valueColor: AppColors.resolve(AppColors.ink, AppDarkColors.ink),
                                labelColor: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 56,
                              color: AppColors.resolve(AppColors.border, AppDarkColors.border),
                            ),
                            Expanded(
                              child: _StatColumn(
                                icon: Icons.payments_rounded,
                                label: 'Revenus',
                                value: CurrencyUtil.formatPrice(_totalRevenue, _country),
                                valueColor: AppColors.resolve(AppColors.ink, AppDarkColors.ink),
                                labelColor: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(l10n.delivery_evolution,
                      style: AppTypography.titleLarge(
                          color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: _PeriodChip('today', l10n.delivery_today)),
                        const SizedBox(width: 4),
                        Expanded(child: _PeriodChip('week', l10n.delivery_this_week)),
                        const SizedBox(width: 4),
                        Expanded(child: _PeriodChip('month', l10n.delivery_this_month)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ── Graphique ─────────────────────────────
                  if (hasData)
                    SizedBox(
                      height: 220,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16, left: 8),
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: _dailyData.map((d) => d.gains).reduce((a, b) => a > b ? a : b) * 1.3,
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  final p = _dailyData[groupIndex];
                                  return BarTooltipItem(
                                    '${p.date}\n${CurrencyUtil.formatPrice(p.gains, _country)}',
                                    const TextStyle(color: Colors.white, fontSize: 12),
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (val, meta) {
                                    final i = val.toInt();
                                    if (i < 0 || i >= _dailyData.length) return const SizedBox();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(_shortDate(_dailyData[i].date),
                                          style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(
                              show: true,
                              horizontalInterval: _dailyData.map((d) => d.gains).reduce((a, b) => a > b ? a : b) / 4,
                              getDrawingHorizontalLine: (val) => FlLine(
                                color: AppColors.border,
                                strokeWidth: 0.5,
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: _dailyData.asMap().entries.map((entry) {
                              return BarChartGroupData(
                                x: entry.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: entry.value.gains,
                                    color: AppColors.brand,
                                    width: _dailyData.length > 10 ? 8 : 16,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  if (!hasData)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                      decoration: BoxDecoration(
                        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(
                          color: AppColors.resolve(AppColors.border, AppDarkColors.border),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.bar_chart_rounded,
                                size: 30,
                                color: AppColors.resolve(AppColors.brand, AppDarkColors.brand)),
                          ),
                          const SizedBox(height: 16),
                          Text(l10n.delivery_no_data,
                              textAlign: TextAlign.center,
                              style: AppTypography.titleSmall(
                                  color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _PeriodChip(String value, String label) {
    final selected = _period == value;
    return GestureDetector(
      onTap: () => _setPeriod(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.resolve(AppColors.brand, AppDarkColors.brand)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected
                ? Colors.white
                : AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  final Color labelColor;

  const _StatColumn({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.brand),
        const SizedBox(height: 6),
        Text(value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleMedium(color: valueColor)
                .copyWith(fontSize: 22)),
        const SizedBox(height: 4),
        Text(label, style: AppTypography.bodyMedium(color: labelColor)),
      ],
    );
  }
}

class _DailyPoint {
  final String date;
  final double gains;
  final int deliveries;
  const _DailyPoint({required this.date, required this.gains, required this.deliveries});
}
