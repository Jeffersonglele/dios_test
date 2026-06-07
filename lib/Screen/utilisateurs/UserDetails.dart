import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dios_delices/Screen/restaurants/RestaurantDetails.dart';
import 'package:dios_delices/modeles/restaurant.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/core/app_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../modeles/identity.dart';
import '../../modeles/users.dart';
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

      // Vérifier les droits d'édition
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

        if (current_user?.roleID == 1) {
          type_profil = "Administrateur";
        } else if (current_user?.roleID == 2) {
          type_profil = "Particulier";
        } else if (current_user?.roleID == 3) {
          type_profil = "Restaurateur";
        } else if (current_user?.roleID == 4) {
          type_profil = "Super-Administrateur";
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _toggleEdit() {
    if (_isEditing) {
      // Annulation → restaurer les valeurs originales
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
    try {
      final profileResult = await Users.updateProfile(
        current_user!.userID,
        firstname: _firstnameCtrl.text.trim(),
        lastname: _lastnameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        telephone: _phoneCtrl.text.trim(),
      );

      if (profileResult != "success") {
        Toast(context, "Erreur lors de la mise à jour du profil : $profileResult", false);
        return;
      }

      // Recharger les données
      await loadData();

      Toast(context, "Profil mis à jour avec succès.", true);
      setState(() => _isEditing = false);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _handleFilePreview(BuildContext context, String fileUrl) async {
    if (fileUrl.toLowerCase().endsWith(".pdf")) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PDFViewerScreen(fileUrl: fileUrl),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FullScreenImageViewer(imageUrl: fileUrl),
        ),
      );
    }
  }

  Future<bool> _sendEmailToUser(Users user, bool valid,
      [String? remark]) async {
    final recipientEmail = user.email ?? 'adigbononrodicaa@gmail.com';
    final subject = valid
        ? '🎉 Bienvenue sur Dios Délices - Votre profil est validé !'
        : '❌ Mise à jour : Validation de votre profil sur Dios Délices';

    final messageText = valid
        ? 'Bonjour ${user.firstname},\n\n'
            'Nous sommes ravis de vous informer que votre profil a été validé. '
            'Vous pouvez maintenant accéder à votre compte pour gérer votre profil et recevoir des commandes.\n\n'
            'Cordialement,\nL’équipe Dios Délices'
        : 'Bonjour ${user.firstname},\n\n'
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
  Widget build(BuildContext context) {
    if (current_user == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.ink,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isVerified = current_user!.identity == "Verified";
    final isRejected = current_user!.identity == "Rejected";

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.ink,
          elevation: 0,
          title: Text(
            '${current_user!.firstname} ${current_user!.lastname}',
            style: AppTypography.titleMedium(),
          ),
          actions: [
            if (_canEdit)
              IconButton(
                icon: Icon(
                    _isEditing ? Icons.close : Icons.edit_outlined),
                onPressed: _toggleEdit,
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // ── Photo + status ──
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      height: 260,
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(
                            current_identity?.photo ??
                                "https://parsefiles.back4app.com/9qBeGGwSGOQ1iWOJ1UNUXt40NhgwwgbHJYGpV1zg/4f636282d677d999cd624580cdec2ff7_no_image.png",
                          ),
                          fit: BoxFit.cover,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 20, right: 20),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isVerified
                                  ? AppColors.success
                                  : isRejected
                                      ? AppColors.error
                                      : AppColors.accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Infos ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${current_user!.firstname} ${current_user!.lastname}',
                              style: AppTypography.headlineMedium(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (_isEditing) ...[
                        TextFormField(
                          controller: _firstnameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Prénom',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Requis' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _lastnameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nom',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Requis' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Requis' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Téléphone',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveChanges,
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: AppColors.surface),
                                  )
                                : const Text('Enregistrer'),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        _infoRow('Email', current_user!.email),
                        _infoRow('Téléphone', current_user!.telephone),
                        _infoRow('Pays', current_user!.country),
                        _infoRow('Type de profil', type_profil),
                        _infoRow('Identité',
                            isVerified ? 'Validée' : isRejected ? 'Rejetée' : 'En attente'),
                        const SizedBox(height: 12),
                      ],

                      // ── Pièce d'identité ──
                      if (current_identity != null &&
                          (current_identity?.piece_identite ?? '').isNotEmpty)
                        Row(
                          children: [
                            Text("Pièce d'identité :",
                                style: AppTypography.titleMedium()),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.remove_red_eye_outlined),
                              color: AppColors.brand,
                              onPressed: () => _handleFilePreview(
                                  context, current_identity?.piece_identite ?? ""),
                            ),
                          ],
                        ),
                      if (current_identity != null &&
                          (current_identity?.piece_identite ?? '').isNotEmpty)
                        const SizedBox(height: 12),

                      // ── Boutons validation ──
                      if (!_isEditing && !isVerified)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.check_rounded),
                                label: const Text('Valider'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.lg)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: () => _validateUsers(current_user!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.close_rounded),
                                label: const Text('Rejeter'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: const BorderSide(color: AppColors.error),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.lg)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: () =>
                                    _showRejectDialog(current_user!),
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 20),

                      // ── Restaurant associé ──
                      if (current_user_restaurant != null) ...[
                        Text("Restaurant associé",
                            style: AppTypography.titleMedium()),
                        const SizedBox(height: 8),
                        Card(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.lg)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(8),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: DiosImage(
                                  url: current_user_restaurant?.image,
                                  width: 56,
                                  height: 56,
                                ),
                              ),
                            ),
                            title: Text(
                              current_user_restaurant?.name ?? "Nom non défini",
                              style: AppTypography.titleMedium()
                                  .copyWith(fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              current_user_restaurant?.categories ?? "",
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RestaurantDetails(
                                  restaurant_id:
                                      current_user_restaurant!.restaurantID,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: MediaQuery.of(context).size.height * 0.05),
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: AppTypography.bodyMedium()
                    .copyWith(fontSize: 13, color: AppColors.inkMuted)),
          ),
          Expanded(
            child: Text(value,
                style: AppTypography.bodyLarge().copyWith(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(Users users) {
    final TextEditingController remarkController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Rejeter le profil"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Ajouter une remarque pour l'utilisateur :"),
              const SizedBox(height: 8),
              TextField(
                controller: remarkController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Saisissez votre remarque ici...",
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _rejectUsers(users, remarkController.text);
              },
              child: const Text('Envoyer',
                  style: TextStyle(color: AppColors.error)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _validateUsers(Users users) async {
    String updateResult =
        await Users.updateIdentity(users.userID, "Verified");
    if (updateResult == "success") {
      bool emailSent = await _sendEmailToUser(users, true);
      if (emailSent) {
        setState(() => users.identity = "Verified");
        Toast(
            context,
            "Le profil de ${users.firstname} ${users.lastname} a été validé et un email a été envoyé.",
            true);
      } else {
        Toast(
            context,
            "Profil validé mais erreur lors de l'envoi de l'email.",
            false);
      }
    } else {
      Toast(context, "Erreur : $updateResult", false);
    }
  }

  Future<void> _rejectUsers(Users users, String remark) async {
    String updateResult =
        await Users.updateIdentity(users.userID, "Rejected");
    if (updateResult == "success") {
      bool emailSent = await _sendEmailToUser(users, false, remark);
      if (emailSent) {
        setState(() => users.identity = "Rejected");
        Toast(
            context,
            "Le profil de ${users.firstname} ${users.lastname} a été rejeté et un email a été envoyé.",
            false);
      } else {
        Toast(
            context,
            "Profil rejeté mais erreur lors de l'envoi de l'email.",
            false);
      }
    } else {
      Toast(context, "Erreur : $updateResult", false);
    }
  }
}

class PDFViewerScreen extends StatelessWidget {
  final String fileUrl;

  PDFViewerScreen({required this.fileUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aperçu du PDF')),
      body: SfPdfViewer.network(fileUrl),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  FullScreenImageViewer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pièce d'identité")),
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
