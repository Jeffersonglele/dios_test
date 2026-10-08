import 'dart:async';
import 'package:dios_delices/core/commande_status.dart';
import 'package:dios_delices/models/commande.dart';
import 'package:dios_delices/models/restaurant.dart';
import 'package:dios_delices/screens/orders/commande_details_page.dart';
import 'package:dios_delices/services/commande_api.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/services/socket_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/currency_util.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

enum OrderOtpMode { pickup, delivery }

OrderOtpMode orderOtpModeFrom({String? deliveryMode}) {
  final d = (deliveryMode ?? '').toLowerCase().trim();
  if (d == 'pickup' || d == 'emporter' || d == 'a_emporter' || d == 'à emporter') {
    return OrderOtpMode.pickup;
  }
  return OrderOtpMode.delivery;
}

class OtpGradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isLoading;
  final VoidCallback? onPressed;

  const OtpGradientButton({
    super.key,
    required this.label,
    this.icon,
    this.isLoading = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final brandLight =
        AppColors.resolve(AppColors.brandLight, AppDarkColors.brandLight);
    const onBrand = Colors.white;

    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          gradient: disabled
              ? null
              : LinearGradient(
                  colors: [brand, brandLight],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          color: disabled ? AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle).withValues(alpha: 0.25) : null,
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: brand.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: disabled ? null : onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(onBrand),
                      ),
                    )
                  else if (icon != null)
                    Icon(icon, color: onBrand, size: 22),
                  if (isLoading || icon != null) const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: onBrand,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        letterSpacing: 0.2,
                      ),
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
}

class OrderOtpCard extends StatelessWidget {
  final String? otp;
  final OrderOtpMode mode;
  final bool verified;

  const OrderOtpCard({
    super.key,
    required this.otp,
    required this.mode,
    this.verified = false,
  });

  @override
  Widget build(BuildContext context) {
    final surface = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final success = AppColors.success;

    final title = mode == OrderOtpMode.pickup
        ? 'Code à présenter au restaurant'
        : 'Code de remise (livreur)';
    final subtitle = mode == OrderOtpMode.pickup
        ? 'Montrez ce code lors du retrait de votre commande.'
        : 'Communiquez ce code au livreur à la livraison.';
    final icon = mode == OrderOtpMode.pickup
        ? Icons.storefront_rounded
        : Icons.delivery_dining_rounded;

    final code = (otp ?? '').trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: verified ? success.withValues(alpha: 0.45) : border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (verified ? success : brand).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  verified ? Icons.verified_user_rounded : icon,
                  color: verified ? success : brand,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleSmall(color: ink)
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.bodyMedium(color: muted)
                          .copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (code.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                color: muted.withValues(alpha: 0.08),
                border: Border.all(color: border),
              ),
              child: Text(
                'Code indisponible',
                style: AppTypography.bodyMedium(color: muted),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                gradient: LinearGradient(
                  colors: [
                    (verified ? success : brand).withValues(alpha: 0.06),
                    (verified ? success : brand).withValues(alpha: 0.14),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: (verified ? success : brand).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < code.length; i++) ...[
                    _CodeChar(
                      code[i],
                      highlighted: verified
                          ? success
                          : brand,
                    ),
                    if (i != code.length - 1) const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 10),
          if (verified)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, color: success, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Code vérifié',
                  style: AppTypography.bodyMedium(color: success)
                      .copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: code.isNotEmpty
                        ? () async {
                            await Clipboard.setData(ClipboardData(text: code));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: ink,
                                  content: Text(
                                    'Code copié : $code',
                                    style: TextStyle(
                                      color: AppColors.resolve(
                                          AppColors.surface,
                                          AppDarkColors.surface),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded,
                              size: 16, color: muted),
                          const SizedBox(width: 6),
                          Text(
                            'Copier',
                            style: AppTypography.bodyMedium(color: muted)
                                .copyWith(fontSize: 12.5,
                                    fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CodeChar extends StatelessWidget {
  final String char;
  final Color highlighted;

  const _CodeChar(this.char, {required this.highlighted});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.resolve(Colors.white, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: highlighted.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: highlighted.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        char.toUpperCase(),
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          color: highlighted,
        ),
      ),
    );
  }
}

Future<bool?> showRestaurateurOtpDialog(
  BuildContext context, {
  required int orderId,
}) async {
  final formKey = GlobalKey<FormState>();
  final controller = TextEditingController();
  final focusNode = FocusNode();
  bool submitting = false;
  String? errorMsg;

  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
      final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
      final surface = AppColors.resolve(AppColors.surface, AppDarkColors.surface);
      final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
      final error = AppColors.error;

      return StatefulBuilder(
        builder: (ctx2, setDialogState) {
          return AlertDialog(
            backgroundColor: surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            title: Row(
              children: [
                Icon(Icons.lock_outline_rounded, color: brand, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Valider le retrait',
                    style: AppTypography.titleMedium(color: ink)
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saisissez le code à 4 caractères que le client vous présente.',
                    style: AppTypography.bodyMedium(color: muted),
                  ),
                  const SizedBox(height: 18),
                  PinCodeTextField(
                    appContext: ctx2,
                    length: 4,
                    controller: controller,
                    focusNode: focusNode,
                    autoFocus: true,
                    textStyle: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: brand,
                      letterSpacing: 1.5,
                    ),
                    pinTheme: PinTheme(
                      shape: PinCodeFieldShape.box,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      fieldHeight: 54,
                      fieldWidth: 46,
                      activeFillColor: Colors.transparent,
                      inactiveFillColor: Colors.transparent,
                      selectedFillColor: Colors.transparent,
                      activeColor: brand,
                      inactiveColor: muted.withValues(alpha: 0.4),
                      selectedColor: brand,
                      borderWidth: 1.3,
                    ),
                    enableActiveFill: false,
                    keyboardType: TextInputType.text,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9]'),
                      ),
                      UpperCaseTextFormatter(),
                    ],
                    onChanged: (_) {
                      if (errorMsg != null) {
                        setDialogState(() => errorMsg = null);
                      }
                    },
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              color: error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMsg!,
                              style: AppTypography.bodyMedium(color: error)
                                  .copyWith(fontSize: 13,
                                      fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting
                    ? null
                    : () => Navigator.of(ctx2).pop(false),
                child: Text(
                  'Annuler',
                  style: TextStyle(
                    color: muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: SizedBox(
                  width: 170,
                  child: OtpGradientButton(
                    label: submitting ? 'Vérification…' : 'Vérifier',
                    icon: submitting ? null : Icons.check_rounded,
                    isLoading: submitting,
                    onPressed: submitting
                        ? null
                        : () async {
                            final code = controller.text.trim().toUpperCase();
                            if (code.length != 4) {
                              setDialogState(() =>
                                  errorMsg = 'Le code doit comporter 4 caractères.');
                              return;
                            }
                            setDialogState(() {
                              submitting = true;
                              errorMsg = null;
                            });
                            try {
                              final ok = await CommandeApi.verifyPickupOtp(
                                orderId: orderId,
                                otp: code,
                              );
                              if (ok && ctx2.mounted) {
                                Navigator.of(ctx2).pop(true);
                              } else {
                                setDialogState(() {
                                  submitting = false;
                                  errorMsg = 'Code incorrect. Vérifiez et réessayez.';
                                });
                              }
                            } catch (e) {
                              setDialogState(() {
                                submitting = false;
                                errorMsg =
                                    'Erreur lors de la vérification : ${e.toString().split('\n').first}';
                              });
                            }
                          },
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  ).whenComplete(() {
    controller.dispose();
    focusNode.dispose();
  });
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

String? _otpOf(Commande c) {
  try {
    return (c as dynamic).retrievalOtp?.toString();
  } catch (_) {
    return null;
  }
}

bool _otpVerifiedOf(Commande c) {
  try {
    return (c as dynamic).isOtpVerified == true;
  } catch (_) {
    return false;
  }
}

bool _isPickupOrder(Commande c) =>
    orderOtpModeFrom(deliveryMode: c.deliveryMode) == OrderOtpMode.pickup;

class OrderTrackingPage extends StatefulWidget {
  final String? highlightedCommandeId;
  const OrderTrackingPage({super.key, this.highlightedCommandeId});
  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  bool isLoading = true;
  List<Commande> commandes = [];
  Map<int, Restaurant> restaurantById = {};
  String _country = 'RDC';
  StreamSubscription<Map<String, dynamic>>? _courierMovedSubscription;
  StreamSubscription<Map<String, dynamic>>? _deliveryStatusSubscription;
  final SocketService _socketService = SocketService();

  @override
  void initState() {
    super.initState();
    _load();
    _initSocket();
  }

  @override
  void dispose() {
    _courierMovedSubscription?.cancel();
    _deliveryStatusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initSocket() async {
    await _socketService.connect();

    _courierMovedSubscription = _socketService.onCourierMoved.listen((data) {
      final orderId = data['orderId']?.toString();
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (orderId != null && lat != null && lng != null && mounted) {
        setState(() {
          for (var i = 0; i < commandes.length; i++) {
            if (commandes[i].commandeID.toString() == orderId) {
              commandes[i].livreurLat = lat;
              commandes[i].livreurLng = lng;
              break;
            }
          }
        });
      }
    });

    _deliveryStatusSubscription =
        _socketService.onDeliveryStatusChanged.listen((data) {
      final orderId = data['orderId']?.toString();
      final newStatus = data['status']?.toString();
      if (orderId != null && newStatus != null && mounted) {
        setState(() {
          for (var i = 0; i < commandes.length; i++) {
            if (commandes[i].commandeID.toString() == orderId) {
              commandes[i].deliveryStatus = newStatus;
              break;
            }
          }
        });
      }
    });

    _joinActiveTrackingRooms();
  }

  void _joinActiveTrackingRooms() {
    for (final commande in commandes) {
      final status = DeliveryStatus.normalize(commande.deliveryStatus);
      if (status == DeliveryStatus.assigned ||
          status == DeliveryStatus.atPickup ||
          status == DeliveryStatus.pickedUp ||
          status == DeliveryStatus.inTransit) {
        _socketService.joinOrderTracking(commande.commandeID.toString());
      }
    }
  }

  Future<void> _load() async {
    final session = await SessionService.readSession();
    _country = session.country;
    try {
      await Commande.refreshLocalCommandes();
    } catch (_) {}
    final allC = await Commande.fetchCommandesFromDB();
    final restos = await Restaurant.fetchRestaurantsFromDB();
    final userC = allC.where((c) => c.userID == session.userId).toList()
      ..sort((a, b) => b.dateCommande.compareTo(a.dateCommande));
    if (!mounted) return;
    setState(() {
      commandes = userC;
      restaurantById = {for (final r in restos) r.restaurantID: r};
      isLoading = false;
    });

    _joinActiveTrackingRooms();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(l10n.order_tracking_title)),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: _load,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : commandes.isEmpty
                ? ListView(children: [
                    const SizedBox(height: 120),
                    Center(
                        child: Text("Aucune commande à suivre.",
                            style: AppTypography.bodyMedium())),
                  ])
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                    children: commandes.map(_buildCard).toList(),
                  ),
      ),
    );
  }

  Widget _buildCard(Commande c) {
    final resto = restaurantById[c.restauID];
    final status = CommandeStatus.normalize(c.status);
    final isHighlighted =
        widget.highlightedCommandeId == c.commandeID.toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CommandeDetailsPage(commande: c),
            ),
          ).then((_) => _load());
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isHighlighted
                ? AppColors.brandSurface.withValues(alpha: 0.5)
                : AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: isHighlighted
                  ? AppColors.brand.withValues(alpha: 0.3)
                  : AppColors.border,
              width: isHighlighted ? 1 : 0.5,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(
                    AppLocalizations.of(context)!.order_num(c.commandeID),
                    style: AppTypography.titleMedium()),
              ),
              _StatusChip(status: status),
            ]),
            const SizedBox(height: 8),
            Text(resto?.name ?? 'Restaurant inconnu',
                style: AppTypography.bodyMedium()),
            Text(
                '${c.dateCommande.toLocal().toString().split(" ")[0]} à ${c.heure}',
                style: AppTypography.bodyMedium(color: AppColors.inkSubtle)
                    .copyWith(fontSize: 12)),
            const SizedBox(height: 12),
            Text(_statusMessage(status, c),
                style: AppTypography.bodyMedium()),
            if (status != CommandeStatus.cancelled &&
                status != CommandeStatus.refused &&
                !_otpVerifiedOf(c) &&
                (_otpOf(c) ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              OrderOtpCard(
                otp: _otpOf(c),
                mode: orderOtpModeFrom(deliveryMode: c.deliveryMode),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                for (var i = 0; i < 5; i++) ...[
                  _Step(
                    _trackingLabels[i],
                    i <= _trackingStepIndex(c, status),
                    status == CommandeStatus.cancelled ||
                        status == CommandeStatus.refused,
                  ),
                  if (i < 4)
                    _StepConnector(i < _trackingStepIndex(c, status) &&
                        status != CommandeStatus.cancelled &&
                        status != CommandeStatus.refused),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(
                  AppLocalizations.of(context)!.delivery_cost(
                      CurrencyUtil.formatPrice(c.fraisLivraison, _country)),
                  style: AppTypography.bodyMedium().copyWith(fontSize: 12)),
              Text(
                  AppLocalizations.of(context)!.discount_amount(
                      CurrencyUtil.formatPrice(c.reduction, _country)),
                  style: AppTypography.bodyMedium().copyWith(fontSize: 12)),
            ]),
          ]),
        ),
      ),
    );
  }

  String _statusMessage(String s, Commande c) {
    final l10n = AppLocalizations.of(context)!;
    switch (s) {
      case CommandeStatus.pending:
        return l10n.tracking_pending_label;
      case CommandeStatus.paid:
        return l10n.tracking_paid_label;
      case CommandeStatus.confirmed:
        return l10n.tracking_confirmed_label;
      case CommandeStatus.preparing:
        return 'Le restaurant prépare votre commande.';
      case CommandeStatus.ready:
        return _isPickupOrder(c)
            ? 'Votre commande est prête. Présentez votre code au restaurateur.'
            : 'Votre commande est prête. Recherche d’un livreur en cours.';
      case CommandeStatus.delivered:
        return 'Commande livrée.';
      case CommandeStatus.refused:
        return 'Commande refusée par le restaurant.';
      case CommandeStatus.cancelled:
        return l10n.tracking_cancelled_label;
      default:
        return 'Statut mis à jour.';
    }
  }

  static const _trackingLabels = [
    'Créée',
    'Préparation',
    'Prête',
    'En livraison',
    'Livrée',
  ];

  int _trackingStepIndex(Commande commande, String status) {
    if (status == CommandeStatus.cancelled ||
        status == CommandeStatus.refused) {
      return -1;
    }
    final delivery = commande.deliveryStatus == null
        ? null
        : DeliveryStatus.normalize(commande.deliveryStatus);
    if (status == CommandeStatus.delivered ||
        delivery == DeliveryStatus.delivered) {
      return 4;
    }
    if (delivery == DeliveryStatus.inTransit) return 3;
    if (delivery == DeliveryStatus.pickedUp) return 3;
    if (delivery == DeliveryStatus.assigned ||
        delivery == DeliveryStatus.atPickup ||
        delivery == DeliveryStatus.searching ||
        status == CommandeStatus.ready) {
      return 2;
    }
    if (status == CommandeStatus.preparing) return 1;
    return 0;
  }

  Widget _Step(String label, bool done, bool cancelled) {
    final color = cancelled
        ? AppColors.error
        : done
            ? AppColors.success
            : AppColors.inkSubtle;
    return Expanded(
      child: Column(children: [
        Icon(
            done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: color,
            size: 24),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 11)),
      ]),
    );
  }

  Widget _StepConnector(bool active) => Expanded(
        child: Container(
            height: 2,
            color: active ? AppColors.success : AppColors.border),
      );
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});
  @override
  Widget build(BuildContext context) {
    final color = CommandeStatus.color(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99)),
      child: Text(status,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}
