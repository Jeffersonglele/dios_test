import 'package:fl_chart/fl_chart.dart';
import 'package:dios_delices/services/livreur_api.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/currency_util.dart';
import 'package:flutter/material.dart';
import 'package:dios_delices/l10n/app_localizations.dart';

class LivreurEarningsPage extends StatefulWidget {
  const LivreurEarningsPage({super.key});

  @override
  State<LivreurEarningsPage> createState() => _LivreurEarningsPageState();
}

class _LivreurEarningsPageState extends State<LivreurEarningsPage> {
  int _totalDeliveries = 0;
  double _totalGains = 0;
  String _period = 'week';
  bool _isLoading = true;
  List<_DailyPoint> _dailyData = [];
  String _country = 'RDC';

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
      final result = await LivreurApi.getLivreurEarnings(session.userId, period: _period);
      if (mounted) {
        final raw = (result['dailyData'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        setState(() {
          _totalDeliveries = (result['totalLivraisons'] as num?)?.toInt() ?? 0;
          _totalGains = (result['totalGains'] as num?)?.toDouble() ?? 0;
          _dailyData = raw.map((m) => _DailyPoint(
            date: m['date']?.toString() ?? '',
            gains: (m['gains'] as num?)?.toDouble() ?? 0,
            deliveries: (m['deliveries'] as num?)?.toInt() ?? 0,
          )).toList();
          _isLoading = false;
        });
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
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.resolve(AppColors.card, AppDarkColors.card),
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      boxShadow: [AppShadows.subtle],
                    ),
                    child: Column(
                      children: [
                        Text(l10n.delivery_earnings(periodLabel),
                            style: AppTypography.bodyMedium(color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted))),
                        const SizedBox(height: 8),
                        Text(CurrencyUtil.formatPrice(_totalGains, _country),
                            style: AppTypography.headlineLarge(color: AppColors.brand).copyWith(fontSize: 40)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delivery_dining_rounded, size: 16, color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted)),
                            const SizedBox(width: 6),
                            Text('$_totalDeliveries ${l10n.myDeliveries}',
                                style: AppTypography.bodyMedium(color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _PeriodButton(label: l10n.delivery_today, period: 'today', selected: _period == 'today', onTap: () => _setPeriod('today')),
                        const SizedBox(width: 8),
                        _PeriodButton(label: l10n.delivery_period_7days, period: 'week', selected: _period == 'week', onTap: () => _setPeriod('week')),
                        const SizedBox(width: 8),
                        _PeriodButton(label: l10n.delivery_period_30days, period: 'month', selected: _period == 'month', onTap: () => _setPeriod('month')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_dailyData.isNotEmpty && hasData)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                      decoration: BoxDecoration(
                        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        boxShadow: [AppShadows.subtle],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.delivery_evolution,
                              style: AppTypography.titleMedium(color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 200,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: _dailyData.map((d) => d.gains).reduce((a, b) => a > b ? a : b) * 1.3,
                                barTouchData: BarTouchData(
                                  touchTooltipData: BarTouchTooltipData(
                                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                      final p = _dailyData[group.x.toInt()];
                                      return BarTooltipItem(
                                        '${p.date}\n${CurrencyUtil.formatPrice(p.gains, _country)}',
                                        TextStyle(color: AppColors.brand, fontWeight: FontWeight.w700, fontSize: 12),
                                      );
                                    },
                                  ),
                                ),
                                titlesData: FlTitlesData(
                                  show: true,
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      getTitlesWidget: (value, meta) => Text(
                                        '${value.toInt()}',
                                        style: TextStyle(fontSize: 10, color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted)),
                                      ),
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 28,
                                      interval: _period == 'month' ? 4 : 1,
                                      getTitlesWidget: (value, meta) {
                                        final i = value.toInt();
                                        if (i < 0 || i >= _dailyData.length) return const SizedBox.shrink();
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            _shortDate(_dailyData[i].date),
                                            style: TextStyle(fontSize: 9, color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted)),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                gridData: FlGridData(
                                  show: true,
                                  horizontalInterval: _dailyData.map((d) => d.gains).reduce((a, b) => a > b ? a : b) / 4,
                                  getDrawingHorizontalLine: (value) => FlLine(
                                    color: AppColors.resolve(AppColors.border, AppDarkColors.border).withValues(alpha: 0.3),
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
                                        width: _period == 'month' ? 6 : 14,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!hasData && _dailyData.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.bar_chart_rounded, size: 48, color: AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle)),
                          const SizedBox(height: 12),
                          Text(l10n.delivery_no_data,
                              style: AppTypography.bodyMedium(color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _DailyPoint {
  final String date;
  final double gains;
  final int deliveries;
  const _DailyPoint({required this.date, required this.gains, required this.deliveries});
}

class _PeriodButton extends StatelessWidget {
  final String label;
  final String period;
  final bool selected;
  final VoidCallback onTap;
  const _PeriodButton({required this.label, required this.period, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.brand : AppColors.resolve(AppColors.card, AppDarkColors.card),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.resolve(AppColors.border, AppDarkColors.border),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.labelMedium(
              color: selected ? Colors.white : AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted),
            ),
          ),
        ),
      ),
    );
  }
}
