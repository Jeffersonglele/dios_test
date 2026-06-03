import 'package:dios_delices/Screen/utilisateurs/UserDetails.dart';
import 'package:dios_delices/providers/data_version_notifier.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../../modeles/users.dart';
import '../../modeles/identity.dart';
import '../../widgets/dios_image.dart';
import '../../utils/strings.dart';

class UsersListPage extends StatefulWidget {
  final String country;

  const UsersListPage({super.key, required this.country});

  @override
  _UsersListPageState createState() => _UsersListPageState();
}

class _UsersListPageState extends State<UsersListPage> {
  List<Map<String, dynamic>> filteredUsers = [];
  List<Identity> identities = [];
  List<Users> users = [];
  bool isLoading = true;
  bool showOnlyWaitingForValidation = false;
  String sortBy = 'Nom';
  String searchQuery = '';

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
    loadData();
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

  void loadData() async {
    List<Identity> identityList = await Identity.fetchIdentitiesFromDB();
    List<Users> usersList = await Users.fetchUsersFromDB();

    setState(() {
      identities = identityList;
      users = usersList;
      _fetchUsersByCountry();
    });
  }

  Future<void> _fetchUsersByCountry() async {
    for (var user in users) {
      Identity? identity = await Identity.getIdentityByUserId(identities, user.userID);
      if (identity != null && user.country == widget.country) {
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
        filteredUsers.sort((a, b) => b["users"].name.compareTo(a["users"].name));
      } else if (criterion == 'Username') {
        filteredUsers.sort((a, b) => b["users"].username.compareTo(a["users"].username));
      }
    });
  }

  List<Map<String, dynamic>> get _filteredList {
    if (searchQuery.isEmpty) return filteredUsers;
    return filteredUsers.where((item) {
      final user = item["users"] as Users;
      final fullName = '${user.firstname} ${user.lastname}'.toLowerCase();
      return fullName.contains(searchQuery.toLowerCase()) ||
          user.email.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _filteredList;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('${Strings.users} · ${widget.country}'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search + Filter bar
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
                      hintText: '${Strings.search}...',
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
          // Filter pending toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: showOnlyWaitingForValidation
                      ? AppColors.accentLight
                      : AppColors.card,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: showOnlyWaitingForValidation
                        ? AppColors.accent
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: showOnlyWaitingForValidation,
                      activeColor: AppColors.accent,
                      onChanged: (v) => setState(() => showOnlyWaitingForValidation = v),
                    ),
                    Text(Strings.pending, style: AppTypography.labelMedium().copyWith(fontSize: 12)),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              const Spacer(),
              Text('${displayed.length} utilisateur(s)',
                  style: AppTypography.bodyMedium().copyWith(fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 4),
          // List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : displayed.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline_rounded,
                                size: 64, color: AppColors.inkSubtle),
                            const SizedBox(height: 12),
                            Text(Strings.get('Aucun utilisateur trouvé', 'No user found'),
                                style: AppTypography.bodyLarge(color: AppColors.inkMuted)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: displayed.length,
                        itemBuilder: (context, index) {
                          final item = displayed[index];
                          final user = item["user"] as Users;
                          final identity = item["identity"] as Identity;

                          if (showOnlyWaitingForValidation && user.identity == "Verified") {
                            return const SizedBox.shrink();
                          }

                          return _buildUserCard(user, identity);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Users user, Identity identity) {
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
                    child: DiosImage(
                      url: identity.photo,
                      width: 56,
                      height: 56,
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
                            isVerified ? Strings.validated : isRejected ? Strings.rejected : Strings.pending,
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
          Text(Strings.get('Rejeter le profil', 'Reject profile'), style: AppTypography.titleMedium()),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${Strings.rejectReason} pour ${user.firstname} ${user.lastname} :',
              style: AppTypography.bodyMedium()),
          const SizedBox(height: 12),
          TextField(
            controller: remarkCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: Strings.get('Saisissez votre remarque...', 'Enter your remark...'),
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
            child: Text(Strings.cancel,
                style: AppTypography.labelMedium(color: AppColors.inkMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              _rejectUsers(user, remarkCtrl.text);
            },
            child: Text(Strings.reject),
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
          content: Text('${user.firstname} : ${Strings.get("Profil validé", "Profile validated")}'),
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
          content: Text('${user.firstname} : ${Strings.get("Profil rejeté", "Profile rejected")}'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ));
      }
    }
  }
}
