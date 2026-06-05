import 'package:dios_delices/Screen/utilisateurs/UserDetails.dart';
import 'package:dios_delices/core/app_role.dart';
import 'package:dios_delices/providers/data_version_notifier.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../../modeles/users.dart';
import '../../modeles/identity.dart';
import '../../widgets/dios_image.dart';

class UsersListPage extends StatefulWidget {
  final String country;
  final List<int>? roleFilter;

  const UsersListPage({super.key, required this.country, this.roleFilter});

  @override
  _UsersListPageState createState() => _UsersListPageState();
}

enum _UserStatus { all, pending, verified, rejected }

class _UsersListPageState extends State<UsersListPage> {
  List<Map<String, dynamic>> filteredUsers = [];
  List<Identity> identities = [];
  List<Users> users = [];
  bool isLoading = true;
  _UserStatus filterStatus = _UserStatus.all;
  String sortBy = 'Nom';
  String searchQuery = '';
  int _currentUserId = 0;

  final TextEditingController _searchCtrl = TextEditingController();

  Future<bool> _sendEmailToUser(Users user, bool valid, [String? remark]) async {
    final recipientEmail = user?.email ?? 'adigbononrodicaa@gmail.com';
    final subject = valid
        ? '🎉 Bienvenue sur Dios Délices - Votre profil est validé !'
        : '❌ Mise à jour : Validation de votre profil sur Dios Délices';

    final messageText = valid
        ? 'Bonjour ${user?.firstname},\n\n'
            'Nous sommes ravis de vous informer que votre profil a été validé. '
            'Vous pouvez maintenant accéder à votre compte pour gérer votre profil et recevoir des commandes.\n\n'
            'Cordialement,\nL’équipe Dios Délices'
        : 'Bonjour ${user?.firstname},\n\n'
            'Nous regrettons de vous informer que votre profil n’a pas été validé suite à notre processus de vérification.\n\n'
            'Raison du rejet : ${remark ?? "Non spécifiée"}\n\n'
            'Pour plus d’informations, n’hésitez pas à nous contacter.\n\n'
            'Cordialement,\nL’équipe Dios Délices';

    final cloudFunction = ParseCloudFunction('sendEmail');
    try {
      await cloudFunction.execute(parameters: {
        'to': recipientEmail,
        'subject': subject,
        'text': messageText,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    dataVersionNotifier.addListener(_onDataChanged);
    _loadSession();
    loadData();
  }

  Future<void> _loadSession() async {
    final session = await SessionService.readSession();
    if (mounted) setState(() => _currentUserId = session.userId);
  }

  @override
  void dispose() {
    dataVersionNotifier.removeListener(_onDataChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) loadData();
  }

  Future<void> loadData() async {
    List<Identity> identityList = await Identity.fetchIdentitiesFromDB();
    List<Users> usersList = await Users.fetchUsersFromDB();

    setState(() {
      identities = identityList;
      users = usersList;
      filteredUsers = [];
      isLoading = true;
    });
    await _fetchUsersByCountry();
  }

  Future<void> _fetchUsersByCountry() async {
    for (var user in users) {
      if (user.userID == _currentUserId) continue;
      if (user.country == widget.country && (widget.roleFilter == null || widget.roleFilter!.contains(user.roleID))) {
        Identity? identity = Identity.getIdentityByUserId(identities, user.userID);
        setState(() {
          filteredUsers.add({"user": user, "identity": identity});
        });
      }
    }
    setState(() {
      isLoading = false;
    });
  }

  void _sortUsers(String criterion) {
    setState(() {
      sortBy = criterion;
      if (criterion == 'Nom') {
        filteredUsers.sort((a, b) => (a["user"] as Users).firstname.compareTo((b["user"] as Users).firstname));
      } else if (criterion == 'Username') {
        filteredUsers.sort((a, b) => (a["user"] as Users).username.compareTo((b["user"] as Users).username));
      }
    });
  }

  List<Map<String, dynamic>> get _filteredList {
    var list = filteredUsers;
    if (filterStatus == _UserStatus.pending) {
      list = list.where((item) {
        final u = item["user"] as Users;
        return u.identity != "Verified" && u.identity != "Rejected";
      }).toList();
    } else if (filterStatus == _UserStatus.verified) {
      list = list.where((item) => (item["user"] as Users).identity == "Verified").toList();
    } else if (filterStatus == _UserStatus.rejected) {
      list = list.where((item) => (item["user"] as Users).identity == "Rejected").toList();
    }
    if (searchQuery.isNotEmpty) {
      list = list.where((item) {
        final user = item["user"] as Users;
        final fullName = '${user.firstname} ${user.lastname}'.toLowerCase();
        return fullName.contains(searchQuery.toLowerCase()) ||
            user.email.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _filteredList;
    final totalInList = filteredUsers.length;
    final pendingCount = filteredUsers.where((i) {
      final u = i["user"] as Users;
      return u.identity != "Verified" && u.identity != "Rejected";
    }).length;
    final verifiedCount = filteredUsers.where((i) => (i["user"] as Users).identity == "Verified").length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('Utilisateurs · ${widget.country}'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: loadData,
        child: Column(
          children: [
            // Search + Sort
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() {}),
                      style: AppTypography.bodyLarge().copyWith(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Rechercher...',
                        hintStyle: AppTypography.bodyMedium().copyWith(fontSize: 14),
                        prefixIcon: Icon(Icons.search_rounded, color: AppColors.inkSubtle, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: PopupMenuButton<String>(
                    onSelected: _sortUsers,
                    offset: const Offset(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    itemBuilder: (_) => {'Nom', 'Username'}
                        .map((c) => PopupMenuItem(value: c, child: Text(c)))
                        .toList(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.sort_rounded, color: AppColors.inkMuted, size: 20),
                    ),
                  ),
                ),
              ]),
            ),
            // Filter chips
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildChip('Tous', _UserStatus.all),
                  const SizedBox(width: 8),
                  _buildChip('En attente', _UserStatus.pending, count: pendingCount),
                  const SizedBox(width: 8),
                  _buildChip('Validé', _UserStatus.verified, count: verifiedCount),
                  const SizedBox(width: 8),
                  _buildChip('Rejeté', _UserStatus.rejected),
                ],
              ),
            ),
            // Stats row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
                Text('${displayed.length} / $totalInList utilisateur(s)',
                    style: AppTypography.bodyMedium().copyWith(fontSize: 12)),
                const Spacer(),
                if (pendingCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('$pendingCount en attente',
                        style: AppTypography.labelMedium(color: AppColors.accent).copyWith(fontSize: 11)),
                  ),
                if (verifiedCount > 0)
                  Text('$verifiedCount validés',
                      style: AppTypography.labelMedium(color: AppColors.success).copyWith(fontSize: 11)),
              ]),
            ),
            // List
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : displayed.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.12),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.people_outline_rounded,
                                      size: 64, color: AppColors.inkSubtle),
                                  const SizedBox(height: 12),
                                  Text('Aucun utilisateur trouvé',
                                      style: AppTypography.bodyLarge(color: AppColors.inkMuted)),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: displayed.length,
                          itemBuilder: (context, index) {
                            final item = displayed[index];
                            final user = item["user"] as Users;
                            final identity = item["identity"] as Identity?;
                            return _buildUserCard(user, identity);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, _UserStatus status, {int? count}) {
    final selected = filterStatus == status;
    return GestureDetector(
      onTap: () => setState(() => filterStatus = status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandSurface : AppColors.card,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.brand : AppColors.inkMuted,
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? AppColors.brand.withValues(alpha: 0.15) : AppColors.surfaceWarm,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text('$count',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? AppColors.brand : AppColors.inkSubtle)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _roleBadge(int roleID) {
    final role = AppRole.fromId(roleID);
    String label;
    Color bg;
    switch (role) {
      case AppRole.admin:
        label = 'Admin'; bg = AppColors.brandSurface; break;
      case AppRole.superAdmin:
        label = 'Super Admin'; bg = AppColors.accentLight; break;
      case AppRole.microRestaurant:
        label = 'Resto'; bg = AppColors.successLight; break;
      case AppRole.livreur:
        label = 'Livreur'; bg = AppColors.surfaceWarm; break;
      default:
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.inkMuted)),
    );
  }

  Widget _buildUserCard(Users user, Identity? identity) {
    final isVerified = user.identity == "Verified";
    final isRejected = user.identity == "Rejected";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: AppShadows.cardList,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserDetails(user_id: user.userID),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: identity?.photo != null && identity!.photo!.isNotEmpty
                        ? DiosImage(url: identity.photo, width: 56, height: 56)
                        : Container(
                            width: 56, height: 56,
                            color: AppColors.surfaceWarm,
                            child: Icon(Icons.person_rounded, color: AppColors.inkSubtle, size: 28),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${user.firstname} ${user.lastname}',
                          style: AppTypography.titleMedium().copyWith(fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: AppTypography.bodyMedium().copyWith(fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Row(children: [
                          Icon(Icons.person_outline_rounded,
                              size: 12, color: AppColors.inkSubtle),
                          const SizedBox(width: 4),
                          Text('@${user.username}',
                              style: AppTypography.bodyMedium().copyWith(fontSize: 11)),
                          const SizedBox(width: 12),
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isVerified
                                  ? AppColors.success
                                  : isRejected
                                      ? AppColors.error
                                      : AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isVerified ? 'Validé' : isRejected ? 'Rejeté' : 'En attente',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isVerified
                                  ? AppColors.success
                                  : isRejected
                                      ? AppColors.error
                                      : AppColors.accent,
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  if (widget.roleFilter == null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: _roleBadge(user.roleID),
                    ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.inkSubtle, size: 20),
                ]),
                if (!isVerified)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.successLight,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Icon(Icons.check_rounded, color: AppColors.success, size: 20),
                          ),
                          onPressed: () => _validateUsers(user),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.errorLight,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Icon(Icons.close_rounded, color: AppColors.error, size: 20),
                          ),
                          onPressed: () => _showRejectDialog(user),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRejectDialog(Users user) {
    final remarkCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
          ),
          const SizedBox(width: 10),
          Text('Rejeter le profil', style: AppTypography.titleMedium()),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Motif du rejet pour ${user.firstname} ${user.lastname} :',
              style: AppTypography.bodyMedium()),
          const SizedBox(height: 12),
          TextField(
            controller: remarkCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Saisissez votre remarque...',
              filled: true,
              fillColor: AppColors.surfaceWarm,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler',
                style: AppTypography.labelMedium(color: AppColors.inkMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              _rejectUsers(user, remarkCtrl.text);
            },
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
  }

  Future<void> _validateUsers(Users user) async {
    final result = await Users.updateIdentity(user.userID, "Verified");
    if (result == "success") {
      await _sendEmailToUser(user, true);
      if (mounted) {
        setState(() => user.identity = "Verified");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Profil de ${user.firstname} validé avec succès'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ));
      }
    }
  }

  Future<void> _rejectUsers(Users user, String remark) async {
    final result = await Users.updateIdentity(user.userID, "Rejected");
    if (result == "success") {
      await _sendEmailToUser(user, false, remark);
      if (mounted) {
        setState(() => user.identity = "Rejected");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Profil de ${user.firstname} rejeté'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ));
      }
    }
  }
}
