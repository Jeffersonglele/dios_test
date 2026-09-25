import 'package:dios_delices/screens/users/user_details.dart';
import 'package:dios_delices/core/app_role.dart';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/providers/data_version_notifier.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../../models/users.dart';
import '../../models/identity.dart';
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
  String searchQuery = '';
  int _currentUserId = 0;

  final TextEditingController _searchCtrl = TextEditingController();

  Future<bool> _sendEmailToUser(Users user, bool valid,
      [String? remark]) async {
    final l10n = AppLocalizations.of(context)!;
    final recipientEmail = user?.email ?? 'adigbononrodicaa@gmail.com';
    final subject = valid
        ? l10n.identity_validated_email_subject
        : l10n.identity_rejected_email_subject;

    final messageText = valid
        ? l10n.identity_validated_email_body(user!.firstname!)
        : l10n.identity_rejected_email_body(user!.firstname!, remark ?? '');

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
      if (user.country == widget.country &&
          (widget.roleFilter == null ||
              widget.roleFilter!.contains(user.roleID))) {
        Identity? identity =
            Identity.getIdentityByUserId(identities, user.userID);
        setState(() {
          filteredUsers.add({"user": user, "identity": identity});
        });
      }
    }
    setState(() {
      isLoading = false;
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
      list = list
          .where((item) => (item["user"] as Users).identity == "Verified")
          .toList();
    } else if (filterStatus == _UserStatus.rejected) {
      list = list
          .where((item) => (item["user"] as Users).identity == "Rejected")
          .toList();
    }
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((item) {
        final user = item["user"] as Users;
        final fullName = '${user.firstname} ${user.lastname}'.toLowerCase();
        return fullName.contains(q) ||
            user.email.toLowerCase().contains(q) ||
            user.username.toLowerCase().contains(q) ||
            user.telephone.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayed = _filteredList;
    final totalInList = filteredUsers.length;
    final pendingCount = filteredUsers.where((i) {
      final u = i["user"] as Users;
      return u.identity != "Verified" && u.identity != "Rejected";
    }).length;
    final verifiedCount = filteredUsers
        .where((i) => (i["user"] as Users).identity == "Verified")
        .length;

    return Scaffold(
      backgroundColor:
          AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      appBar: AppBar(
        title: Text(l10n.users_list_title(widget.country)),
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
                      color:
                          AppColors.resolve(AppColors.card, AppDarkColors.card),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                          color: AppColors.resolve(
                              AppColors.border, AppDarkColors.border)),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => searchQuery = v),
                      style: AppTypography.bodyLarge(
                              color: AppColors.resolve(
                                  AppColors.ink, AppDarkColors.ink))
                          .copyWith(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: l10n.search_name_email_phone,
                        hintStyle: AppTypography.bodyMedium(
                                color: AppColors.resolve(
                                    AppColors.inkMuted, AppDarkColors.inkMuted))
                            .copyWith(fontSize: 14),
                        prefixIcon: Icon(Icons.search_rounded,
                            color: AppColors.resolve(
                                AppColors.inkSubtle, AppDarkColors.inkSubtle),
                            size: 20),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close_rounded, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ]),
            ),
            // Status filter chips
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildChip(l10n.all_filter, _UserStatus.all),
                  const SizedBox(width: 8),
                  _buildChip(l10n.pending_filter, _UserStatus.pending,
                      count: pendingCount),
                  const SizedBox(width: 8),
                  _buildChip(l10n.validated_filter, _UserStatus.verified,
                      count: verifiedCount),
                  const SizedBox(width: 8),
                  _buildChip(l10n.rejected_filter, _UserStatus.rejected),
                ],
              ),
            ),
            // Stats row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
                Text(l10n.users_count('${displayed.length}', '$totalInList'),
                    style: AppTypography.bodyMedium(
                        color: AppColors.resolve(
                            AppColors.inkMuted, AppDarkColors.inkMuted))),
                const Spacer(),
                if (pendingCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(l10n.pending_count('$pendingCount'),
                        style:
                            AppTypography.labelMedium(color: AppColors.accent)
                                .copyWith(fontSize: 11)),
                  ),
                if (verifiedCount > 0)
                  Text(l10n.validated_count('$verifiedCount'),
                      style: AppTypography.labelMedium(color: AppColors.success)
                          .copyWith(fontSize: 11)),
              ]),
            ),
            // List
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : displayed.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.12),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.people_outline_rounded,
                                      size: 64, color: AppColors.inkSubtle),
                                  const SizedBox(height: 12),
                                  Text(l10n.no_user_found,
                                      style: AppTypography.bodyLarge(
                                          color: AppColors.resolve(
                                              AppColors.inkMuted,
                                              AppDarkColors.inkMuted))),
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
                            return _buildUserCard(user, identity, l10n);
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
          color: selected
              ? AppColors.resolve(
                  AppColors.brandSurface, AppDarkColors.brandSurface)
              : AppColors.resolve(AppColors.card, AppDarkColors.card),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected
                ? AppColors.resolve(AppColors.brand, AppDarkColors.brand)
                : AppColors.resolve(AppColors.border, AppDarkColors.border),
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
                color: selected
                    ? AppColors.resolve(AppColors.brand, AppDarkColors.brand)
                    : AppColors.resolve(
                        AppColors.inkMuted, AppDarkColors.inkMuted),
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.resolve(AppColors.brand, AppDarkColors.brand)
                          .withValues(alpha: 0.15)
                      : AppColors.resolve(
                          AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text('$count',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color:
                            selected ? AppColors.brand : AppColors.inkSubtle)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _roleBadge(int roleID, AppLocalizations l10n) {
    final role = AppRole.fromId(roleID);
    String label;
    Color bg;
    switch (role) {
      case AppRole.admin:
        label = l10n.admin_role_label;
        bg = AppColors.resolve(
            AppColors.brandSurface, AppDarkColors.brandSurface);
        break;
      case AppRole.superAdmin:
        label = l10n.super_admin_role_label;
        bg =
            AppColors.resolve(AppColors.accentLight, AppDarkColors.accentLight);
        break;
      case AppRole.microRestaurant:
        label = l10n.resto_role_label;
        bg = AppColors.resolve(
            AppColors.successLight, AppDarkColors.successLight);
        break;
      case AppRole.livreur:
        label = l10n.livreur_role_label;
        bg = AppColors.resolve(
            AppColors.successLight, AppDarkColors.successLight);
        break;
      case AppRole.livreur:
        label = l10n.livreur_role_label;
        bg =
            AppColors.resolve(AppColors.surfaceWarm, AppDarkColors.surfaceWarm);
        break;
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
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.resolve(
                  AppColors.inkMuted, AppDarkColors.inkMuted))),
    );
  }

  Widget _buildUserCard(Users user, Identity? identity, AppLocalizations l10n) {
    final isVerified = user.identity == "Verified";
    final isRejected = user.identity == "Rejected";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
            color: AppColors.resolve(AppColors.border, AppDarkColors.border),
            width: 0.5),
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
                    child: identity?.photo != null &&
                            identity!.photo!.isNotEmpty
                        ? DiosImage(url: identity.photo, width: 56, height: 56)
                        : Container(
                            width: 56,
                            height: 56,
                            color: AppColors.resolve(AppColors.surfaceWarm,
                                AppDarkColors.surfaceWarm),
                            child: Icon(Icons.person_rounded,
                                color: AppColors.resolve(AppColors.inkSubtle,
                                    AppDarkColors.inkSubtle),
                                size: 28),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${user.firstname} ${user.lastname}',
                          style: AppTypography.titleMedium(
                              color: AppColors.resolve(
                                  AppColors.ink, AppDarkColors.ink)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: AppTypography.bodyMedium(
                                  color: AppColors.resolve(AppColors.inkMuted,
                                      AppDarkColors.inkMuted))
                              .copyWith(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        Row(children: [
                          Icon(Icons.person_outline_rounded,
                              size: 12,
                              color: AppColors.resolve(AppColors.inkSubtle,
                                  AppDarkColors.inkSubtle)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text('@${user.username}',
                                style: AppTypography.bodyMedium(
                                        color: AppColors.resolve(
                                            AppColors.inkMuted,
                                            AppDarkColors.inkMuted))
                                    .copyWith(fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 6,
                            height: 6,
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
                          Flexible(
                            fit: FlexFit.loose,
                            child: Text(
                              isVerified
                                  ? l10n.profile_validated
                                  : isRejected
                                      ? l10n.profile_rejected
                                      : l10n.profile_pending,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isVerified
                                    ? AppColors.success
                                    : isRejected
                                        ? AppColors.error
                                        : AppColors.accent,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  if (widget.roleFilter == null)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: _roleBadge(user.roleID, l10n),
                    ),
                  Icon(Icons.chevron_right_rounded,
                      color: AppColors.inkSubtle, size: 20),
                ]),
                if (!isVerified)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.resolve(AppColors.successLight,
                                  AppDarkColors.successLight),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Icon(Icons.check_rounded,
                                color: AppColors.resolve(
                                    AppColors.success, AppDarkColors.success),
                                size: 20),
                          ),
                          onPressed: () => _validateUsers(user),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.errorLight,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Icon(Icons.close_rounded,
                                color: AppColors.error, size: 20),
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
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 18),
            ),
            const SizedBox(width: 10),
            Text(l10n.reject_profile, style: AppTypography.titleMedium()),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l10n.reject_profile_remark_hint,
                style: AppTypography.bodyMedium()),
            const SizedBox(height: 12),
            TextField(
              controller: remarkCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l10n.type_your_remark_hint,
                filled: true,
                fillColor: AppColors.resolve(
                    AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
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
              child: Text(l10n.cancel,
                  style: AppTypography.labelMedium(color: AppColors.inkMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () {
                Navigator.pop(ctx);
                _rejectUsers(user, remarkCtrl.text);
              },
              child: Text(l10n.reject),
            ),
          ],
        );
      },
    );
  }

  Future<void> _validateUsers(Users user) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await Users.updateIdentity(user.userID, "Verified");
    if (result == "success") {
      await _sendEmailToUser(user, true);
      if (mounted) {
        setState(() => user.identity = "Verified");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.profile_validated_email_sent(user.firstname!, '')),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
        ));
      }
    }
  }

  Future<void> _rejectUsers(Users user, String remark) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await Users.updateIdentity(user.userID, "Rejected");
    if (result == "success") {
      await _sendEmailToUser(user, false, remark);
      if (mounted) {
        setState(() => user.identity = "Rejected");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.profile_rejected_email_sent(user.firstname!, '')),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
        ));
      }
    }
  }
}
