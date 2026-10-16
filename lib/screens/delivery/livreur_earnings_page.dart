import 'package:fl_chart/fl_chart.dart';
import 'package:dios_delices/services/livreur_api.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:dios_delices/l10n/app_localizations.dart';

/// Gains du livreur sur ses courses livrées (frais de livraison + pourboires),
/// par période : aujourd'hui, 7 jours, 30 jours ou dates choisies.
class LivreurEarningsPage extends StatefulWidget {
  const LivreurEarningsPage({super.key});

  @override
  State<LivreurEarningsPage> createState() => _LivreurEarningsPageState();
}

enum _Period { today, week, month, custom }

class _Day {
  const _Day(this.date, this.gains, this.deliveries);
  final DateTime date;
  final double gains;
  final int deliveries;
}

class _Ride {
  _Ride(Map<String, dynamic> m)
      : orderId = int.tryParse('${m['orderId']}') ?? 0,
        deliveredAt = DateTime.tryParse('${m['deliveredAt']}')?.toLocal(),
        restaurant = m['restaurantName']?.toString(),
        fee = double.tryParse('${m['deliveryFee']}') ?? 0,
        tip = double.tryParse('${m['tip']}') ?? 0,
        payment = m['paymentMethod']?.toString().toUpperCase() ?? '',
        distanceKm = double.tryParse('${m['distanceKm']}');
  final int orderId;
  final DateTime? deliveredAt;
  final String? restaurant;
  final double fee;
  final double tip;
  final String payment;
  final double? distanceKm;
}

class _LivreurEarningsPageState extends State<LivreurEarningsPage> {
  _Period _period = _Period.week;
  DateTimeRange? _customRange;
  bool _isLoading = true;
  String? _error;

  String _currency = 'XOF';
  int _deliveries = 0;
  double _total = 0;
  double _fees = 0;
  double _tips = 0;
  double _average = 0;
  double _cashOnHand = 0;
  List<_Day> _days = [];
  List<_Ride> _rides = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _apiPeriod => switch (_period) {
        _Period.today => 'today',
        _Period.week => 'week',
        _Period.month => 'month',
        _Period.custom => 'custom',
      };

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final range = _customRange;
    final result = await LivreurApi.getLivreurEarnings(
      0,
      period: _apiPeriod,
      startDate: _period == _Period.custom ? range?.start : null,
      endDate: _period == _Period.custom ? range?.end : null,
    );
    if (!mounted) return;
    if (result['success'] == false) {
      setState(() {
        _isLoading = false;
        _error = AppLocalizations.of(context)!.earnings_load_error;
      });
      return;
    }
    double n(Object? v) => double.tryParse('${v ?? ''}') ?? 0;
    setState(() {
      _currency = result['currency']?.toString() ?? _currency;
      _deliveries = n(result['totalLivraisons']).toInt();
      _total = n(result['totalGains']);
      _fees = n(result['totalDeliveryFees']);
      _tips = n(result['totalPourboires']);
      _average = n(result['averagePerDelivery']);
      _cashOnHand = n(result['cashOnHand']);
      _days = ((result['dailyData'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => _Day(
                DateTime.tryParse('${m['date']}') ?? DateTime.now(),
                n(m['gains']),
                n(m['deliveries']).toInt(),
              ))
          .toList();
      _rides = ((result['deliveries'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => _Ride(Map<String, dynamic>.from(m)))
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1, now.month, now.day),
      lastDate: now,
      initialDateRange: _customRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
      helpText: AppLocalizations.of(context)!.earnings_pick_dates,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customRange = picked;
      _period = _Period.custom;
    });
    _load();
  }

  void _select(_Period p) {
    if (p == _Period.custom) {
      _pickRange();
      return;
    }
    if (p == _period) return;
    setState(() => _period = p);
    _load();
  }

  String _money(double v) {
    final s = v.round().toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');
    return '$s ${_currency == 'XOF' ? 'FCFA' : _currency}';
  }

  String _dayLabel(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  String _periodTitle(AppLocalizations l10n) {
    final r = _customRange;
    return switch (_period) {
      _Period.today => l10n.earnings_title_today,
      _Period.week => l10n.earnings_title_week,
      _Period.month => l10n.earnings_title_month,
      _Period.custom => r == null
          ? l10n.earnings_pick_dates
          : l10n.earnings_title_range(_dayLabel(r.start), _dayLabel(r.end)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final surface = AppColors.resolve(AppColors.surface, AppDarkColors.surface);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: surface,
        title: Text(l10n.store_my_earnings,
            style: AppTypography.titleSmall(color: ink)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            _PeriodBar(
              selected: _period,
              customLabel: _customRange == null
                  ? l10n.earnings_period_custom
                  : '${_dayLabel(_customRange!.start)} – ${_dayLabel(_customRange!.end)}',
              onSelect: _select,
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _Message(icon: Icons.cloud_off_rounded, text: _error!)
            else ...[
              _HeroCard(
                title: _periodTitle(l10n),
                amount: _money(_total),
                deliveries: _deliveries,
                l10n: l10n,
              ),
              const SizedBox(height: 12),
              Row(children: [
                _Kpi(
                    icon: Icons.two_wheeler_rounded,
                    label: l10n.earnings_kpi_fees,
                    value: _money(_fees)),
                const SizedBox(width: 10),
                _Kpi(
                    icon: Icons.volunteer_activism_outlined,
                    label: l10n.earnings_kpi_tips,
                    value: _money(_tips)),
                const SizedBox(width: 10),
                _Kpi(
                    icon: Icons.functions_rounded,
                    label: l10n.earnings_kpi_average,
                    value: _money(_average)),
              ]),
              if (_cashOnHand > 0) ...[
                const SizedBox(height: 12),
                _CashCard(amount: _money(_cashOnHand), l10n: l10n),
              ],
              const SizedBox(height: 20),
              if (_deliveries == 0)
                _Message(
                    icon: Icons.inbox_rounded, text: l10n.earnings_empty)
              else ...[
                if (_days.length > 1) ...[
                  _SectionTitle(l10n.earnings_chart_title),
                  _Chart(days: _days, money: _money),
                  const SizedBox(height: 20),
                ],
                _SectionTitle(l10n.earnings_rides_title(_rides.length)),
                for (final ride in _rides) ...[
                  _RideTile(ride: ride, money: _money),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PeriodBar extends StatelessWidget {
  const _PeriodBar({
    required this.selected,
    required this.customLabel,
    required this.onSelect,
  });
  final _Period selected;
  final String customLabel;
  final ValueChanged<_Period> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = [
      (_Period.today, l10n.delivery_today, null),
      (_Period.week, l10n.delivery_period_7days, null),
      (_Period.month, l10n.delivery_period_30days, null),
      (_Period.custom, customLabel, Icons.event_rounded),
    ];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (period, label, icon) = items[i];
          final active = period == selected;
          final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
          final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
          final border =
              AppColors.resolve(AppColors.border, AppDarkColors.border);
          final muted =
              AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
          return Material(
            color: active ? brand : card,
            borderRadius: BorderRadius.circular(99),
            child: InkWell(
              borderRadius: BorderRadius.circular(99),
              onTap: () => onSelect(period),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: active ? brand : border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: active ? Colors.white : muted),
                    const SizedBox(width: 6),
                  ],
                  Text(label,
                      style: AppTypography.labelMedium(
                              color: active ? Colors.white : muted)
                          .copyWith(
                              fontWeight:
                                  active ? FontWeight.w800 : FontWeight.w600)),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.amount,
    required this.deliveries,
    required this.l10n,
  });
  final String title;
  final String amount;
  final int deliveries;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final deep = Color.lerp(brand, Colors.black, 0.25)!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [brand, deep],
        ),
        boxShadow: [
          BoxShadow(
            color: brand.withValues(alpha: 0.28),
            blurRadius: 22,
            spreadRadius: -4,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppTypography.labelMedium(
                      color: Colors.white.withValues(alpha: 0.9))
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(amount,
                style: AppTypography.headlineLarge(color: Colors.white)
                    .copyWith(fontSize: 34)),
          ),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(l10n.earnings_deliveries_count(deliveries),
                style: AppTypography.bodyMedium(
                    color: Colors.white.withValues(alpha: 0.92))),
          ]),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: border, width: 0.6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: brand),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: AppTypography.labelLarge(color: ink)
                      .copyWith(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall(color: muted)
                    .copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _CashCard extends StatelessWidget {
  const _CashCard({required this.amount, required this.l10n});
  final String amount;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.resolve(AppColors.accent, AppDarkColors.accent);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(Icons.account_balance_wallet_rounded, color: accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.earnings_cash_title(amount),
                  style: AppTypography.labelLarge(color: ink)
                      .copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(l10n.earnings_cash_body,
                  style: AppTypography.bodySmall(color: muted)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 2),
        child: Text(text.toUpperCase(),
            style: AppTypography.labelMedium(
                    color: AppColors.resolve(
                        AppColors.inkMuted, AppDarkColors.inkMuted))
                .copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.8)),
      );
}

class _Chart extends StatelessWidget {
  const _Chart({required this.days, required this.money});
  final List<_Day> days;
  final String Function(double) money;

  @override
  Widget build(BuildContext context) {
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final maxGain = days.fold<double>(0, (m, d) => d.gains > m ? d.gains : m);
    // Une étiquette de date sur ~6 pour rester lisible.
    final step = (days.length / 6).ceil().clamp(1, 31);
    return Container(
      height: 210,
      padding: const EdgeInsets.fromLTRB(8, 16, 12, 8),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border, width: 0.6),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxGain <= 0 ? 1 : maxGain * 1.25,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, __, ___) {
                final d = days[group.x];
                return BarTooltipItem(
                  '${d.date.day.toString().padLeft(2, '0')}/${d.date.month.toString().padLeft(2, '0')}\n${money(d.gains)}',
                  const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= days.length) return const SizedBox.shrink();
                  if (i % step != 0 && i != days.length - 1) {
                    return const SizedBox.shrink();
                  }
                  final d = days[i].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 10, color: muted)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < days.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: days[i].gains,
                  color: days[i].gains > 0
                      ? brand
                      : border.withValues(alpha: 0.6),
                  width: days.length > 14 ? 6 : 14,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

class _RideTile extends StatelessWidget {
  const _RideTile({required this.ride, required this.money});
  final _Ride ride;
  final String Function(double) money;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final success = AppColors.resolve(AppColors.success, AppDarkColors.success);
    final d = ride.deliveredAt;
    final when = d == null
        ? ''
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final payment = switch (ride.payment) {
      'CASH' => l10n.earnings_payment_cash,
      'NYOLE' => l10n.earnings_payment_mobile,
      'WALLET' => l10n.earnings_payment_wallet,
      _ => '',
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: border, width: 0.6),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: brand.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.storefront_rounded, color: brand, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ride.restaurant ?? '#${ride.orderId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLarge(color: ink)
                      .copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                [
                  when,
                  if (ride.distanceKm != null && ride.distanceKm! > 0)
                    '${ride.distanceKm!.toStringAsFixed(1)} km',
                  if (payment.isNotEmpty) payment,
                ].where((p) => p.isNotEmpty).join(' · '),
                style: AppTypography.bodySmall(color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(money(ride.fee + ride.tip),
                style: AppTypography.labelLarge(color: ink)
                    .copyWith(fontWeight: FontWeight.w800)),
            if (ride.tip > 0)
              Text('+ ${money(ride.tip)} ${l10n.earnings_tip_suffix}',
                  style: AppTypography.bodySmall(color: success)
                      .copyWith(fontSize: 11)),
          ],
        ),
      ]),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(children: [
        Icon(icon,
            size: 48,
            color:
                AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle)),
        const SizedBox(height: 12),
        Text(text,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium(color: muted)),
      ]),
    );
  }
}
