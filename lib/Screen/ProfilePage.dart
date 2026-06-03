import 'package:dios_delices/modeles/users.dart';
import 'package:dios_delices/providers/data_version_notifier.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/strings.dart';
import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Users? _user;

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
    setState(() => _user = user);
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
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.brandSurface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.person_rounded,
                color: AppColors.brand, size: 18),
          ),
          const SizedBox(width: 10),
          Text(Strings.editProfileTitle,
              style: AppTypography.titleMedium().copyWith(fontSize: 16)),
        ]),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: firstnameCtrl,
              decoration: InputDecoration(
                labelText: Strings.firstName,
                prefixIcon:
                    const Icon(Icons.person_outline_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lastnameCtrl,
              decoration: InputDecoration(
                labelText: Strings.lastName,
                prefixIcon:
                    const Icon(Icons.person_outline_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: Strings.email,
                prefixIcon: const Icon(Icons.email_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: Strings.phone,
                prefixIcon: const Icon(Icons.phone_outlined, size: 20),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(Strings.cancel,
                style:
                    AppTypography.labelMedium(color: AppColors.inkMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (firstnameCtrl.text.trim().isEmpty ||
                  lastnameCtrl.text.trim().isEmpty ||
                  emailCtrl.text.trim().isEmpty ||
                  phoneCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(Strings.allFieldsRequired)));
                return;
              }
              final result = await Users.updateProfile(
                user.userID,
                firstname: firstnameCtrl.text.trim(),
                lastname: lastnameCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                telephone: phoneCtrl.text.trim(),
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx, result == 'success');
              if (result == 'success') {
                await _load();
              }
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(result == 'success'
                  ? Strings.profileUpdated
                  : result.toString()),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
              ));
            },
            child: Text(Strings.save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text(Strings.profile)),
      body: user == null
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
                    border: Border.all(
                        color: AppColors.border, width: 0.5),
                  ),
                  child: Column(children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.brandSurface,
                      child: Text(
                        '${user.firstname.isNotEmpty ? user.firstname[0] : ''}${user.lastname.isNotEmpty ? user.lastname[0] : ''}'
                            .toUpperCase(),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${user.firstname} ${user.lastname}',
                      style: AppTypography
                          .titleMedium()
                          .copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${user.username}',
                      style: AppTypography
                          .bodyMedium(color: AppColors.inkSubtle),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),

                // ── Informations ──────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                        color: AppColors.border, width: 0.5),
                  ),
                  child: Column(children: [
                    _infoTile(Icons.person_outline_rounded,
                        '${Strings.firstName} / ${Strings.lastName}',
                        '${user.firstname} ${user.lastname}'),
                    const Divider(height: 1, indent: 56),
                    _infoTile(Icons.email_outlined, Strings.email,
                        user.email),
                    const Divider(height: 1, indent: 56),
                    _infoTile(Icons.phone_outlined, Strings.phone,
                        user.telephone),
                  ]),
                ),
                const SizedBox(height: 24),

                // ── Modifier ──────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _showEditDialog,
                    icon: const Icon(Icons.edit_rounded, size: 20),
                    label: Text(Strings.modify),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: AppColors.brand),
      title: Text(label,
          style: AppTypography.bodyMedium(color: AppColors.inkSubtle)
              .copyWith(fontSize: 12)),
      subtitle: Text(value, style: AppTypography.labelMedium()),
    );
  }
}
