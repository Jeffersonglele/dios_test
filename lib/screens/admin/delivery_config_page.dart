import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/toast.dart';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class DeliveryConfigPage extends StatefulWidget {
  const DeliveryConfigPage({super.key});

  @override
  State<DeliveryConfigPage> createState() => _DeliveryConfigPageState();
}

class _DeliveryConfigPageState extends State<DeliveryConfigPage> {
  bool _loading = true;
  bool _saving = false;

  final _baseFeeCtrl = TextEditingController();
  final _perKmCtrl = TextEditingController();

  int _currentBaseFee = 1500;
  int _currentPerKm = 300;
  String _currency = 'CDF';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _baseFeeCtrl.dispose();
    _perKmCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final fn = ParseCloudFunction('getDeliveryConfig');
      final response = await fn.execute();
      if (response.success && response.result != null) {
        final data = response.result as Map<String, dynamic>;
        if (data['success'] == true && mounted) {
          final baseFee = (data['baseFee'] as num?)?.toInt() ?? 1500;
          final perKmRate = (data['perKmRate'] as num?)?.toInt() ?? 300;
          _currentBaseFee = baseFee;
          _currentPerKm = perKmRate;
          _currency = data['currency'] as String? ?? 'CDF';
          _baseFeeCtrl.text = baseFee.toString();
          _perKmCtrl.text = perKmRate.toString();
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final baseFee = int.tryParse(_baseFeeCtrl.text);
    final perKm = int.tryParse(_perKmCtrl.text);

    if (baseFee == null || baseFee < 0 || perKm == null || perKm < 0) {
      Toast(context, l10n.delivery_config_error, false);
      return;
    }

    setState(() => _saving = true);
    try {
      final fn = ParseCloudFunction('updateDeliveryConfig');
      final response = await fn.execute(parameters: {
        'baseFee': baseFee,
        'perKmRate': perKm,
      });
      if (response.success && mounted) {
        Toast(context, l10n.delivery_config_saved, true);
        _load();
      }
    } catch (_) {
      if (mounted) Toast(context, l10n.delivery_config_error, false);
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final surface = AppColors.resolve(AppColors.surface, AppDarkColors.surface);

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: Text(l10n.delivery_config_title, style: AppTypography.titleMedium()),
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.brand),
                  const SizedBox(height: 16),
                  Text(l10n.delivery_config_loading,
                      style: AppTypography.bodyMedium(color: AppColors.inkMuted)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCurrentCard(l10n),
                  const SizedBox(height: 24),
                  _buildForm(l10n),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentCard(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.resolve(AppColors.border, AppDarkColors.border),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.delivery_config_current,
              style: AppTypography.labelMedium(color: AppColors.inkMuted)),
          const SizedBox(height: 16),
          _configRow(
            icon: Icons.monetization_on_outlined,
            label: l10n.delivery_config_base_fee,
            value: '$_currentBaseFee $_currency',
          ),
          const SizedBox(height: 12),
          _configRow(
            icon: Icons.route_outlined,
            label: l10n.delivery_config_per_km,
            value: '$_currentPerKm $_currency',
          ),
          const SizedBox(height: 12),
          _configRow(
            icon: Icons.straighten_outlined,
            label: l10n.delivery_config_currency,
            value: _currency,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.brandSurface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                const Icon(Icons.calculate_outlined, size: 18, color: AppColors.brand),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$_currentBaseFee $_currency + $_currentPerKm $_currency/km × distance',
                    style: AppTypography.bodySmall(color: AppColors.brand),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _configRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.brandSurface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, size: 16, color: AppColors.brand),
        ),
        const SizedBox(width: 12),
        Text(label, style: AppTypography.bodyMedium()),
        const Spacer(),
        Text(value,
            style: AppTypography.labelMedium(
                color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
      ],
    );
  }

  Widget _buildForm(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.resolve(AppColors.border, AppDarkColors.border),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _baseFeeCtrl,
            decoration: InputDecoration(
              labelText: l10n.delivery_config_base_fee,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _perKmCtrl,
            decoration: InputDecoration(
              labelText: l10n.delivery_config_per_km,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n.delivery_config_save),
            ),
          ),
        ],
      ),
    );
  }
}
