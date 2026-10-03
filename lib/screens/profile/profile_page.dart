import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/models/address.dart';
import 'package:dios_delices/models/users.dart';
import 'package:dios_delices/providers/data_version_notifier.dart';
import 'package:dios_delices/screens/orders/user_orders_page.dart';
import 'package:dios_delices/screens/profile/location_page.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/image_picker_helper.dart';
import 'package:dios_delices/widgets/dios_image.dart';
import 'package:dios_delices/widgets/swirling_loader.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/currency_service.dart';
import '../../utils/currency_util.dart';

// ═══════════════════════════════════════════════════════════
// Raccourcis couleurs 
// ═══════════════════════════════════════════════════════════
class _PC {
  static Color get brand =>
      AppColors.resolve(AppColors.brand, AppDarkColors.brand);
  static Color get brandSurface =>
      AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface);
  static Color get surface =>
      AppColors.resolve(AppColors.surface, AppDarkColors.surface);
  static Color get card => AppColors.resolve(AppColors.card, AppDarkColors.card);
  static Color get border =>
      AppColors.resolve(AppColors.border, AppDarkColors.border);
  static Color get ink => AppColors.resolve(AppColors.ink, AppDarkColors.ink);
  static Color get inkMuted =>
      AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
  static Color get inkSubtle =>
      AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle);
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Users? _user;
  String _address = '';
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    dataVersionNotifier.addListener(_onDataChanged);
    _load();
  }

  @override
  void dispose() {
    dataVersionNotifier.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final session = await SessionService.readSession();
    final users = await Users.fetchUsersFromDB();
    final user = Users.getUsersByUserId(users, session.userId);
    if (!mounted) return;
    final addresses = await Address.fetchAddressesFromDB();
    final address =
        Address.getAddressByObject(addresses, 'User', session.userId);
    if (!mounted) return;
    setState(() {
      _user = user;
      _address = address?.fullAddress ?? '';
      _isAdmin = session.role.isAdmin;
    });
  }

  // ───────────────────────────────────────────────────────
  // Écran bloqué avec Swirling pendant une tâche
  // ───────────────────────────────────────────────────────
  /// Affiche un voile plein écran (non fermable) avec [Swirling] le temps
  /// que [task] se termine, puis le retire. Durée minimale 700 ms pour un
  /// rendu posé (pas de clignotement si la tâche est quasi instantanée).
  Future<T> _runBlocking<T>(Future<T> Function() task) async {
    final nav = Navigator.of(context, rootNavigator: true);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      pageBuilder: (_, __, ___) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: _PC.card,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Center(
              child: Swirling(size: 64, color: _PC.brand),
            ),
          ),
        ),
      ),
    );

    try {
      final results = await Future.wait<dynamic>([
        task(),
        Future<void>.delayed(const Duration(milliseconds: 700)),
      ]);
      return results[0] as T;
    } finally {
      if (nav.canPop()) nav.pop();
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md)),
    ));
  }

  Future<void> _showCurrencyPicker() async {
    final svc = CurrencyService.instance;
    final all = svc.availableCurrencies;
    final active = svc.activeCurrency;
    final auto = svc.isAutoCurrency;
    final detected = svc.detectedCurrency;
    final sheet = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: _PC.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 42, height: 4, decoration: BoxDecoration(color: _PC.border, borderRadius: BorderRadius.circular(4))),
            SizedBox(height: 16),
            ListTile(
              leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: _PC.brandSurface, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.auto_awesome_rounded, color: _PC.brand, size: 20)),
              title: Text('Automatique (détectée)'),
              subtitle: Text(auto ? 'Actif : ${detected} (${CurrencyUtil.symbol(detected)})' : 'Detected: ${detected}'),
              trailing: auto ? Icon(Icons.check_circle_rounded, color: _PC.brand) : null,
              onTap: () => Navigator.pop(ctx, '__auto__'),
            ),
            Divider(height: 1, indent: 72, color: _PC.border),
            ...all.map((c) {
              final selected = !auto && c == active;
              return ListTile(
                title: Text('${c.toUpperCase()}  (${CurrencyUtil.symbol(c)})'),
                trailing: selected ? Icon(Icons.check_circle_rounded, color: _PC.brand) : null,
                onTap: () => Navigator.pop(ctx, c),
              );
            }),
            SizedBox(height: 8),
          ])),
        );
      },
    );
    if (!mounted || sheet == null) return;
    if (sheet == '__auto__') { await svc.setPreferredCurrency(null); }
    else { await svc.setPreferredCurrency(sheet); }
  }

  String _currentCurrencyLabel() {
    final svc = CurrencyService.instance;
    if (svc.isAutoCurrency) {
      final d = svc.detectedCurrency;
      return 'Auto (${d.toUpperCase()} · ${CurrencyUtil.symbol(d)})';
    }
    final c = svc.activeCurrency;
    return '${c.toUpperCase()} (${CurrencyUtil.symbol(c)})';
  }

  // ───────────────────────────────────────────────────────
  // Changement rapide de photo (depuis l'avatar)
  // ───────────────────────────────────────────────────────
  Future<void> _changePhotoQuick() async {
    final user = _user;
    if (user == null) return;
    final file = await pickAndConfirmImage(context);
    if (file == null || !mounted) return;

    final result = await _runBlocking<String>(() async {
      final b64 = base64Encode(await file.readAsBytes());
      final res = await Users.updateProfile(
        user.userID,
        firstname: user.firstname,
        lastname: user.lastname,
        email: user.email,
        telephone: user.telephone,
        image: b64,
      );
      final ok = res == 'success';
      if (ok) await _load();
      return ok ? 'success' : res.toString();
    });

    if (!mounted) return;
    _snack(result == 'success'
        ? AppLocalizations.of(context)!.profileUpdated
        : result);
  }

  // ───────────────────────────────────────────────────────
  // Édition complète (bottom sheet)
  // ───────────────────────────────────────────────────────
  Future<void> _showEditSheet() async {
    final user = _user;
    if (user == null) return;

    final firstnameCtrl = TextEditingController(text: user.firstname);
    final lastnameCtrl = TextEditingController(text: user.lastname);
    final emailCtrl = TextEditingController(text: user.email);
    final phoneCtrl = TextEditingController(text: user.telephone);
    XFile? sheetPhoto;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: _PC.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // poignée
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _PC.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _PC.brandSurface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.edit_rounded,
                              color: _PC.brand, size: 19),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(l10n.editProfileTitle,
                              style: AppTypography.titleMedium(color: _PC.ink)
                                  .copyWith(fontSize: 18)),
                        ),
                      ]),
                      const SizedBox(height: 20),

                      // Photo
                      GestureDetector(
                        onTap: () async {
                          final file = await pickAndConfirmImage(ctx);
                          if (file == null) return;
                          if (!ctx.mounted) return;
                          // Écran bloqué le temps de préparer l'aperçu
                          await _runBlocking<void>(() async {
                            await file.readAsBytes();
                          });
                          if (!ctx.mounted) return;
                          setSheet(() => sheetPhoto = file);
                        },
                        child: Stack(children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: _PC.brand, width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 44,
                              backgroundColor: _PC.brandSurface,
                              child: sheetPhoto != null
                                  ? ClipOval(
                                      child: pickedImagePreview(sheetPhoto!,
                                          width: 88,
                                          height: 88,
                                          fit: BoxFit.cover))
                                  : _buildUserAvatar(user, 88),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: _PC.brand,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: _PC.surface, width: 2.5),
                              ),
                              child: const Icon(Icons.camera_alt_rounded,
                                  color: Colors.white, size: 15),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 20),

                      _field(firstnameCtrl, l10n.firstName,
                          Icons.person_outline_rounded),
                      const SizedBox(height: 12),
                      _field(lastnameCtrl, l10n.lastName,
                          Icons.person_outline_rounded),
                      const SizedBox(height: 12),
                      _field(emailCtrl, l10n.email, Icons.email_outlined,
                          type: TextInputType.emailAddress),
                      const SizedBox(height: 12),
                      _field(phoneCtrl, l10n.phone, Icons.phone_outlined,
                          type: TextInputType.phone),
                      const SizedBox(height: 22),

                      Row(children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(l10n.cancel),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (firstnameCtrl.text.trim().isEmpty ||
                                    lastnameCtrl.text.trim().isEmpty ||
                                    emailCtrl.text.trim().isEmpty ||
                                    phoneCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                          content: Text(l10n.allFieldsRequired)));
                                  return;
                                }
                                FocusScope.of(ctx).unfocus();
                                final result = await _runBlocking<String>(
                                    () async {
                                  final res = await Users.updateProfile(
                                    user.userID,
                                    firstname: firstnameCtrl.text.trim(),
                                    lastname: lastnameCtrl.text.trim(),
                                    email: emailCtrl.text.trim(),
                                    telephone: phoneCtrl.text.trim(),
                                    image: sheetPhoto != null
                                        ? base64Encode(
                                            await sheetPhoto!.readAsBytes())
                                        : null,
                                  );
                                  final ok = res == 'success';
                                  if (ok) await _load();
                                  return ok ? 'success' : res.toString();
                                });
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (!mounted) return;
                                _snack(result == 'success'
                                    ? AppLocalizations.of(context)!
                                        .profileUpdated
                                    : result);
                              },
                              child: Text(l10n.save_profile),
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    firstnameCtrl.dispose();
    lastnameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {TextInputType? type}) {
    return TextField(
      controller: c,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: _PC.brand),
        filled: true,
        fillColor: _PC.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: _PC.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: _PC.border, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: _PC.brand, width: 1.5),
        ),
      ),
    );
  }

  String _initials(Users u) =>
      '${u.firstname.isNotEmpty ? u.firstname[0] : ''}${u.lastname.isNotEmpty ? u.lastname[0] : ''}'
          .toUpperCase();

  Widget _buildUserAvatar(Users user, double size) {
    final raw = user.image.trim();
    final isUrl = raw.startsWith('http://') ||
        raw.startsWith('https://') ||
        raw.startsWith('/') ||
        raw.startsWith('file://') ||
        raw.startsWith('/data/') ||
        raw.startsWith('/storage/');
    if (isUrl) {
      return ClipOval(
        child: DiosImage(url: raw, width: size, height: size, fit: BoxFit.cover),
      );
    }
    if (raw.isNotEmpty) {
      try {
        return ClipOval(
          child: Image.memory(
            base64Decode(raw),
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {}
    }
    return Text(_initials(user),
        style: TextStyle(
            fontSize: size * 0.318,
            fontWeight: FontWeight.bold,
            color: _PC.brand));
  }

  // ───────────────────────────────────────────────────────
  // Page
  // ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = _user;

    return Scaffold(
      backgroundColor: _PC.surface,
      appBar: AppBar(
        title: Text(l10n.myProfile),
        centerTitle: true,
        backgroundColor: _PC.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: user == null
            ? Center(child: Swirling(size: 56, color: _PC.brand))
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _reveal(0, _header(user)),
                  const SizedBox(height: 20),
                  _reveal(
                    1,
                    _card(Column(children: [
                      _infoTile(
                          Icons.person_outline_rounded,
                          '${l10n.firstName} / ${l10n.lastName}',
                          '${user.firstname} ${user.lastname}'),
                      _divider(),
                      _infoTile(Icons.email_outlined, l10n.email, user.email),
                      _divider(),
                      _infoTile(
                          Icons.phone_outlined, l10n.phone, user.telephone),
                      _divider(),
                      _infoTile(
                        Icons.location_on_rounded,
                        l10n.address,
                        _address.isEmpty ? l10n.add_your_address : _address,
                        muted: _address.isEmpty,
                        onTap: () async {
                          final session = await SessionService.readSession();
                          if (!mounted) return;
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) => LocationPage(
                                objectID: session.userId,
                                user_roleID: session.role.id,
                              ),
                            ),
                          );
                          _load();
                        },
                      ),
                      _divider(),
                      AnimatedBuilder(
                        animation: CurrencyService.instance,
                        builder: (_, __) => _infoTile(
                          Icons.currency_exchange_rounded,
                          'Devise d\'affichage',
                          _currentCurrencyLabel(),
                          onTap: _showCurrencyPicker,
                        ),
                      ),
                    ])),
                  ),
                  const SizedBox(height: 22),
                  if (!_isAdmin)
                    _reveal(
                      2,
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _PC.brand,
                              side: BorderSide(
                                  color: _PC.brand.withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.lg)),
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const UserOrdersPage(
                                    showRestaurantOrders: false),
                              ),
                            ),
                            icon: const Icon(Icons.receipt_long_rounded,
                                size: 20),
                            label: Text(l10n.myOrders),
                          ),
                        ),
                      ),
                    ),
                  _reveal(
                    3,
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.lg)),
                        ),
                        onPressed: _showEditSheet,
                        icon: const Icon(Icons.edit_rounded, size: 20),
                        label: Text(l10n.editProfile),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Widgets de page ─────────────────────────────────────
  Widget _reveal(int index, Widget child) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 380 + index * 90),
        curve: Curves.easeOutCubic,
        builder: (_, v, c) => Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: c),
        ),
        child: child,
      );

  Uint8List? _decodePhoto(String b64) {
    if (b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  /// En-tête façon « profil réseau social » : la photo de l'utilisateur,
  /// floutée, sert de fond ; une carte aux coins arrondis la chevauche et
  /// l'avatar net est posé à cheval entre les deux.
  /// Sans photo → dégradé de la couleur de marque.
  Widget _header(Users user) {
    final bytes = _decodePhoto(user.image);
    const backdropH = 200.0;
    const cardTop = 150.0;
    const avatarR = 48.0;

    final Widget backdrop = bytes != null
        ? Stack(fit: StackFit.expand, children: [
            // Photo agrandie + floutée (mirror = pas de bords transparents)
            ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                    sigmaX: 22, sigmaY: 22, tileMode: TileMode.mirror),
                child: Transform.scale(
                  scale: 1.35,
                  child: Image.memory(bytes,
                      fit: BoxFit.cover, gaplessPlayback: true),
                ),
              ),
            ),
            // Voile pour garder le contraste + teinte de marque
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.10),
                    _PC.brand.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ])
        : Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_PC.brand, _PC.brand.withValues(alpha: 0.75)],
              ),
            ),
            child: Stack(children: [
              Positioned(
                right: -20,
                top: -30,
                child: _bubble(140, Colors.white.withValues(alpha: 0.09)),
              ),
              Positioned(
                left: -16,
                top: 70,
                child: _bubble(100, Colors.black.withValues(alpha: 0.06)),
              ),
            ]),
          );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: _PC.ink.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Fond flouté ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: backdropH,
            child: backdrop,
          ),

          // ── Carte qui chevauche ──
          Column(
            children: [
              const SizedBox(height: cardTop),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _PC.card,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                padding: const EdgeInsets.fromLTRB(20, avatarR + 16, 20, 24),
                child: Column(children: [
                  Text(
                    '${user.firstname} ${user.lastname}',
                    textAlign: TextAlign.center,
                    style: AppTypography.titleMedium(color: _PC.ink)
                        .copyWith(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  if (_address.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 15, color: _PC.brand),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium(
                                    color: _PC.inkSubtle)
                                .copyWith(fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _PC.brandSurface,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('@${user.username}',
                        style: AppTypography.labelMedium(color: _PC.brand)),
                  ),
                ]),
              ),
            ],
          ),

          // ── Avatar net, à cheval fond / carte ──
          Positioned(
            top: cardTop - avatarR - 4,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _changePhotoQuick,
                child: Stack(children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _PC.card,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.20),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: avatarR,
                      backgroundColor: _PC.brandSurface,
                      child: bytes != null
                          ? ClipOval(
                              child: Image.memory(bytes,
                                  width: avatarR * 2,
                                  height: avatarR * 2,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true))
                          : Text(_initials(user),
                              style: AppTypography.titleMedium(color: _PC.brand)
                                  .copyWith(fontSize: 28)),
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _PC.brand,
                        shape: BoxShape.circle,
                        border: Border.all(color: _PC.card, width: 3),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 15),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  Widget _card(Widget child) => Container(
        decoration: BoxDecoration(
          color: _PC.card,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: _PC.border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: _PC.ink.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );

  Widget _divider() => Divider(height: 1, indent: 72, color: _PC.border);

  Widget _infoTile(IconData icon, String label, String value,
      {VoidCallback? onTap, bool muted = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _PC.brandSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _PC.brand, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTypography.bodyMedium(color: _PC.inkSubtle)
                          .copyWith(fontSize: 12)),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelMedium(
                            color: muted ? _PC.inkMuted : _PC.ink)
                        .copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded,
                  color: _PC.inkSubtle, size: 22),
          ]),
        ),
      ),
    );
  }
}