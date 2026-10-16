import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/currency_util.dart';
import 'package:dios_delices/widgets/order_otp_widgets.dart' show OtpGradientButton;
import 'package:dios_delices/widgets/swirling_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/currency_service.dart';
import '../../services/wallet_service.dart';
import '../payment/nyole_payment_page.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, this.openTopUpOnStart = false});
  final bool openTopUpOnStart;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  WalletData? _wallet;
  String? _error;
  bool _loading = true;
  bool _hideBalance = false;
  bool _verifyingTopUp = false;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.openTopUpOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openTopUp());
    }
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

  /// Le solde est tenu dans la devise du portefeuille (CDF/USD) : on le
  /// convertit vers la devise d'affichage choisie dans l'app.
  String _money(double v) {
    final currency = CurrencyService.instance.activeCurrency;
    final converted = CurrencyService.instance.convertBetween(
      v,
      _wallet?.currency ?? CurrencyService.instance.sourceCurrency,
      currency,
    );
    return CurrencyUtil.formatAmount(converted, currency);
  }

  void _snack(String message, {required Color color, required IconData icon}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        duration: const Duration(seconds: 5),
        content: Row(children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ]),
      ));
  }

  /// Recharge réelle : montant → page Nyole → attente de la confirmation
  /// serveur → rafraîchissement du solde. Le retour « succès » de Nyole
  /// n'est pas une preuve : seul le statut vérifié par le serveur compte.
  Future<void> _openTopUp() async {
    final session = await showModalBottomSheet<TopUpSession>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TopUpSheet(currency: _wallet?.currency ?? 'CDF'),
    );
    if (session == null || !mounted) return;

    final returnedSuccess = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NyolePaymentPage(
          paymentUrl: session.paymentUrl,
          orderId: session.transactionId,
        ),
      ),
    );
    if (!mounted) return;
    if (returnedSuccess != true) {
      _snack('Recharge annulée. Aucun montant n’a été débité.',
          color: AppColors.inkMuted, icon: Icons.info_outline_rounded);
      return;
    }

    setState(() => _verifyingTopUp = true);
    final status = await WalletService.waitForTopUp(session.transactionId);
    if (!mounted) return;
    setState(() => _verifyingTopUp = false);
    await _load(); // rafraîchit solde + historique

    switch (status) {
      case TopUpStatus.paid:
        _snack('Recharge confirmée : votre solde est à jour.',
            color: AppColors.success, icon: Icons.check_circle_rounded);
        break;
      case TopUpStatus.failed:
        _snack('Le paiement a échoué. Votre solde n’a pas changé.',
            color: AppColors.error, icon: Icons.error_outline_rounded);
        break;
      case TopUpStatus.pending:
        _snack(
            'Paiement en cours de vérification. Votre solde sera mis à jour '
            'dès la confirmation de l’opérateur.',
            color: AppColors.inkMuted,
            icon: Icons.hourglass_top_rounded);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface =
        AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);

    return ListenableBuilder(
      listenable: CurrencyService.instance,
      builder: (context, _) {
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
                        label: _verifyingTopUp
                            ? 'Vérification du paiement…'
                            : 'Recharger mon solde',
                        icon: Icons.add_card_rounded,
                        isLoading: _verifyingTopUp,
                        onPressed: _verifyingTopUp ? null : _openTopUp,
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
      },
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

    final currency = CurrencyService.instance.activeCurrency;
    final isAuto = CurrencyService.instance.isAutoCurrency;

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
                    // Badge de la devise active
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isAuto)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.my_location_rounded,
                                  size: 11, color: Colors.white70),
                            ),
                          Text(
                            currency,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
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
// BottomSheet de recharge (possède et libère ses contrôleurs).
// Ouvre la session Nyole et se ferme avec la TopUpSession, ou null.
// L'opérateur (M-Pesa, Orange Money, Airtel Money…) se choisit sur la
// page sécurisée Nyole : aucun numéro n'est demandé ici.
// ═══════════════════════════════════════════════════════════
class _TopUpSheet extends StatefulWidget {
  const _TopUpSheet({required this.currency});

  /// Devise du portefeuille : la recharge se fait toujours dans celle-ci.
  final String currency;

  @override
  State<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<_TopUpSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  /// Montants rapides par devise (entiers : Nyole n'accepte pas de décimales).
  static const _quickAmounts = {
    'CDF': [5000, 10000, 20000, 50000],
    'USD': [5, 10, 20, 50],
    'XOF': [1000, 2000, 5000, 10000],
  };

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  int? get _amount =>
      int.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final session = await WalletService.startTopUp(
        amount: _amount!,
        currency: widget.currency,
      );
      if (!mounted) return;
      Navigator.of(context).pop(session);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e is WalletException
            ? e.message
            : 'Impossible de lancer la recharge. Réessayez.';
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

  Widget _quickChip(int value) {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final selected = _amount == value;
    return ChoiceChip(
      label: Text(CurrencyUtil.formatAmount(value.toDouble(), widget.currency)),
      selected: selected,
      showCheckmark: false,
      selectedColor: brand.withValues(alpha: 0.14),
      labelStyle: AppTypography.labelMedium(
        color: selected
            ? brand
            : AppColors.resolve(AppColors.ink, AppDarkColors.ink),
      ).copyWith(fontWeight: FontWeight.w700),
      side: BorderSide(
        color: selected
            ? brand
            : AppColors.resolve(AppColors.border, AppDarkColors.border),
      ),
      onSelected: _submitting
          ? null
          : (_) => setState(() {
                _amountCtrl.text = '$value';
                _error = null;
              }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final currency = widget.currency;
    final quick = _quickAmounts[currency] ?? const <int>[];

    return PopScope(
      canPop: !_submitting, // pas de fermeture pendant l'appel
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Material(
            color: card,
            child: SingleChildScrollView(
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
                        style: AppTypography.titleMedium(color: ink).copyWith(
                            fontWeight: FontWeight.w800, fontSize: 20)),
                    const SizedBox(height: 6),
                    Text(
                      'Vous choisirez votre opérateur (M-Pesa, Orange Money, '
                      'Airtel Money…) sur la page de paiement sécurisée.',
                      style: AppTypography.bodyMedium(color: muted)
                          .copyWith(height: 1.4),
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: _amountCtrl,
                      enabled: !_submitting,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() => _error = null),
                      onFieldSubmitted: (_) => _submit(),
                      decoration: _decoration('Montant ($currency)',
                          Icons.payments_rounded, 'Ex. ${quick.isNotEmpty ? quick[1] : 5000}'),
                      validator: (_) {
                        final a = _amount;
                        if (a == null || a <= 0) {
                          return 'Saisissez un montant valide';
                        }
                        return null;
                      },
                    ),
                    if (quick.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [for (final v in quick) _quickChip(v)],
                      ),
                    ],
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
                      label: 'Continuer vers le paiement',
                      icon: Icons.lock_rounded,
                      isLoading: _submitting,
                      onPressed: _submitting ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
