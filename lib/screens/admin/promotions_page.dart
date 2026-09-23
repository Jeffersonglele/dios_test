import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/services/promo_service.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/currency_util.dart';
import 'package:dios_delices/utils/toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key});

  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  List<Map<String, dynamic>> _promoCodes = [];
  bool _isLoading = true;
  String _country = 'RDC';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final session = await SessionService.readSession();
    _country = session.country;
    final codes = await PromoService.getAllPromoCodes();
    if (mounted) {
      setState(() {
        _promoCodes = codes;
        _isLoading = false;
      });
    }
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

  String _fmtDiscount(Map<String, dynamic> code) {
    final discountPercent = (code['discountPercent'] ?? 0).toDouble();
    final discountFixed = (code['discountFixed'] ?? 0).toDouble();

    if (discountPercent > 0) {
      return '-${discountPercent.toInt()}%';
    }
    if (discountFixed > 0) {
      return '-${CurrencyUtil.formatPrice(discountFixed, _country)}';
    }
    return '—';
  }

  bool _isActive(Map<String, dynamic> code) {
    final active = code['active'];
    // Le switch doit représenter uniquement le champ `active` de Parse.
    // Une date expirée rend le code inutilisable, mais ne doit pas empêcher
    // l'administrateur de le réactiver/désactiver depuis cette page.
    return active is bool
        ? active
        : (active == 1 || active == true || active?.toString() == 'true');
  }

  void _showCreateForm() {
    final codeCtrl = TextEditingController();
    final discountValueCtrl = TextEditingController();
    final minOrderCtrl = TextEditingController(text: '0');
    final maxUsesCtrl = TextEditingController(text: '0');
    final descCtrl = TextEditingController();
    String discountType = 'percentage';
    DateTime? validFrom;
    DateTime? validUntil;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.resolve(
                            AppColors.border, AppDarkColors.border),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.resolve(
                            AppColors.brandSurface, AppDarkColors.brandSurface),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(Icons.local_offer_rounded,
                          color: AppColors.brand, size: 18),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(AppLocalizations.of(context)!.promo_create_title,
                        style: AppTypography.titleMedium(
                            color: AppColors.resolve(
                                AppColors.ink, AppDarkColors.ink))),
                  ]),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: codeCtrl,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.promo_code_label,
                      prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? AppLocalizations.of(context)!.promo_required
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    value: discountType,
                    decoration: InputDecoration(
                      labelText:
                          AppLocalizations.of(context)!.promo_discount_type,
                      prefixIcon: const Icon(Icons.percent_rounded, size: 20),
                    ),
                    items: [
                      DropdownMenuItem(
                          value: 'percentage',
                          child: Text(
                              AppLocalizations.of(context)!.promo_percentage)),
                      DropdownMenuItem(
                          value: 'fixed',
                          child: Text(AppLocalizations.of(context)!
                              .promo_fixed_amount)),
                    ],
                    onChanged: (v) {
                      if (v != null) setSheetState(() => discountType = v);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: discountValueCtrl,
                    decoration: InputDecoration(
                      labelText: discountType == 'percentage'
                          ? AppLocalizations.of(context)!.promo_value_percent
                          : AppLocalizations.of(context)!.promo_value_fixed,
                      prefixIcon:
                          const Icon(Icons.monetization_on_outlined, size: 20),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return AppLocalizations.of(context)!.promo_required;
                      }
                      final value = double.tryParse(v);
                      if (value == null) {
                        return 'Valeur invalide';
                      }
                      if (discountType == 'percentage' &&
                          (value <= 0 || value > 100)) {
                        return 'Le pourcentage doit être entre 1 et 100';
                      }
                      if (discountType == 'fixed' && value <= 0) {
                        return 'Le montant doit être supérieur à 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: minOrderCtrl,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.promo_min_order,
                      prefixIcon:
                          const Icon(Icons.shopping_cart_outlined, size: 20),
                      helperText: '0 = pas de minimum',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v != null && v.trim().isNotEmpty) {
                        final n = int.tryParse(v.trim());
                        if (n == null || n < 0) return 'Entrez un nombre ≥ 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: maxUsesCtrl,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.promo_max_uses,
                      prefixIcon: const Icon(Icons.repeat_rounded, size: 20),
                      helperText: '0 = illimité',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v != null && v.trim().isNotEmpty) {
                        final n = int.tryParse(v.trim());
                        if (n == null || n < 0) return 'Entrez un nombre ≥ 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: validFrom ?? DateTime.now(),
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 365)),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365 * 5)),
                            );
                            if (picked != null) {
                              setSheetState(() => validFrom = picked);
                            }
                          },
                          child: AbsorbPointer(
                            child: TextFormField(
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(context)!
                                    .promo_valid_from,
                                prefixIcon: const Icon(Icons.date_range_rounded,
                                    size: 20),
                                hintText: validFrom != null
                                    ? '${validFrom!.day.toString().padLeft(2, '0')}/'
                                        '${validFrom!.month.toString().padLeft(2, '0')}/'
                                        '${validFrom!.year}'
                                    : AppLocalizations.of(context)!
                                        .promo_select_date,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: validUntil ??
                                  DateTime.now().add(const Duration(days: 30)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365 * 5)),
                            );
                            if (picked != null) {
                              setSheetState(() => validUntil = picked);
                            }
                          },
                          child: AbsorbPointer(
                            child: TextFormField(
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(context)!
                                    .promo_valid_until,
                                prefixIcon:
                                    const Icon(Icons.event_rounded, size: 20),
                                hintText: validUntil != null
                                    ? '${validUntil!.day.toString().padLeft(2, '0')}/'
                                        '${validUntil!.month.toString().padLeft(2, '0')}/'
                                        '${validUntil!.year}'
                                    : AppLocalizations.of(context)!
                                        .promo_select_date,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: descCtrl,
                    decoration: InputDecoration(
                      labelText:
                          AppLocalizations.of(context)!.promo_description,
                      prefixIcon:
                          const Icon(Icons.description_outlined, size: 20),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;

                        final code = codeCtrl.text.trim().toUpperCase();
                        final discountVal =
                            double.tryParse(discountValueCtrl.text) ?? 0;
                        final minOrderVal =
                            int.tryParse(minOrderCtrl.text) ?? 0;
                        final maxUsesVal = int.tryParse(maxUsesCtrl.text) ?? 0;
                        final description = descCtrl.text.trim().isEmpty
                            ? 'Promo ${codeCtrl.text.trim().toUpperCase()}'
                            : descCtrl.text.trim();

                        String result;

                        if (discountType == 'percentage') {
                          result = await PromoService.createPromoCode(
                            code: code,
                            discountPercent: discountVal,
                            discountFixed: 0,
                            description: description,
                            minOrder: minOrderVal,
                            maxUses: maxUsesVal,
                            validFrom: validFrom,
                            validUntil: validUntil,
                          );
                        } else {
                          result = await PromoService.createPromoCode(
                            code: code,
                            discountPercent: 0,
                            discountFixed: discountVal,
                            description: description,
                            minOrder: minOrderVal,
                            maxUses: maxUsesVal,
                            validFrom: validFrom,
                            validUntil: validUntil,
                          );
                        }

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (mounted) {
                          Toast(
                            context,
                            result == 'success'
                                ? AppLocalizations.of(context)!.promo_created
                                : result,
                            result == 'success',
                          );
                          if (result == 'success') _load();
                        }
                      },
                      child: Text(AppLocalizations.of(context)!.promo_submit),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(String code) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.promo_delete_confirm),
        content: Text('$code ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await PromoService.deletePromoCode(code);
      _load();
    }
  }

  void _showEditForm(Map<String, dynamic> current) {
    final discountValueCtrl = TextEditingController(
      text: ((current['discountPercent'] ?? 0) > 0
          ? current['discountPercent'].toString()
          : current['discountFixed']?.toString() ?? '0'),
    );
    final minOrderCtrl = TextEditingController(text: (current['minOrder'] ?? 0).toString());
    final maxUsesCtrl = TextEditingController(text: (current['maxUses'] ?? 0).toString());
    final descCtrl = TextEditingController(text: current['description'] ?? '');
    String discountType = (current['discountPercent'] ?? 0) > 0 ? 'percentage' : 'fixed';
    final formKey = GlobalKey<FormState>();
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.lg, top: AppSpacing.lg, bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.resolve(AppColors.border, AppDarkColors.border), borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.promo_edit_title_key(current['code']), style: AppTypography.titleMedium()),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<String>(
                  value: discountType,
                  decoration: InputDecoration(labelText: l10n.promo_discount_type, prefixIcon: const Icon(Icons.percent_rounded, size: 20)),
                  items: [
                    DropdownMenuItem(value: 'percentage', child: Text(l10n.promo_percentage)),
                    DropdownMenuItem(value: 'fixed', child: Text(l10n.promo_fixed_amount)),
                  ],
                  onChanged: (v) { if (v != null) setSheetState(() => discountType = v); },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: discountValueCtrl,
                  decoration: InputDecoration(labelText: discountType == 'percentage' ? l10n.promo_value_percent : l10n.promo_value_fixed, prefixIcon: const Icon(Icons.monetization_on_outlined, size: 20)),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return l10n.promo_required;
                    final val = double.tryParse(v); if (val == null) return 'Valeur invalide';
                    if (discountType == 'percentage' && (val <= 0 || val > 100)) return 'Entre 1 et 100';
                    if (discountType == 'fixed' && val <= 0) return 'Supérieur à 0';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(controller: minOrderCtrl, decoration: InputDecoration(labelText: l10n.promo_min_order, prefixIcon: const Icon(Icons.shopping_cart_outlined, size: 20)), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], validator: (v) {
                  if (v != null && v.trim().isNotEmpty) { final n = int.tryParse(v.trim()); if (n == null || n < 0) return 'Nombre (≥ 0)'; } return null;
                }),
                const SizedBox(height: AppSpacing.md),
                TextFormField(controller: maxUsesCtrl, decoration: InputDecoration(labelText: l10n.promo_max_uses, prefixIcon: const Icon(Icons.repeat_rounded, size: 20)), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], validator: (v) {
                  if (v != null && v.trim().isNotEmpty) { final n = int.tryParse(v.trim()); if (n == null || n < 0) return 'Nombre (≥ 0)'; } return null;
                }),
                const SizedBox(height: AppSpacing.md),
                TextFormField(controller: descCtrl, decoration: InputDecoration(labelText: l10n.promo_description, prefixIcon: const Icon(Icons.description_outlined, size: 20)), maxLines: 2),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final discountVal = double.tryParse(discountValueCtrl.text) ?? 0;
                    final result = await PromoService.updatePromoCode(
                      code: current['code'],
                      discountPercent: discountType == 'percentage' ? discountVal : 0,
                      discountFixed: discountType == 'fixed' ? discountVal : 0,
                      description: descCtrl.text.trim().isEmpty ? 'Promo ${current['code']}' : descCtrl.text.trim(),
                      minOrder: int.tryParse(minOrderCtrl.text) ?? 0,
                      maxUses: int.tryParse(maxUsesCtrl.text) ?? 0,
                    );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (mounted) { Toast(context, result == 'success' ? 'Modifié' : result, result == 'success'); if (result == 'success') _load(); }
                  },
                  child: Text(l10n.save),
                )),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.promo_title)),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _showCreateForm,
        backgroundColor:
            AppColors.resolve(AppColors.brand, AppDarkColors.brand),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _promoCodes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_offer_outlined,
                          size: 64,
                          color: AppColors.resolve(
                              AppColors.inkSubtle, AppDarkColors.inkSubtle)),
                      const SizedBox(height: AppSpacing.md),
                      Text(AppLocalizations.of(context)!.promo_empty,
                          style: AppTypography.titleMedium(
                              color: AppColors.resolve(
                                  AppColors.inkMuted, AppDarkColors.inkMuted))),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        AppLocalizations.of(context)!.promo_empty_hint,
                        style: AppTypography.bodyMedium(
                            color: AppColors.resolve(
                                AppColors.inkSubtle, AppDarkColors.inkSubtle)),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ElevatedButton.icon(
                        onPressed: _showCreateForm,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                            AppLocalizations.of(context)!.promo_create_code),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.brand,
                  backgroundColor:
                      AppColors.resolve(AppColors.card, AppDarkColors.card),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 100),
                    itemCount: _promoCodes.length,
                    itemBuilder: (_, i) {
                      final code = _promoCodes[i];
                      final active = _isActive(code);
                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.resolve(
                              AppColors.card, AppDarkColors.card),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(
                            color: AppColors.resolve(
                                AppColors.border, AppDarkColors.border),
                            width: 0.5,
                          ),
                          boxShadow: [AppShadows.subtle],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      code['code']?.toString() ?? '—',
                                      style: AppTypography.titleMedium(
                                          color: AppColors.resolve(
                                              AppColors.ink,
                                              AppDarkColors.ink)),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: active
                                          ? AppColors.resolve(
                                              AppColors.successLight,
                                              AppDarkColors.successLight)
                                          : AppColors.resolve(
                                              AppColors.errorLight,
                                              AppDarkColors.errorLight),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      active
                                          ? AppLocalizations.of(context)!
                                              .promo_active
                                          : AppLocalizations.of(context)!
                                              .promo_inactive,
                                      style: AppTypography.labelMedium(
                                              color: active
                                                  ? AppColors.success
                                                  : AppColors.error)
                                          .copyWith(fontSize: 11),
                                    ),
                                  ),
                                  Switch(
                                    value: active,
                                    activeColor: AppColors.success,
                                    onChanged: (_) async {
                                      final codeStr = code['code']?.toString() ?? '';
                                      // Optimistic update
                                      setState(() {
                                        final idx = _promoCodes.indexOf(code);
                                        if (idx != -1) {
                                          _promoCodes[idx]['active'] = !active;
                                        }
                                      });
                                      final toggled = await PromoService.togglePromoActive(codeStr);
                                      if (!toggled) {
                                        // Revert on failure
                                        if (mounted) _load();
                                      } else if (mounted) {
                                        // Recharger l'état réellement enregistré dans Parse.
                                        await _load();
                                      }
                                    },
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                                    onSelected: (action) async {
                                      if (action == 'edit') {
                                        _showEditForm(code);
                                      } else if (action == 'delete') {
                                        _confirmDelete(code['code']);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text(AppLocalizations.of(context)!.modify),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text(AppLocalizations.of(context)!.delete,
                                            style: const TextStyle(color: AppColors.error)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(children: [
                                Icon(Icons.discount_rounded,
                                    size: 14,
                                    color: AppColors.resolve(
                                        AppColors.brand, AppDarkColors.brand)),
                                const SizedBox(width: 6),
                                Text(
                                  _fmtDiscount(code),
                                  style: AppTypography.labelLarge(
                                      color: AppColors.resolve(AppColors.brand,
                                          AppDarkColors.brand)),
                                ),
                                const Spacer(),
                                Icon(Icons.shopping_cart_outlined,
                                    size: 14,
                                    color: AppColors.resolve(
                                        AppColors.inkSubtle,
                                        AppDarkColors.inkSubtle)),
                                const SizedBox(width: 6),
                                Text(
                                  'Min. ${(code['minOrder'] ?? 0) > 0 ? CurrencyUtil.formatPrice((code['minOrder'] as num).toDouble(), _country) : '0'}',
                                  style: AppTypography.bodyMedium(
                                      color: AppColors.resolve(
                                          AppColors.inkMuted,
                                          AppDarkColors.inkMuted)),
                                ),
                              ]),
                              const SizedBox(height: AppSpacing.sm),
                              Row(children: [
                                Icon(Icons.date_range_rounded,
                                    size: 14,
                                    color: AppColors.resolve(
                                        AppColors.inkSubtle,
                                        AppDarkColors.inkSubtle)),
                                const SizedBox(width: 6),
                                Text(
                                  'Du ${_fmtDate(code['validFrom'])} '
                                  'au ${_fmtDate(code['validUntil'])}',
                                  style: AppTypography.bodySmall(
                                      color: AppColors.resolve(
                                          AppColors.inkMuted,
                                          AppDarkColors.inkMuted)),
                                ),
                              ]),
                              if ((code['maxUses'] ?? 0) > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(children: [
                                    Icon(Icons.repeat_rounded,
                                        size: 12,
                                        color: AppColors.resolve(
                                            AppColors.inkSubtle,
                                            AppDarkColors.inkSubtle)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Utilisations max: ${code['maxUses']}',
                                      style: AppTypography.bodySmall(
                                          color: AppColors.resolve(
                                              AppColors.inkMuted,
                                              AppDarkColors.inkMuted)),
                                    ),
                                  ]),
                                ),
                              if (code['description'] != null &&
                                  (code['description'] as String)
                                      .isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  code['description'] as String,
                                  style: AppTypography.bodySmall(
                                      color: AppColors.resolve(
                                          AppColors.inkSubtle,
                                          AppDarkColors.inkSubtle)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
