import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/currency_util.dart';
import 'package:dios_delices/widgets/order_otp_widgets.dart' show OtpGradientButton;
import 'package:dios_delices/widgets/swirling_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/wallet_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  WalletData? _wallet;
  String? _error;
  bool _loading = true;
  bool _hideBalance = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _error = null);
    try {
      final data = await WalletService.fetchWallet();
      if (!mounted) return;
      setState(() {
        _wallet = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is WalletException
            ? e.message
            : 'Impossible de charger le portefeuille.';
        _loading = false;
      });
    }
  }

  String _money(double v) => '${CurrencyUtil.symbol('CDF')} ${v.toStringAsFixed(2)}';

  Future<void> _openTopUp() async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TopUpSheet(),
    );
    if (message != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ]),
        ));
      await _load(); // rafraîchit solde + historique
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface =
        AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Mon portefeuille',
            style: AppTypography.titleMedium(color: ink)
                .copyWith(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? Center(child: Swirling(size: 56, color: AppColors.brand))
          : RefreshIndicator(
              color: AppColors.brand,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  _BalanceCard(
                    balance: _wallet == null ? null : _money(_wallet!.balance),
                    hidden: _hideBalance,
                    onToggle: () =>
                        setState(() => _hideBalance = !_hideBalance),
                  ),
                  const SizedBox(height: 18),
                  OtpGradientButton(
                    label: 'Recharger mon solde',
                    icon: Icons.add_card_rounded,
                    onPressed: _openTopUp,
                  ),
                  const SizedBox(height: 28),
                  Text('Dernières transactions',
                      style: AppTypography.titleMedium(color: ink)
                          .copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  ..._historySection(),
                ],
              ),
            ),
    );
  }

  List<Widget> _historySection() {
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);

    if (_error != null && _wallet == null) {
      return [
        _Placeholder(
          icon: Icons.cloud_off_rounded,
          text: _error!,
          action: TextButton(onPressed: _load, child: const Text('Réessayer')),
        ),
      ];
    }
    final txs = (_wallet?.transactions ?? const <WalletTransaction>[])
        .take(10)
        .toList();
    if (txs.isEmpty) {
      return [
        _Placeholder(
          icon: Icons.receipt_long_rounded,
          text: 'Aucune transaction pour le moment.',
          sub: 'Rechargez votre solde pour commencer.',
          muted: muted,
        ),
      ];
    }
    return [
      for (final t in txs) _TransactionTile(tx: t, money: _money),
    ];
  }
}

// ═══════════════════════════════════════════════════════════
// Carte du solde
// ═══════════════════════════════════════════════════════════
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balance,
    required this.hidden,
    required this.onToggle,
  });

  final String? balance;
  final bool hidden;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final radius = BorderRadius.circular(28);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [brand, Color.lerp(brand, Colors.black, 0.28)!],
        ),
        boxShadow: [
          BoxShadow(
            color: brand.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -50,
              child: _circle(150, 0.10),
            ),
            Positioned(
              right: 30,
              bottom: -70,
              child: _circle(130, 0.07),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 16, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Solde disponible',
                          style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ),
                    IconButton(
                      onPressed: onToggle,
                      tooltip: hidden ? 'Afficher' : 'Masquer',
                      icon: Icon(
                        hidden
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: Colors.white70,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      balance == null ? '—' : (hidden ? '••••••' : balance!),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Dios Délices Wallet',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: alpha),
        ),
      );
}

// ═══════════════════════════════════════════════════════════
// Ligne de transaction
// ═══════════════════════════════════════════════════════════
class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx, required this.money});

  final WalletTransaction tx;
  final String Function(double) money;

  String _date(DateTime? d) {
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} à ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);

    final color = tx.isFailed
        ? AppColors.error
        : tx.isCredit
            ? AppColors.success
            : ink;
    final title = tx.description.isNotEmpty
        ? tx.description
        : (tx.isCredit ? 'Recharge du portefeuille' : 'Paiement');
    final sub = [
      _date(tx.createdAt),
      if (tx.isPending) 'En attente',
      if (tx.isFailed) 'Échouée',
    ].where((e) => e.isNotEmpty).join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 0.6),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: (tx.isCredit ? AppColors.success : AppColors.brand)
                .withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            tx.isCredit
                ? Icons.south_west_rounded
                : Icons.north_east_rounded,
            color: tx.isCredit ? AppColors.success : AppColors.brand,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium(color: ink)
                    .copyWith(fontWeight: FontWeight.w700)),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium(color: muted)
                      .copyWith(fontSize: 12)),
            ],
          ]),
        ),
        const SizedBox(width: 10),
        Text('${tx.isCredit ? '+' : '−'} ${money(tx.amount)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              decoration: tx.isFailed ? TextDecoration.lineThrough : null,
            )),
      ]),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.icon,
    required this.text,
    this.sub,
    this.action,
    this.muted,
  });

  final IconData icon;
  final String text;
  final String? sub;
  final Widget? action;
  final Color? muted;

  @override
  Widget build(BuildContext context) {
    final m = muted ?? AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(children: [
        Icon(icon, size: 44, color: m.withValues(alpha: 0.6)),
        const SizedBox(height: 12),
        Text(text,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium(color: m)
                .copyWith(fontWeight: FontWeight.w600)),
        if (sub != null) ...[
          const SizedBox(height: 4),
          Text(sub!,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(color: m).copyWith(fontSize: 12)),
        ],
        if (action != null) ...[const SizedBox(height: 8), action!],
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// BottomSheet de recharge (possède et libère ses contrôleurs)
// Se ferme avec le message de succès (String) ou null.
// ═══════════════════════════════════════════════════════════
class _TopUpSheet extends StatefulWidget {
  const _TopUpSheet();

  @override
  State<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<_TopUpSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  double? get _amount =>
      double.tryParse(_amountCtrl.text.trim().replaceAll(',', '.'));

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // Simulation de l'appel à l'agrégateur Mobile Money (comme avant) :
      // à remplacer par le vrai paiement ; le backend doit vérifier le
      // referenceId auprès de l'agrégateur avant de créditer le solde.
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      final res = await WalletService.requestTopUp(
        amount: _amount!,
        phone: _phoneCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(res.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e is WalletException
            ? e.message
            : 'La recharge a échoué. Réessayez.';
      });
    }
  }

  InputDecoration _decoration(String label, IconData icon, String hint) {
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.brand),
      enabledBorder: b(border),
      focusedBorder: b(AppColors.brand, 1.6),
      errorBorder: b(AppColors.error),
      focusedErrorBorder: b(AppColors.error, 1.6),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);

    return PopScope(
      canPop: !_submitting, // pas de fermeture pendant l'appel
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Material(
            color: card,
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: muted.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('Recharger mon solde',
                            style: AppTypography.titleMedium(color: ink)
                                .copyWith(
                                    fontWeight: FontWeight.w800, fontSize: 20)),
                        const SizedBox(height: 6),
                        Text(
                          'Payez par Mobile Money : vous recevrez une demande de confirmation sur votre téléphone.',
                          style: AppTypography.bodyMedium(color: muted)
                              .copyWith(height: 1.4),
                        ),
                        const SizedBox(height: 22),
                        TextFormField(
                          controller: _amountCtrl,
                          enabled: !_submitting,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]')),
                          ],
                          textInputAction: TextInputAction.next,
                          decoration: _decoration(
                              'Montant (CDF)', Icons.payments_rounded, 'Ex. 5000'),
                          validator: (_) {
                            final a = _amount;
                            if (a == null || a <= 0) {
                              return 'Saisissez un montant valide';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phoneCtrl,
                          enabled: !_submitting,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                          ],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: _decoration('Numéro Mobile Money',
                              Icons.phone_android_rounded, 'Ex. 97 00 00 00'),
                          validator: (v) {
                            final digits =
                                (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                            if (digits.length < 8 || digits.length > 15) {
                              return 'Numéro de téléphone invalide';
                            }
                            return null;
                          },
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: AppColors.error, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_error!,
                                    style: const TextStyle(
                                        color: AppColors.error,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ]),
                          ),
                        ],
                        const SizedBox(height: 22),
                        OtpGradientButton(
                          label: 'Valider la recharge',
                          icon: Icons.check_circle_outline_rounded,
                          isLoading: _submitting,
                          onPressed: _submitting ? null : _submit,
                        ),
                      ],
                    ),
                  ),
                ),
                // Écran bloqué pendant l'appel
                if (_submitting)
                  Positioned.fill(
                    child: ColoredBox(
                      color: card.withValues(alpha: 0.65),
                      child: Center(
                        child: Swirling(size: 52, color: AppColors.brand),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}