import 'dart:convert';
import 'dart:io';
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

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Users? _user;
  File? _newPhoto;
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
    final address = Address.getAddressByObject(addresses, 'user', session.userId);
    if (!mounted) return;
    setState(() {
      _user = user;
      _address = address?.fullAddress ?? '';
      _isAdmin = session.role.isAdmin;
    });
  }

  Future<void> _showEditDialog() async {
    final user = _user;
    if (user == null) return;

    final firstnameCtrl = TextEditingController(text: user.firstname);
    final lastnameCtrl = TextEditingController(text: user.lastname);
    final emailCtrl = TextEditingController(text: user.email);
    final phoneCtrl = TextEditingController(text: user.telephone);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.brandSurface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.person_rounded,
                color: AppColors.brand, size: 18),
          ),
          const SizedBox(width: 10),
          Text(AppLocalizations.of(ctx)!.editProfileTitle,
              style: AppTypography.titleMedium().copyWith(fontSize: 16)),
        ]),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              onTap: () async {
                final file = await pickAndConfirmImage(context);
                if (file != null) setState(() => _newPhoto = file);
              },
              child: Stack(children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: AppColors.brandSurface,
                  child: _newPhoto != null
                      ? ClipOval(child: Image.file(_newPhoto!, width: 84, height: 84, fit: BoxFit.cover))
                      : user.image.isNotEmpty
                          ? ClipOval(child: Image.memory(const Base64Decoder().convert(user.image), width: 84, height: 84, fit: BoxFit.cover))
                          : Text('${user.firstname.isNotEmpty ? user.firstname[0] : ''}${user.lastname.isNotEmpty ? user.lastname[0] : ''}'.toUpperCase(),
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.brand)),
                ),
                Positioned(bottom: 0, right: 0, child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: AppColors.brand, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                )),
              ]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: firstnameCtrl,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(ctx)!.firstName,
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lastnameCtrl,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(ctx)!.lastName,
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(ctx)!.email,
                prefixIcon: const Icon(Icons.email_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(ctx)!.phone,
                prefixIcon: const Icon(Icons.phone_outlined, size: 20),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(ctx)!.cancel,
                style: AppTypography.labelMedium(color: AppColors.inkMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (firstnameCtrl.text.trim().isEmpty ||
                  lastnameCtrl.text.trim().isEmpty ||
                  emailCtrl.text.trim().isEmpty ||
                  phoneCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(AppLocalizations.of(context)!.allFieldsRequired)));
                return;
              }
              final result = await Users.updateProfile(
                user.userID,
                firstname: firstnameCtrl.text.trim(),
                lastname: lastnameCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                telephone: phoneCtrl.text.trim(),
                image: _newPhoto != null ? base64Encode(_newPhoto!.readAsBytesSync()) : null,
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx, result == 'success');
              if (result == 'success') {
                await _load();
              }
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(result == 'success'
                    ? AppLocalizations.of(context)!.profileUpdated
                    : result.toString()),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
              ));
            },
            child: Text(AppLocalizations.of(context)!.save_profile),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = _user;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(l10n.myProfile)),
      body: SafeArea(
        child: user == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Avatar / En‑tête ──────────────────────
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Column(children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.brandSurface,
                        child: user.image.isNotEmpty
                            ? ClipOval(child: Image.memory(base64Decode(user.image), width: 80, height: 80, fit: BoxFit.cover))
                            : Text(
                                '${user.firstname.isNotEmpty ? user.firstname[0] : ''}${user.lastname.isNotEmpty ? user.lastname[0] : ''}'
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.brand,
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${user.firstname} ${user.lastname}',
                        style:
                            AppTypography.titleMedium().copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${user.username}',
                        style: AppTypography.bodyMedium(
                            color: AppColors.inkSubtle),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  // ── Informations ──────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Column(children: [
                      _infoTile(
                          Icons.person_outline_rounded,
                          '${l10n.firstName} / ${l10n.lastName}',
                          '${user.firstname} ${user.lastname}'),
                      const Divider(height: 1, indent: 56),
                      _infoTile(Icons.email_outlined, l10n.email, user.email),
                      const Divider(height: 1, indent: 56),
                      _infoTile(
                          Icons.phone_outlined, l10n.phone, user.telephone),
                      const Divider(height: 1, indent: 56),
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          leading: Icon(Icons.location_on_rounded,
                              color: AppColors.resolve(
                                  AppColors.brand, AppDarkColors.brand)),
                          title: Text(l10n.address,
                              style: AppTypography.bodyMedium().copyWith(
                                  color: AppColors.resolve(AppColors.inkSubtle,
                                      AppDarkColors.inkSubtle),
                                  fontSize: 12)),
                          subtitle: Text(
                              _address.isEmpty
                                  ? l10n.add_your_address
                                  : _address,
                              style: AppTypography.labelMedium().copyWith(
                                  color: AppColors.resolve(AppColors.inkMuted,
                                      AppDarkColors.inkMuted),
                                  fontSize: 12)),
                          trailing: Icon(Icons.chevron_right_rounded,
                              color: AppColors.resolve(AppColors.inkSubtle,
                                  AppDarkColors.inkSubtle),
                              size: 20),
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
                      )
                    ]),
                  ),
                  const SizedBox(height: 24),

                  // ── Mes commandes ─────────────────────────
                  if (!_isAdmin) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const UserOrdersPage(
                                  showRestaurantOrders: false),
                            ),
                          );
                        },
                        icon: const Icon(Icons.receipt_long_rounded, size: 20),
                        label: Text(l10n.myOrders),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // ── Adresse ────────────────────────────────

                  const SizedBox(height: 12),
                  // ── Modifier ──────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _showEditDialog,
                      icon: const Icon(Icons.edit_rounded, size: 20),
                      label: Text(l10n.editProfile),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: AppColors.brand),
        title: Text(label,
            style: AppTypography.bodyMedium(color: AppColors.inkSubtle)
                .copyWith(fontSize: 12)),
        subtitle: Text(value, style: AppTypography.labelMedium()),
      ),
    );
  }
}
