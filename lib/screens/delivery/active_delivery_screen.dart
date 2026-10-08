import 'dart:async';
import 'dart:io';

import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/widgets/order_otp_widgets.dart'
    show OtpGradientButton;
import 'package:dios_delices/widgets/swirling_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/delivery_orders_service.dart';

/// Résultat renvoyé à l'écran précédent (Navigator.pop).
enum ActiveDeliveryResult { delivered, clientUnreachable }

/// Course active côté livreur : arrivée → chrono de 10 min → photo + code OTP
/// → « Valider la livraison », ou « Client injoignable » à l'expiration.
///
///  uploadPhoto : votre service d'upload (File → URL de la photo)
class ActiveDeliveryScreen extends StatefulWidget {
  const ActiveDeliveryScreen({
    super.key,
    required this.orderId,
    required this.uploadPhoto,
    this.clientName,
    this.restaurantName,
    this.dropoffAddress,
    this.waitSeconds = 600,
  });

  final int orderId;
  final Future<String> Function(File photo) uploadPhoto;
  final String? clientName;
  final String? restaurantName;
  final String? dropoffAddress;

  /// Durée d'attente accordée au client (600 s = 10 min).
  final int waitSeconds;

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  final _otpCtrl = TextEditingController();
  final _otpFocus = FocusNode();
  final _picker = ImagePicker();

  bool _ready = false; // lecture de l'arrivée mémorisée terminée
  bool _busy = false; // appel API en cours (écran bloqué)
  bool _uploading = false;
  DateTime? _arrivedAt;
  int _remaining = 0;
  Timer? _ticker;

  File? _photo;
  String? _photoUrl;
  String? _otpError;

  String get _orderKey => widget.orderId.toString();
  String get _prefsKey => 'arrival_at_$_orderKey';

  bool get _arrived => _arrivedAt != null;
  bool get _expired => _arrived && _remaining <= 0;
  bool get _canValidate =>
      _arrived &&
      !_expired &&
      !_busy &&
      !_uploading &&
      _photoUrl != null &&
      _otpCtrl.text.length == 4;

  @override
  void initState() {
    super.initState();
    _restoreArrival();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _otpCtrl.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  // ── Arrivée mémorisée : le chrono survit à la fermeture de l'écran ──
  Future<void> _restoreArrival() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      final at = raw == null ? null : DateTime.tryParse(raw);
      if (at != null) _startTicker(at);
    } catch (_) {}
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _rememberArrival(DateTime at) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, at.toIso8601String());
    } catch (_) {}
  }

  Future<void> _forgetArrival() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }

  // ── Chronomètre (calculé sur l'heure d'arrivée : exact même après veille) ──
  void _startTicker(DateTime arrivedAt) {
    _arrivedAt = arrivedAt;
    _tick();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final at = _arrivedAt;
    if (at == null) return;
    final deadline = at.add(Duration(seconds: widget.waitSeconds));
    final ms = deadline.difference(DateTime.now()).inMilliseconds;
    final rem = (ms / 1000).ceil().clamp(0, widget.waitSeconds);
    if (rem <= 0) {
      _ticker?.cancel();
      FocusManager.instance.primaryFocus?.unfocus();
    }
    if (mounted) setState(() => _remaining = rem);
  }

  String get _mmss {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Actions ─────────────────────────────────────────────
  Future<void> _arrive() async {
    setState(() => _busy = true);
    try {
      final serverTime = await DeliveryOrdersService.arrive(_orderKey);
      final now = DateTime.now();
      // heure du serveur si plausible (pas dans le futur), sinon maintenant
      final at = (serverTime != null && !serverTime.isAfter(now))
          ? serverTime
          : now;
      await _rememberArrival(at);
      if (!mounted) return;
      _startTicker(at);
    } on DeliveryException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Impossible de confirmer votre arrivée. Réessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _takePhoto() async {
    if (_expired || _busy || _uploading) return;
    XFile? shot;
    try {
      shot = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1600,
      );
    } catch (_) {
      _snack("Impossible d'ouvrir la caméra. Vérifiez l'autorisation.");
      return;
    }
    if (shot == null || !mounted) return;

    final file = File(shot.path);
    setState(() {
      _photo = file;
      _photoUrl = null;
      _uploading = true;
    });
    try {
      final url = await widget.uploadPhoto(file);
      if (!mounted) return;
      setState(() => _photoUrl = url);
    } catch (_) {
      _snack("Échec de l'envoi de la photo. Reprenez-la.");
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _validate() async {
    if (!_canValidate) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _otpError = null;
    });
    try {
      await DeliveryOrdersService.verifyRetrieval(
        _orderKey,
        otp: _otpCtrl.text,
        proofPhotoUrl: _photoUrl!,
      );
      await _forgetArrival();
      if (!mounted) return;
      Navigator.of(context).pop(ActiveDeliveryResult.delivered);
    } on DeliveryException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _otpError = e.message;
      });
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('La validation a échoué. Réessayez.');
    }
  }

  Future<void> _clientUnreachable() async {
    setState(() => _busy = true);
    try {
      await DeliveryOrdersService.clientUnreachable(_orderKey);
      await _forgetArrival();
      if (!mounted) return;
      Navigator.of(context).pop(ActiveDeliveryResult.clientUnreachable);
    } on DeliveryException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Impossible de clôturer la course. Réessayez.');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: AppColors.error,
        content: Text(msg),
      ));
  }

  // ── UI ──────────────────────────────────────────────────
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
        title: Text('Course #${widget.orderId}',
            style: AppTypography.titleMedium(color: ink)
                .copyWith(fontWeight: FontWeight.w800)),
      ),
      body: Stack(
        children: [
          if (!_ready)
            Center(child: Swirling(size: 52, color: AppColors.brand))
          else
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _infoCard(),
                  const SizedBox(height: 18),
                  if (!_arrived) _arriveSection() else ..._closingSection(),
                ],
              ),
            ),
          // écran bloqué pendant un appel API
          if (_busy)
            Positioned.fill(
              child: ColoredBox(
                color: surface.withValues(alpha: 0.7),
                child: Center(
                  child: Swirling(size: 56, color: AppColors.brand),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoCard() {
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);

    Widget row(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: muted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  Text(value,
                      style: TextStyle(
                          color: ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ]),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border, width: 0.6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: brand.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.delivery_dining_rounded, color: brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Livraison en cours',
                style: AppTypography.titleMedium(color: ink)
                    .copyWith(fontWeight: FontWeight.w800)),
          ),
        ]),
        if (widget.restaurantName != null)
          row(Icons.storefront_rounded, 'Restaurant', widget.restaurantName!),
        if (widget.clientName != null)
          row(Icons.person_outline_rounded, 'Client', widget.clientName!),
        if (widget.dropoffAddress != null)
          row(Icons.location_on_outlined, 'Adresse de livraison',
              widget.dropoffAddress!),
      ]),
    );
  }

  // ── Étape 1 : « Je suis arrivé » ────────────────────────
  Widget _arriveSection() {
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    return Column(children: [
      const SizedBox(height: 8),
      Text(
        'Une fois devant chez le client, confirmez votre arrivée. '
        'Vous aurez ${widget.waitSeconds ~/ 60} minutes pour le retrouver.',
        textAlign: TextAlign.center,
        style: AppTypography.bodyMedium(color: muted).copyWith(height: 1.4),
      ),
      const SizedBox(height: 20),
      OtpGradientButton(
        label: 'Je suis arrivé',
        icon: Icons.flag_rounded,
        isLoading: _busy,
        onPressed: _busy ? null : _arrive,
      ),
    ]);
  }

  // ── Étape 2 : chrono + photo + code ─────────────────────
  List<Widget> _closingSection() {
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final urgent = _expired || _remaining <= 60;
    final timerColor = urgent ? AppColors.error : brand;

    return [
      // Chronomètre
      Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: timerColor.withValues(alpha: 0.35), width: 1),
        ),
        child: Column(children: [
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: _remaining / widget.waitSeconds,
                  strokeWidth: 9,
                  strokeCap: StrokeCap.round,
                  color: timerColor,
                  backgroundColor: timerColor.withValues(alpha: 0.12),
                ),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_mmss,
                    style: TextStyle(
                        color: timerColor,
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()])),
                Text(_expired ? 'Temps écoulé' : 'Temps restant',
                    style: TextStyle(
                        color: muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 18),

      // Photo de preuve
      _sectionTitle('1. Photo de preuve', ink),
      const SizedBox(height: 8),
      _photoBox(card, border, muted, brand),
      const SizedBox(height: 18),

      // Code OTP
      _sectionTitle('2. Code du client', ink),
      const SizedBox(height: 8),
      TextField(
        controller: _otpCtrl,
        focusNode: _otpFocus,
        enabled: !_expired && !_busy,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.characters,
        keyboardType: TextInputType.visiblePassword, // clavier alphanumérique
        autocorrect: false,
        enableSuggestions: false,
        maxLength: 4,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
          _UpperCaseFormatter(),
        ],
        onChanged: (_) => setState(() => _otpError = null),
        onSubmitted: (_) => _validate(),
        style: TextStyle(
          color: ink,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: 12,
        ),
        decoration: InputDecoration(
          counterText: '',
          hintText: '••••',
          errorText: _otpError,
          filled: true,
          fillColor: _expired ? border.withValues(alpha: 0.4) : card,
          prefixIcon: _expired
              ? const Icon(Icons.lock_rounded, color: AppColors.error)
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: brand, width: 1.6),
          ),
        ),
      ),
      const SizedBox(height: 22),

      // Validation / expiration
      if (!_expired)
        OtpGradientButton(
          label: 'Valider la livraison',
          icon: Icons.check_circle_outline_rounded,
          isLoading: _busy,
          onPressed: _canValidate ? _validate : null,
        )
      else ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(children: [
            Icon(Icons.timer_off_rounded, color: AppColors.error),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Le délai d'attente est écoulé. Le code ne peut plus être saisi.",
                style: TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        _DangerButton(
          label: 'Clôturer - Client injoignable',
          icon: Icons.person_off_rounded,
          onPressed: _busy ? null : _clientUnreachable,
        ),
      ],
    ];
  }

  Widget _sectionTitle(String t, Color ink) => Text(t,
      style: AppTypography.titleMedium(color: ink)
          .copyWith(fontWeight: FontWeight.w800, fontSize: 15));

  Widget _photoBox(Color card, Color border, Color muted, Color brand) {
    final canShoot = !_expired && !_busy && !_uploading;

    if (_photo == null) {
      return GestureDetector(
        onTap: canShoot ? _takePhoto : null,
        child: Container(
          height: 130,
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: brand.withValues(alpha: 0.5), width: 1.4),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.photo_camera_rounded,
                size: 34, color: canShoot ? brand : muted),
            const SizedBox(height: 8),
            Text('Prendre la photo (obligatoire)',
                style: TextStyle(
                    color: canShoot ? brand : muted,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 0.6),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(_photo!, width: 96, height: 96, fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_uploading)
              Row(children: [
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Text('Envoi en cours…', style: TextStyle(color: muted)),
              ])
            else if (_photoUrl != null)
              const Row(children: [
                Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 18),
                SizedBox(width: 6),
                Text('Photo envoyée',
                    style: TextStyle(
                        color: AppColors.success, fontWeight: FontWeight.w700)),
              ])
            else
              const Row(children: [
                Icon(Icons.error_outline_rounded,
                    color: AppColors.error, size: 18),
                SizedBox(width: 6),
                Expanded(
                  child: Text('Envoi échoué : reprenez la photo',
                      style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: canShoot ? _takePhoto : null,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reprendre'),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Force les majuscules à la saisie.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

/// Bouton rouge plein (action destructive).
class _DangerButton extends StatelessWidget {
  const _DangerButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppColors.error,
            AppColors.error.withValues(alpha: 0.85),
          ]),
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withValues(alpha: 0.30),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
