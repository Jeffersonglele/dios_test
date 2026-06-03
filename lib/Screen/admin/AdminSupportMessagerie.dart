import 'dart:convert';
import 'package:dios_delices/Screen/ChatScreen.dart';
import 'package:dios_delices/modeles/users.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';

class AdminSupportMessagerie extends StatefulWidget {
  final String country;
  const AdminSupportMessagerie({super.key, required this.country});

  @override
  State<AdminSupportMessagerie> createState() => _AdminSupportMessagerieState();
}

class _AdminSupportMessagerieState extends State<AdminSupportMessagerie> {
  List<Users> _users = [];
  List<Users> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final session = await SessionService.readSession();
    final all = await Users.fetchUsersFromDB();
    final countryUsers = all.where((u) =>
        u.country == widget.country &&
        u.userID != session.userId &&
        u.roleID != 1 &&
        u.roleID != 4).toList();
    if (mounted) {
      setState(() {
        _users = countryUsers;
        _filtered = countryUsers;
        _loading = false;
      });
    }
  }

  void _search(String q) {
    final query = q.toLowerCase();
    setState(() {
      _filtered = _users.where((u) =>
          u.firstname.toLowerCase().contains(query) ||
          u.lastname.toLowerCase().contains(query) ||
          u.username.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query)).toList();
    });
  }

  String _roleLabel(int id) =>
      ['', 'Admin', 'Client', 'Restaurateur', 'Super Admin', 'Livreur']
          [id >= 0 && id <= 5 ? id : 0];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      appBar: AppBar(
        title: Text('Support Messagerie — ${widget.country}',
            style: AppTypography.titleMedium()),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: AppTypography.bodyLarge(),
                decoration: InputDecoration(
                  hintText: 'Rechercher un utilisateur…',
                  hintStyle: AppTypography.bodyMedium(
                      color: AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle)),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: _search,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline_rounded,
                                size: 64,
                                color: AppColors.resolve(AppColors.border, AppDarkColors.border)),
                            const SizedBox(height: 16),
                            Text('Aucun utilisateur trouvé.',
                                style: AppTypography.bodyMedium()),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final u = _filtered[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: AppColors.resolve(AppColors.card, AppDarkColors.card),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(
                                  color: AppColors.resolve(AppColors.border, AppDarkColors.border),
                                  width: 0.5),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                              leading: CircleAvatar(
                                backgroundColor: AppColors.resolve(
                                    AppColors.brandSurface, AppDarkColors.brandSurface),
                                child: u.image.isNotEmpty
                                    ? ClipOval(
                                        child: Image.memory(
                                          const Base64Decoder().convert(u.image),
                                          width: 40, height: 40, fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Text(
                                            '${u.firstname.isNotEmpty ? u.firstname[0] : ''}${u.lastname.isNotEmpty ? u.lastname[0] : ''}',
                                            style: AppTypography.labelMedium(
                                                color: AppColors.resolve(
                                                    AppColors.brand, AppDarkColors.brand)),
                                          ),
                                        ),
                                      )
                                    : Text(
                                        '${u.firstname.isNotEmpty ? u.firstname[0] : ''}${u.lastname.isNotEmpty ? u.lastname[0] : ''}',
                                        style: AppTypography.labelMedium(
                                            color: AppColors.resolve(
                                                AppColors.brand, AppDarkColors.brand)),
                                      ),
                              ),
                              title: Text('${u.firstname} ${u.lastname}',
                                  style: AppTypography.bodyLarge().copyWith(fontSize: 14)),
                              subtitle: Text(
                                '${u.email} · ${_roleLabel(u.roleID)}',
                                style: AppTypography.bodyMedium().copyWith(fontSize: 11),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.resolve(
                                      AppColors.brandSurface, AppDarkColors.brandSurface),
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Icon(Icons.chat_rounded,
                                    size: 18,
                                    color: AppColors.resolve(AppColors.brand, AppDarkColors.brand)),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      withUserID: u.userID,
                                      withUsername: '${u.firstname} ${u.lastname}',
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
