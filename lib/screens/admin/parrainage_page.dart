import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/currency_util.dart';
import 'package:dios_delices/utils/toast.dart';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class ParrainagePage extends StatefulWidget {
  const ParrainagePage({super.key});

  @override
  State<ParrainagePage> createState() => _ParrainagePageState();
}

class _ParrainagePageState extends State<ParrainagePage> {
  bool _isLoading = true;
  int _totalReferrals = 0;
  int _activeCodes = 0;
  int _rewardsGiven = 0;
  List<Map<String, dynamic>> _referralCodes = [];
  String _country = 'France';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final session = await SessionService.readSession();
    _country = session.country;
    await Future.wait([_loadStats(), _loadCodes()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadStats() async {
    try {
      final fn = ParseCloudFunction('getReferralStats');
      final response = await fn.execute();
      if (response.success && response.result != null) {
        final data = response.result as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _totalReferrals =
                (data['totalReferrals'] as num?)?.toInt() ?? 0;
            _activeCodes = (data['activeCodes'] as num?)?.toInt() ?? 0;
            _rewardsGiven =
                (data['rewardsGiven'] as num?)?.toInt() ?? 0;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadCodes() async {
    try {
      final fn = ParseCloudFunction('getAllReferralCodes');
      final response = await fn.execute();
      if (response.success && response.result != null) {
        final result = response.result;
        if (result is List) {
          if (mounted) {
            setState(() {
              _referralCodes = result
                  .map((e) => e is Map<String, dynamic>
                      ? e
                      : <String, dynamic>{})
                  .toList();
            });
          }
        }
      }
    } catch (_) {}
  }

  String _fmtDate(dynamic date) {
    if (date == null) return '—';
    if (date is Map && date['iso'] != null) {
      final dt = DateTime.tryParse(date['iso'])?.toLocal();
      if (dt != null) {
        return '${dt.day.toString().padLeft(2, '0')}/'
            '${dt.month.toString().padLeft(2, '0')}/'
            '${dt.year}';
      }
    }
    if (date is String) {
      final dt = DateTime.tryParse(date)?.toLocal();
      if (dt != null) {
        return '${dt.day.toString().padLeft(2, '0')}/'
            '${dt.month.toString().padLeft(2, '0')}/'
            '${dt.year}';
      }
    }
    return date.toString();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cardColor = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final surfaceColor =
        AppColors.resolve(AppColors.surface, AppDarkColors.surface);
    final inkColor = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final inkMutedColor =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final inkSubtleColor =
        AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle);

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(title: Text(l10n.referral_title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.brand,
              backgroundColor: cardColor,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 100),
                children: [
                  // ── Stats ────────────────────────────────────
                  Row(children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.people_rounded,
                        label: l10n.referral_godchildren,
                        value: '$_totalReferrals',
                        color: AppColors.brand,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.discount_rounded,
                        label: l10n.referral_active_codes,
                        value: '$_activeCodes',
                        color: const Color(0xFF9B59B6),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.redeem_rounded,
                        label: l10n.referral_rewards,
                        value: '$_rewardsGiven',
                        color: AppColors.success,
                      ),
                    ),
                  ]),

                  const SizedBox(height: AppSpacing.xl),

                  // ── Section codes de parrainage ──────────────
                  Row(children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.resolve(
                            AppColors.brandSurface, AppDarkColors.brandSurface),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.share_rounded,
                          color: AppColors.brand, size: 14),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(l10n.referral_codes_section,
                        style: AppTypography.titleMedium(color: inkColor)),
                  ]),

                  const SizedBox(height: AppSpacing.md),

                  if (_referralCodes.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xxl, horizontal: AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                            color: AppColors.resolve(
                                AppColors.border, AppDarkColors.border),
                            width: 0.5),
                      ),
                      child: Column(children: [
                        Icon(Icons.share_outlined,
                            size: 48, color: inkSubtleColor),
                        const SizedBox(height: AppSpacing.md),
                        Text(l10n.referral_empty,
                            style: AppTypography.titleMedium(
                                color: inkMutedColor)),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.referral_empty_hint,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium(color: inkSubtleColor),
                        ),
                      ]),
                    )
                  else
                    ..._referralCodes.map((rc) => Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(
                                color: AppColors.resolve(AppColors.border,
                                    AppDarkColors.border),
                                width: 0.5),
                            boxShadow: [AppShadows.subtle],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.resolve(
                                          AppColors.brandSurface,
                                          AppDarkColors.brandSurface),
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.sm),
                                    ),
                                    child: const Icon(Icons.share_rounded,
                                        color: AppColors.brand, size: 20),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          rc['code']?.toString() ?? '—',
                                          style: AppTypography.labelLarge(
                                              color: inkColor),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Créé le ${_fmtDate(rc['createdAt'] ?? rc['validFrom'])}',
                                          style: AppTypography.bodySmall(
                                              color: inkMutedColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.resolve(
                                          AppColors.brandSurface,
                                          AppDarkColors.brandSurface),
                                      borderRadius:
                                          BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '${rc['usageCount'] ?? rc['uses'] ?? 0} utilisé${(rc['usageCount'] ?? rc['uses'] ?? 0) > 1 ? 's' : ''}',
                                      style: AppTypography.labelMedium(
                                              color: AppColors.brand)
                                          .copyWith(fontSize: 11),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: AppSpacing.sm),
                                Row(children: [
                                  Icon(Icons.person_outline_rounded,
                                      size: 14, color: inkSubtleColor),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      rc['creatorName']?.toString() ??
                                          rc['userName']?.toString() ??
                                          'Utilisateur #${rc['userID'] ?? '?'}',
                                      style: AppTypography.bodyMedium(
                                          color: inkMutedColor),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (rc['discount'] != null ||
                                      rc['discountAmount'] != null) ...[
                                    const SizedBox(width: AppSpacing.sm),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.resolve(
                                            AppColors.successLight,
                                            AppDarkColors.successLight),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        CurrencyUtil.formatPrice(((rc['discount'] ?? rc['discountAmount']) as num?)?.toDouble() ?? 0, _country),
                                        style: AppTypography.labelMedium(
                                                color: AppColors.success)
                                            .copyWith(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ]),
                              ],
                            ),
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// _StatCard
// ═══════════════════════════════════════════════════════════
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: AppColors.resolve(AppColors.border, AppDarkColors.border),
            width: 0.5),
        boxShadow: [AppShadows.subtle],
      ),
      child: Column(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: AppSpacing.sm),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: AppTypography.headlineLarge(
                    color: AppColors.resolve(
                        AppColors.inkSubtle, AppDarkColors.inkSubtle))
                .copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: AppTypography.labelMedium(
                    color: AppColors.resolve(
                        AppColors.ink, AppDarkColors.ink))
                .copyWith(fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
