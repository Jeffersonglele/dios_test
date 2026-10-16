import 'package:dios_delices/core/app_role.dart';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/services/node_admin_service.dart';
import 'package:dios_delices/services/node_auth_service.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/country_util.dart';
import 'package:dios_delices/utils/toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Grille des frais de livraison par ville, telle que le serveur l'applique :
/// frais = max(minimum, prise en charge + prix/km × distance au-delà de la
/// distance incluse), arrondi. Sans grille propre, la ville utilise la grille
/// par défaut de son pays.
class DeliveryConfigPage extends StatefulWidget {
  const DeliveryConfigPage({super.key});

  @override
  State<DeliveryConfigPage> createState() => _DeliveryConfigPageState();
}

class _CityTariff {
  _CityTariff({required this.city, required this.tariff});
  final Map<String, dynamic> city;
  Map<String, dynamic> tariff;

  int get cityId => int.tryParse('${city['cityId']}') ?? 0;
  String get name => city['name']?.toString() ?? 'Ville';
  String get country => city['country']?.toString() ?? '';
  bool get custom => tariff['source'] == 'CITY_CONFIGURATION';
  String get currency => tariff['currency']?.toString() ?? '';
  double num(String key) => double.tryParse('${tariff[key] ?? ''}') ?? 0;

  /// Même calcul que le serveur (delivery-pricing.service.js).
  double feeFor(double km) {
    final extra = (km - num('includedDistanceKm')).clamp(0, double.infinity);
    final raw = (num('baseFee') + extra * num('perKmRate') + num('fuelSurcharge')) *
        (num('demandMultiplier') == 0 ? 1 : num('demandMultiplier')) *
        (num('weatherMultiplier') == 0 ? 1 : num('weatherMultiplier'));
    final step = num('roundingIncrement') <= 0 ? 1 : num('roundingIncrement');
    final rounded = ((raw / step).ceil() * step).toDouble();
    return rounded < num('minFee') ? num('minFee') : rounded;
  }
}

class _DeliveryConfigPageState extends State<DeliveryConfigPage> {
  bool _loading = true;
  String? _error;
  List<_CityTariff> _cities = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await SessionService.readSession();
      final token = await SessionService.readNodeToken();
      if (token == null) throw const NodeAuthException('Session expirée.');
      final cities = await NodeAdminService.getCities(token);
      final myCountry = CountryUtil.canonical(session.country);
      final visible = cities.where((c) {
        if (c['active'] == false) return false;
        // Un admin gère son pays ; le super admin, tous.
        if (session.role == AppRole.superAdmin) return true;
        return CountryUtil.canonical('${c['country'] ?? ''}') == myCountry;
      }).toList();
      final rows = <_CityTariff>[];
      for (final city in visible) {
        final id = int.tryParse('${city['cityId']}') ?? 0;
        if (id <= 0) continue;
        final tariff = await NodeAdminService.getCityTariff(token, id);
        rows.add(_CityTariff(city: city, tariff: tariff));
      }
      if (!mounted) return;
      setState(() {
        _cities = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is NodeAuthException
            ? e.message
            : AppLocalizations.of(context)!.error;
      });
    }
  }

  Future<void> _edit(_CityTariff row) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TariffForm(row: row),
    );
    if (saved == true) _load();
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
        title: Text(l10n.delivery_config_title,
            style: AppTypography.titleSmall(color: ink)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Text(l10n.tariff_intro,
                      style: AppTypography.bodyMedium(color: muted)
                          .copyWith(height: 1.45)),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Text(_error!,
                        style: AppTypography.bodyMedium(
                            color: AppColors.resolve(
                                AppColors.error, AppDarkColors.error)))
                  else if (_cities.isEmpty)
                    Text(l10n.tariff_no_city,
                        style: AppTypography.bodyMedium(color: muted))
                  else
                    for (final row in _cities) ...[
                      _TariffCard(row: row, onEdit: () => _edit(row)),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
    );
  }
}

String _amount(double value, String currency) {
  final v = value.round().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');
  final label = currency == 'XOF' ? 'FCFA' : currency;
  return '$v $label';
}

String _km(double value) =>
    value == value.roundToDouble() ? '${value.round()}' : value.toStringAsFixed(1);

class _TariffCard extends StatelessWidget {
  const _TariffCard({required this.row, required this.onEdit});
  final _CityTariff row;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final warm =
        AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);
    final c = row.currency;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.location_city_rounded, color: brand, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${row.name} · ${row.country}',
                  style: AppTypography.titleSmall(color: ink)
                      .copyWith(fontWeight: FontWeight.w700)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (row.custom ? brand : muted).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                  row.custom ? l10n.tariff_custom : l10n.tariff_default,
                  style: AppTypography.labelMedium(
                          color: row.custom ? brand : muted)
                      .copyWith(fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 12),
          Text(
            l10n.tariff_formula(
              _amount(row.num('baseFee'), c),
              _amount(row.num('perKmRate'), c),
              _km(row.num('includedDistanceKm')),
              _amount(row.num('minFee'), c),
              _km(row.num('maxDistanceKm')),
            ),
            style: AppTypography.bodyMedium(color: ink).copyWith(height: 1.45),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: warm,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final km in const [1.0, 3.0, 5.0, 10.0])
                  Column(children: [
                    Text('${_km(km)} km',
                        style: AppTypography.bodySmall(color: muted)),
                    const SizedBox(height: 2),
                    Text(
                        km > row.num('maxDistanceKm')
                            ? '—'
                            : _amount(row.feeFor(km), c),
                        style: AppTypography.labelMedium(color: ink)
                            .copyWith(fontWeight: FontWeight.w800)),
                  ]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: Icon(Icons.edit_rounded, size: 18, color: brand),
              label: Text(l10n.tariff_edit,
                  style: AppTypography.labelMedium(color: brand)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: brand.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TariffForm extends StatefulWidget {
  const _TariffForm({required this.row});
  final _CityTariff row;

  @override
  State<_TariffForm> createState() => _TariffFormState();
}

class _TariffFormState extends State<_TariffForm> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _ctrls;
  bool _saving = false;

  static const _keys = [
    'baseFee',
    'perKmRate',
    'includedDistanceKm',
    'minFee',
    'maxDistanceKm',
    'roundingIncrement',
  ];

  @override
  void initState() {
    super.initState();
    _ctrls = {
      for (final k in _keys)
        k: TextEditingController(text: _km(widget.row.num(k))),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final token = await SessionService.readNodeToken();
      if (token == null) throw const NodeAuthException('Session expirée.');
      final values = <String, dynamic>{
        for (final k in _keys)
          k: double.parse(_ctrls[k]!.text.replaceAll(',', '.')),
        'currency': widget.row.currency,
      };
      await NodeAdminService.saveCityTariff(
        token: token,
        cityId: widget.row.cityId,
        configUuid: widget.row.tariff['id']?.toString(),
        values: values,
      );
      if (!mounted) return;
      Toast(context, l10n.delivery_config_saved, true);
      Navigator.pop(context, true);
    } on NodeAuthException catch (e) {
      if (mounted) Toast(context, e.message, false);
    } catch (_) {
      if (mounted) Toast(context, l10n.delivery_config_error, false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final c = widget.row.currency == 'XOF' ? 'FCFA' : widget.row.currency;
    final labels = {
      'baseFee': '${l10n.tariff_base_fee} ($c)',
      'perKmRate': '${l10n.tariff_per_km} ($c)',
      'includedDistanceKm': l10n.tariff_included_km,
      'minFee': '${l10n.tariff_min_fee} ($c)',
      'maxDistanceKm': l10n.tariff_max_km,
      'roundingIncrement': '${l10n.tariff_rounding} ($c)',
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${l10n.tariff_edit} · ${widget.row.name}',
                  style: AppTypography.titleSmall(color: ink)
                      .copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              for (final k in _keys) ...[
                TextFormField(
                  controller: _ctrls[k],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: labels[k],
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                    if (n == null || n < 0) return l10n.delivery_config_error;
                    if (k == 'maxDistanceKm' && n <= 0) {
                      return l10n.delivery_config_error;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 4),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(l10n.save,
                          style: AppTypography.labelLarge(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
