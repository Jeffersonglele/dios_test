import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/screens/restaurants/restaurant_details.dart';
import 'package:dios_delices/models/restaurant.dart';
import 'package:dios_delices/providers/data_version_notifier.dart';
import 'package:dios_delices/providers/theme_provider.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/core/app_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../models/identity.dart';
import '../../models/users.dart';
import '../../db/database_helper.dart';
import '../../utils/toast.dart';
import '../../widgets/dios_image.dart';

class UserDetails extends ConsumerStatefulWidget {
  static const routeName = '/UserDetailsUser';
  final int user_id;
  UserDetails({required this.user_id});

  @override
  _UserDetailsState createState() => _UserDetailsState();
}

class _UserDetailsState extends ConsumerState<UserDetails> {
  Users? current_user;
  Identity? current_identity;
  Restaurant? current_user_restaurant;
  String type_profil = "...";

  bool _isEditing = false;
  bool _isAdmin = false;
  bool _isSuperAdmin = false;
  bool _canEdit = false;
  bool _isSaving = false;

  final _formKey = GlobalKey<FormState>();
  final _firstnameCtrl = TextEditingController();
  final _lastnameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    _firstnameCtrl.dispose();
    _lastnameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    try {
      final session = await SessionService.readSession();
      _isAdmin = session.role.isAdmin;
      _isSuperAdmin = session.role == AppRole.superAdmin;

      List<Users> usersList = await Users.fetchUsersFromDB();
      final user = Users.getUsersByUserId(usersList, widget.user_id);
      List<Identity> allIdentities = await Identity.fetchIdentitiesFromDB();
      List<Restaurant> restaurantsList =
          await Restaurant.fetchRestaurantsFromDB();

      Identity? identity;
      final matched = allIdentities.where((i) => i.userID == widget.user_id);
      if (matched.isNotEmpty) identity = matched.first;
      final restaurant =
          Restaurant.getRestaurantByUser(restaurantsList, widget.user_id);

      if (_isSuperAdmin) {
        _canEdit = true;
      } else if (_isAdmin && user != null) {
        _canEdit = session.country == user.country;
      }

      setState(() {
        current_user = user;
        current_identity = identity;
        current_user_restaurant = restaurant;
        if (current_user != null) {
          _firstnameCtrl.text = current_user!.firstname ?? '';
          _lastnameCtrl.text = current_user!.lastname ?? '';
          _emailCtrl.text = current_user!.email;
          _phoneCtrl.text = current_user!.telephone;
        }
        final role = AppRole.fromId(current_user?.roleID);
        if (role.isAdmin) {
          type_profil = "Administrateur";
        } else if (role.isDelivery) {
          type_profil = "Livreur";
        } else if (role.isProfessional) {
          type_profil = "Restaurateur";
        } else {
          type_profil = "Particulier";
        }
      });
    } catch (e) {
      if (mounted) setState(() {});
    }
  }

  void _toggleEdit() {
    if (_isEditing) {
      setState(() {
        _firstnameCtrl.text = current_user!.firstname ?? '';
        _lastnameCtrl.text = current_user!.lastname ?? '';
        _emailCtrl.text = current_user!.email;
        _phoneCtrl.text = current_user!.telephone;
        _isEditing = false;
      });
    } else {
      setState(() => _isEditing = true);
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    if (current_user == null) return;
    setState(() => _isSaving = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final profileResult = await Users.updateProfile(
        current_user!.userID,
        firstname: _firstnameCtrl.text.trim(),
        lastname: _lastnameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        telephone: _phoneCtrl.text.trim(),
      );
      if (profileResult != "success") {
        Toast(context, l10n.error_with_message(profileResult), false);
        return;
      }
      await loadData();
      Toast(context, l10n.profileUpdated, true);
      setState(() => _isEditing = false);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _handleFilePreview(BuildContext context, String fileUrl) async {
    if (fileUrl.toLowerCase().endsWith(".pdf")) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => PDFViewerScreen(fileUrl: fileUrl)));
    } else {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => FullScreenImageViewer(imageUrl: fileUrl)));
    }
  }

  Color _roleColor(AppRole role) {
    if (role.isAdmin)
      return AppColors.resolve(
          const Color(0xFF6C5CE7), const Color(0xFFA29BFE));
    if (role.isDelivery)
      return AppColors.resolve(AppColors.success, AppDarkColors.success);
    if (role.isProfessional)
      return AppColors.resolve(AppColors.accent, AppDarkColors.accent);
    return AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
  }

  Color _statusColor() {
    if (current_user?.identity == "Verified")
      return AppColors.resolve(AppColors.success, AppDarkColors.success);
    if (current_user?.identity == "Rejected")
      return AppColors.resolve(AppColors.error, AppDarkColors.error);
    return AppColors.resolve(AppColors.accent, AppDarkColors.accent);
  }

  String _statusLabel(AppLocalizations l10n) {
    if (current_user?.identity == "Verified") return l10n.profile_validated;
    if (current_user?.identity == "Rejected") return l10n.profile_rejected;
    return l10n.profile_pending;
  }

  IconData _statusIcon() {
    if (current_user?.identity == "Verified") return Icons.check_circle_rounded;
    if (current_user?.identity == "Rejected") return Icons.cancel_rounded;
    return Icons.hourglass_bottom_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (current_user == null) {
      final surface =
          AppColors.resolve(AppColors.surface, AppDarkColors.surface);
      final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
      return Scaffold(
        backgroundColor: surface,
        appBar: AppBar(backgroundColor: surface),
        body: Center(child: CircularProgressIndicator(color: brand)),
      );
    }

    final isVerified = current_user!.identity == "Verified";
    final role = AppRole.fromId(current_user!.roleID);
    final roleColor = _roleColor(role);
    final photoUrl = current_identity?.photo ??
        "https://parsefiles.back4app.com/9qBeGGwSGOQ1iWOJ1UNUXt40NhgwwgbHJYGpV1zg/4f636282d677d999cd624580cdec2ff7_no_image.png";

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor:
            AppColors.resolve(AppColors.surface, AppDarkColors.surface),
        body: Form(
          key: _formKey,
          child: CustomScrollView(
            slivers: [
              // ═══════════════════════════════════════════
              // HERO HEADER — gradient avatar area
              // ═══════════════════════════════════════════
              SliverAppBar(
                pinned: true,
                expandedHeight: 220,
                backgroundColor:
                    AppColors.resolve(AppColors.surface, AppDarkColors.surface),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    children: [
                      // Gradient background
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                roleColor.withValues(alpha: 0.15),
                                AppColors.resolve(
                                    AppColors.surface, AppDarkColors.surface),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Photo full width
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(32)),
                          child: ColorFiltered(
                            colorFilter: ColorFilter.mode(
                                Colors.black.withValues(alpha: 0.25),
                                BlendMode.darken),
                            child: Image.network(photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                      decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: [
                                        roleColor,
                                        roleColor.withValues(alpha: 0.5),
                                      ])),
                                    )),
                          ),
                        ),
                      ),
                      // Overlay content
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 20,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Avatar circle
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 8,
                                      offset: const Offset(0, 2))
                                ],
                                image: DecorationImage(
                                    image: NetworkImage(photoUrl),
                                    fit: BoxFit.cover),
                              ),
                              child: photoUrl.contains('no_image')
                                  ? Center(
                                      child: Text(
                                          (current_user!.firstname ?? '?')[0]
                                              .toUpperCase(),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold)),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: roleColor,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(type_profil,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                      '${current_user!.firstname} ${current_user!.lastname}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          shadows: [
                                            Shadow(
                                                blurRadius: 4,
                                                color: Colors.black38)
                                          ])),
                                ],
                              ),
                            ),
                            // Status dot
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black12, blurRadius: 4)
                                ],
                              ),
                              child: Icon(_statusIcon(),
                                  color: _statusColor(), size: 22),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  if (_canEdit)
                    IconButton(
                      icon: Icon(
                          _isEditing
                              ? Icons.close_rounded
                              : Icons.edit_outlined,
                          color: Colors.white),
                      onPressed: _toggleEdit,
                    ),
                ],
                iconTheme: const IconThemeData(color: Colors.white),
              ),

              // ═══════════════════════════════════════════
              // BODY
              // ═══════════════════════════════════════════
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // ── STATUS BADGE ──
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _statusColor().withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(_statusIcon(),
                                    size: 16, color: _statusColor()),
                                const SizedBox(width: 6),
                                Text(_statusLabel(l10n),
                                    style: AppTypography.labelMedium(
                                        color: _statusColor())),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // Role badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                _roleIcon(role, roleColor),
                                const SizedBox(width: 6),
                                Text(type_profil,
                                    style: AppTypography.labelMedium(
                                        color: roleColor)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── INFO CARD ──
                      if (_isEditing) ...[
                        _buildSectionCard(
                          icon: Icons.person_outline_rounded,
                          title: l10n.user_details_information,
                          color: AppColors.brand,
                          child: Column(children: [
                            _buildFormField(
                                controller: _firstnameCtrl,
                                label: l10n.user_details_firstname,
                                validator: (v) => (v?.trim().isEmpty ?? true)
                                    ? l10n.user_details_required
                                    : null),
                            const SizedBox(height: 12),
                            _buildFormField(
                                controller: _lastnameCtrl,
                                label: l10n.user_details_lastname,
                                validator: (v) => (v?.trim().isEmpty ?? true)
                                    ? l10n.user_details_required
                                    : null),
                            const SizedBox(height: 12),
                            _buildFormField(
                                controller: _emailCtrl,
                                label: l10n.user_details_email,
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) => (v?.trim().isEmpty ?? true)
                                    ? l10n.user_details_required
                                    : null),
                            const SizedBox(height: 12),
                            _buildFormField(
                                controller: _phoneCtrl,
                                label: l10n.user_details_phone,
                                keyboardType: TextInputType.phone),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveChanges,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.brand,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.md)),
                                ),
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : Text(l10n.save_profile,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ]),
                        ),
                      ] else ...[
                        _buildSectionCard(
                          icon: Icons.person_outline_rounded,
                          title: l10n.user_details_information,
                          color: AppColors.brand,
                          child: Column(children: [
                            _infoTile(
                                Icons.email_outlined,
                                l10n.user_details_email,
                                current_user!.email,
                                AppColors.brand),
                            const _Divider(),
                            _infoTile(
                                Icons.phone_android_rounded,
                                l10n.user_details_phone,
                                current_user!.telephone,
                                AppColors.success),
                            const _Divider(),
                            _infoTile(
                                Icons.public_rounded,
                                l10n.user_details_country,
                                current_user!.country,
                                Colors.blue),
                            const _Divider(),
                            _infoTile(
                                Icons.badge_rounded,
                                l10n.user_details_profile_type,
                                type_profil,
                                roleColor),
                            const _Divider(),
                            _infoTile(_statusIcon(), l10n.user_details_identity,
                                _statusLabel(l10n), _statusColor()),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // ── IDENTITY DOCUMENT ──
                      if (current_identity != null &&
                          (current_identity?.piece_identite ?? '').isNotEmpty)
                        _buildDocumentCard(),

                      const SizedBox(height: 16),

                      // ── VALIDATION BUTTONS ──
                      if (!_isEditing && !isVerified) _buildValidationActions(),

                      const SizedBox(height: 16),

                      // ── RESTAURANT ──
                      if (current_user_restaurant != null)
                        _buildRestaurantCard(),

                      // ── FORCE DELETE (super-admin) ──
                      if (_isSuperAdmin) ...[
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _showForceDeleteDialog,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(
                                  color:
                                      AppColors.error.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.error.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                      Icons.delete_forever_rounded,
                                      color: AppColors.error,
                                      size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(l10n.force_delete,
                                          style: const TextStyle(
                                              color: AppColors.error,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15)),
                                      const SizedBox(height: 2),
                                      Text(l10n.force_delete_desc,
                                          style: AppTypography.bodyMedium(
                                                  color: AppColors.error
                                                      .withValues(alpha: 0.7))
                                              .copyWith(fontSize: 12)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded,
                                    color: AppColors.error),
                              ],
                            ),
                          ),
                        ),
                      ],

                      SizedBox(
                          height: MediaQuery.of(context).size.height * 0.08),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleIcon(AppRole role, Color color) {
    IconData icon;
    if (role.isAdmin)
      icon = Icons.admin_panel_settings_rounded;
    else if (role.isDelivery)
      icon = Icons.delivery_dining_rounded;
    else if (role.isProfessional)
      icon = Icons.restaurant_rounded;
    else
      icon = Icons.person_rounded;
    return Icon(icon, size: 16, color: color);
  }

  Widget _buildSectionCard(
      {required IconData icon,
      required String title,
      required Color color,
      required Widget child}) {
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: AppTypography.titleMedium()
                    .copyWith(fontSize: 16, color: ink)),
          ]),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String? value, Color accent) {
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 17, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.bodyMedium()
                        .copyWith(fontSize: 12, color: inkMuted)),
                const SizedBox(height: 2),
                Text(value ?? '—',
                    style: AppTypography.bodyLarge().copyWith(
                        fontSize: 14, fontWeight: FontWeight.w500, color: ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField(
      {required TextEditingController controller,
      required String label,
      TextInputType? keyboardType,
      String? Function(String?)? validator}) {
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final surface = AppColors.resolve(AppColors.surface, AppDarkColors.surface);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: AppTypography.bodyLarge().copyWith(fontSize: 14, color: ink),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.bodyMedium(color: inkMuted),
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: brand, width: 1.5)),
      ),
    );
  }

  Widget _buildDocumentCard() {
    final l10n = AppLocalizations.of(context)!;
    final docUrl = current_identity?.piece_identite ?? '';
    final isPdf = docUrl.toLowerCase().endsWith('.pdf');
    final isImg = !isPdf;

    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final purple =
        AppColors.resolve(const Color(0xFF8B5CF6), const Color(0xFFA78BFA));

    return _buildSectionCard(
      icon: Icons.credit_card_rounded,
      title: l10n.identity_document_label,
      color: purple,
      child: GestureDetector(
        onTap: () => _handleFilePreview(context, docUrl),
        child: Container(
          height: 180,
          decoration: BoxDecoration(
            color: purple.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: purple.withValues(alpha: 0.2)),
          ),
          child: isImg
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: CachedNetworkImage(
                      imageUrl: docUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: brand)),
                      errorWidget: (_, __, ___) => Center(
                          child: Icon(Icons.broken_image_rounded,
                              size: 36, color: inkMuted))),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 4)
                          ]),
                      child: const Icon(Icons.picture_as_pdf_rounded,
                          size: 32, color: Color(0xFFE53935)),
                    ),
                    const SizedBox(height: 10),
                    Text(l10n.pdf_document,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: ink)),
                    const SizedBox(height: 2),
                    Text(l10n.tap_to_open,
                        style: AppTypography.bodyMedium(color: inkMuted)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildValidationActions() {
    final l10n = AppLocalizations.of(context)!;
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final accent = AppColors.resolve(AppColors.accent, AppDarkColors.accent);
    final success = AppColors.resolve(AppColors.success, AppDarkColors.success);
    final error = AppColors.resolve(AppColors.error, AppDarkColors.error);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.shield_rounded, size: 20, color: accent),
            ),
            const SizedBox(width: 10),
            Text(l10n.validation,
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 16, color: ink)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_rounded, size: 20),
                label: Text(l10n.validate),
                style: ElevatedButton.styleFrom(
                  backgroundColor: success,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => _validateUsers(current_user!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.close_rounded, size: 20),
                label: Text(l10n.reject),
                style: OutlinedButton.styleFrom(
                  foregroundColor: error,
                  side: BorderSide(color: error),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => _showRejectDialog(current_user!),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildRestaurantCard() {
    final l10n = AppLocalizations.of(context)!;
    final resto = current_user_restaurant!;
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final accent = AppColors.resolve(AppColors.accent, AppDarkColors.accent);
    final accentLight =
        AppColors.resolve(AppColors.accentLight, AppDarkColors.accentLight);
    return _buildSectionCard(
      icon: Icons.storefront_rounded,
      title: l10n.restaurant_associated,
      color: accent,
      child: GestureDetector(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    RestaurantDetails(restaurant_id: resto.restaurantID))),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accentLight.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 60,
                height: 60,
                child: Hero(
                  tag: 'resto_${resto.restaurantID}',
                  child: DiosImage(url: resto.image, width: 60, height: 60),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(resto.name,
                      style: AppTypography.titleMedium()
                          .copyWith(fontSize: 15, color: ink),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.star_rounded, size: 14, color: accent),
                    const SizedBox(width: 4),
                    Text(resto.note.toStringAsFixed(1),
                        style: AppTypography.bodyMedium(color: accent)),
                    if (resto.categories.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle, color: inkMuted)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(resto.categories,
                              style: AppTypography.bodyMedium()
                                  .copyWith(fontSize: 12, color: inkMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                    ],
                  ]),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.chevron_right_rounded, size: 20, color: accent),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _showForceDeleteDialog() async {
    final ctrl = TextEditingController(text: widget.user_id.toString());
    final confirmCtrl = TextEditingController();
    bool deleting = false;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return StatefulBuilder(
          builder: (ctx, set) => AlertDialog(
            title: Row(children: [
              const Icon(Icons.delete_forever_rounded,
                  color: AppColors.error, size: 24),
              const SizedBox(width: 8),
              Flexible(
                  child: Text(l10n.delete_permanently,
                      style: const TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600))),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${current_user!.firstname} ${current_user!.lastname} (ID: ${widget.user_id})',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(l10n.delete_confirm_message,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.error)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.type_delete_to_confirm,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: deleting ? null : () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: deleting
                    ? null
                    : () async {
                        if (confirmCtrl.text.trim() != 'DELETE') {
                          Toast(context, l10n.must_type_delete, false);
                          return;
                        }
                        set(() => deleting = true);
                        try {
                          final fn = ParseCloudFunction('forceDeleteUser');
                          final res = await fn
                              .execute(parameters: {'userID': widget.user_id});
                          if (!ctx.mounted) return;
                          if (res.success) {
                            await DatabaseHelper.deleteUser(widget.user_id);
                            if (current_user_restaurant != null) {
                              await DatabaseHelper.deleteRestaurant(
                                  current_user_restaurant!.restaurantID);
                            }
                            dataVersionNotifier.value =
                                dataVersionNotifier.value + 1;
                            if (!ctx.mounted) return;
                            Toast(
                                context,
                                l10n.user_deleted(current_user!.firstname!),
                                true);
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                          } else {
                            Toast(
                                context,
                                l10n.error_with_message(res.error?.toString() ??
                                    res.result?.toString() ??
                                    ''),
                                false);
                          }
                        } catch (e) {
                          if (ctx.mounted) Toast(context, '$e', false);
                        } finally {
                          if (ctx.mounted) set(() => deleting = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                child: deleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(l10n.force_delete_button),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRejectDialog(Users users) {
    final remarkController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg)),
          title: Row(children: [
            const Icon(Icons.close_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 8),
            Text(l10n.reject_profile)
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l10n.reject_profile_remark_hint),
            const SizedBox(height: 8),
            TextField(
                controller: remarkController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: l10n.type_your_remark_hint,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                )),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _rejectUsers(users, remarkController.text);
              },
              child: Text(l10n.send,
                  style: const TextStyle(color: AppColors.error)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _validateUsers(Users users) async {
    final l10n = AppLocalizations.of(context)!;
    String updateResult = await Users.updateIdentity(users.userID, "Verified");
    if (updateResult == "success") {
      bool emailSent = await _sendEmailToUser(users, true);
      if (emailSent) {
        setState(() => users.identity = "Verified");
        Toast(
            context,
            l10n.profile_validated_email_sent(
                users.firstname!, users.lastname!),
            true);
      } else {
        Toast(context, l10n.profile_validated_email_error, false);
      }
    } else {
      Toast(context, l10n.error_with_message(updateResult), false);
    }
  }

  Future<void> _rejectUsers(Users users, String remark) async {
    final l10n = AppLocalizations.of(context)!;
    String updateResult = await Users.updateIdentity(users.userID, "Rejected");
    if (updateResult == "success") {
      bool emailSent = await _sendEmailToUser(users, false, remark);
      if (emailSent) {
        setState(() => users.identity = "Rejected");
        Toast(
            context,
            l10n.profile_rejected_email_sent(users.firstname!, users.lastname!),
            false);
      } else {
        Toast(context, l10n.profile_rejected_email_error, false);
      }
    } else {
      Toast(context, l10n.error_with_message(updateResult), false);
    }
  }

  Future<bool> _sendEmailToUser(Users user, bool valid,
      [String? remark]) async {
    final l10n = AppLocalizations.of(context)!;
    final recipientEmail = user.email ?? 'adigbononrodicaa@gmail.com';
    final subject = valid
        ? l10n.identity_validated_email_subject
        : l10n.identity_rejected_email_subject;
    final messageText = valid
        ? l10n.identity_validated_email_body(user.firstname!)
        : l10n.identity_rejected_email_body(user.firstname!, remark ?? "");
    final cloudFunction = ParseCloudFunction('sendEmail');
    try {
      await cloudFunction.execute(parameters: {
        'to': recipientEmail,
        'subject': subject,
        'text': messageText
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}

class _Divider extends StatelessWidget {
  final Color? color;
  const _Divider() : color = null;
  @override
  Widget build(BuildContext context) {
    final dividerColor =
        color ?? AppColors.resolve(AppColors.border, AppDarkColors.border);
    return Divider(color: dividerColor.withValues(alpha: 0.5), height: 1);
  }
}

class PDFViewerScreen extends StatelessWidget {
  final String fileUrl;
  PDFViewerScreen({required this.fileUrl});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pdf_preview)),
      body: SfPdfViewer.network(fileUrl),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  FullScreenImageViewer({required this.imageUrl});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.identity_document_label)),
      body: Center(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          placeholder: (_, __) => const CircularProgressIndicator(),
          errorWidget: (_, __, ___) => const Icon(Icons.error),
        ),
      ),
    );
  }
}
