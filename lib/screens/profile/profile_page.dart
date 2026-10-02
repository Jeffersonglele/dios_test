import 'dart:convert';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/models/users.dart';
import 'package:dios_delices/models/address.dart';
import 'package:dios_delices/providers/data_version_notifier.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/screens/profile/location_page.dart';
import 'package:dios_delices/screens/orders/user_orders_page.dart';
import 'package:dios_delices/utils/image_picker_helper.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Users? _user;
  XFile? _newPhoto;
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
    final address = Address.getAddressByObject(addresses, 'User', session.userId);
    if (!mounted) return;
    setState(() {
      _user = user;
      _address = address?.fullAddress ?? '';
      _isAdmin = session.role.isAdmin;
    });
  }

  Widget _buildAvatarImage(String imageStr, String initials, {double size = 80}) {
    final trimmed = imageStr.trim();
    if (trimmed.isNotEmpty) {
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return ClipOval(
          child: Image.network(trimmed, width: size, height: size, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initialsWidget(initials, size)),
        );
      }
      try {
        return ClipOval(
          child: Image.memory(base64Decode(trimmed), width: size, height: size,
              fit: BoxFit.cover, errorBuilder: (_, __, ___) => _initialsWidget(initials, size)),
        );
      } catch (_) {}
    }
    return _initialsWidget(initials, size);
  }

  Widget _initialsWidget(String initials, double size) {
    return Text(initials.toUpperCase(),
        style: TextStyle(fontSize: size * 0.35, fontWeight: FontWeight.bold,
            color: AppColors.resolve(AppColors.brand, AppDarkColors.brand)));
  }

  Future<void> _showEditDialog() async {
    final user = _user;
    if (user == null) return;

    final firstnameCtrl = TextEditingController(text: user.firstname);
    final lastnameCtrl  = TextEditingController(text: user.lastname);
    final emailCtrl     = TextEditingController(text: user.email);
    final phoneCtrl     = TextEditingController(text: user.telephone);

    XFile? dialogPhoto = _newPhoto;
    bool isSaving = false;

    final savedOk = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (_, setDS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(Icons.person_rounded,
                  color: AppColors.resolve(AppColors.brand, AppDarkColors.brand), size: 18),
            ),
            const SizedBox(width: 10),
            Text(AppLocalizations.of(dialogCtx)!.editProfileTitle,
                style: AppTypography.titleMedium(
                    color: AppColors.resolve(AppColors.ink, AppDarkColors.ink)).copyWith(fontSize: 16)),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                onTap: isSaving ? null : () async {
                  final file = await pickAndConfirmImage(context);
                  if (file != null) {
                    setState(() => _newPhoto = file);
                    setDS(() => dialogPhoto = file);
                  }
                },
                child: Stack(children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface),
                    child: dialogPhoto != null
                        ? ClipOval(child: pickedImagePreview(dialogPhoto!, width: 84, height: 84, fit: BoxFit.cover))
                        : _buildAvatarImage(user.image,
                            '${user.firstname.isNotEmpty ? user.firstname[0] : ''}${user.lastname.isNotEmpty ? user.lastname[0] : ''}',
                            size: 84),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                          color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2)),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              TextField(controller: firstnameCtrl, enabled: !isSaving,
                  decoration: InputDecoration(labelText: AppLocalizations.of(dialogCtx)!.firstName,
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20))),
              const SizedBox(height: 12),
              TextField(controller: lastnameCtrl, enabled: !isSaving,
                  decoration: InputDecoration(labelText: AppLocalizations.of(dialogCtx)!.lastName,
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20))),
              const SizedBox(height: 12),
              TextField(controller: emailCtrl, enabled: !isSaving,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: AppLocalizations.of(dialogCtx)!.email,
                      prefixIcon: const Icon(Icons.email_outlined, size: 20))),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, enabled: !isSaving,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: AppLocalizations.of(dialogCtx)!.phone,
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20))),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogCtx, false),
              child: Text(AppLocalizations.of(dialogCtx)!.cancel,
                  style: AppTypography.labelMedium(
                      color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted))),
            ),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (firstnameCtrl.text.trim().isEmpty || lastnameCtrl.text.trim().isEmpty ||
                    emailCtrl.text.trim().isEmpty   || phoneCtrl.text.trim().isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context)!.allFieldsRequired)));
                  return;
                }

                setDS(() => isSaving = true);

                String? base64Image;
                final photoFile = _newPhoto;
                if (photoFile != null) {
                  try {
                    final bytes = await photoFile.readAsBytes();
                    final decoded = img.decodeImage(bytes);
                    if (decoded != null) {
                      final resized = img.copyResize(decoded, width: 256, height: 256);
                      base64Image = base64Encode(img.encodeJpg(resized, quality: 80));
                    } else {
                      base64Image = base64Encode(bytes);
                    }
                  } catch (e) {
                    setDS(() => isSaving = false);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Erreur image : $e")));
                    return;
                  }
                }

                final result = await Users.updateProfile(user.userID,
                    firstname: firstnameCtrl.text.trim(),
                    lastname: lastnameCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    telephone: phoneCtrl.text.trim(),
                    image: base64Image);

                if (!dialogCtx.mounted) return;
                Navigator.pop(dialogCtx, result == 'success');

                if (!mounted) return;
                if (result == 'success') {
                  setState(() => _newPhoto = null);
                  await _load();
                }
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(result == 'success'
                      ? AppLocalizations.of(context)!.profileUpdated
                      : result.toString()),
                  behavior: SnackBarBehavior.fixed,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.md))),
                ));
              },
              child: isSaving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(AppLocalizations.of(context)!.save_profile),
            ),
          ],
        ),
      ),
    );

    if (savedOk != true && mounted) setState(() => _newPhoto = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = _user;

    return Scaffold(
      backgroundColor: AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      appBar: AppBar(title: Text(l10n.myProfile)),
      body: SafeArea(
        child: user == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                // ── Avatar / En-tête ──────────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.resolve(AppColors.card, AppDarkColors.card),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.resolve(AppColors.border, AppDarkColors.border), width: 0.5),
                  ),
                  child: Column(children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.resolve(AppColors.brandSurface, AppDarkColors.brandSurface),
                      child: _buildAvatarImage(user.image,
                          '${user.firstname.isNotEmpty ? user.firstname[0] : ''}${user.lastname.isNotEmpty ? user.lastname[0] : ''}',
                          size: 80),
                    ),
                    const SizedBox(height: 12),
                    Text('${user.firstname} ${user.lastname}',
                        style: AppTypography.titleMedium(
                            color: AppColors.resolve(AppColors.ink, AppDarkColors.ink)).copyWith(fontSize: 18)),
                    const SizedBox(height: 4),
                    Text('@${user.username}',
                        style: AppTypography.bodyMedium(
                            color: AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle))),
                  ]),
                ),
                const SizedBox(height: 24),

                // ── Informations ──────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.resolve(AppColors.card, AppDarkColors.card),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.resolve(AppColors.border, AppDarkColors.border), width: 0.5),
                  ),
                  child: Column(children: [
                    _infoTile(Icons.person_outline_rounded,
                        '${l10n.firstName} / ${l10n.lastName}', '${user.firstname} ${user.lastname}'),
                    const Divider(height: 1, indent: 56),
                    _infoTile(Icons.email_outlined, l10n.email, user.email),
                    const Divider(height: 1, indent: 56),
                    _infoTile(Icons.phone_outlined, l10n.phone, user.telephone),
                    const Divider(height: 1, indent: 56),
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        leading: Icon(Icons.location_on_rounded,
                            color: AppColors.resolve(AppColors.brand, AppDarkColors.brand)),
                        title: Text(l10n.address,
                            style: AppTypography.bodyMedium().copyWith(
                                color: AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle), fontSize: 12)),
                        subtitle: Text(_address.isEmpty ? l10n.add_your_address : _address,
                            style: AppTypography.labelMedium().copyWith(
                                color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted), fontSize: 12)),
                        trailing: Icon(Icons.chevron_right_rounded,
                            color: AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle), size: 20),
                        onTap: () async {
                          final session = await SessionService.readSession();
                          if (!mounted) return;
                          await Navigator.push(context, MaterialPageRoute(
                            builder: (ctx) => LocationPage(objectID: session.userId, user_roleID: session.role.id),
                          ));
                          _load();
                        },
                      ),
                    )
                  ]),
                ),
                const SizedBox(height: 24),

                // ── Mes commandes ─────────────────────────
                if (!_isAdmin) ...[
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const UserOrdersPage(showRestaurantOrders: false))),
                      icon: const Icon(Icons.receipt_long_rounded, size: 20),
                      label: Text(l10n.myOrders),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),

                // ── Modifier ──────────────────────────────
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _showEditDialog,
                    icon: const Icon(Icons.edit_rounded, size: 20),
                    label: Text(l10n.editProfile),
                  ),
                ),
                const SizedBox(height: 40),
              ]),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: AppColors.resolve(AppColors.brand, AppDarkColors.brand)),
        title: Text(label,
            style: AppTypography.bodyMedium(
                color: AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle)).copyWith(fontSize: 12)),
        subtitle: Text(value, style: AppTypography.labelMedium()),
      ),
    );
  }
}
