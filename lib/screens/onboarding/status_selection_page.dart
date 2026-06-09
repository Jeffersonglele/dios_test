import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/constant.dart';
import '../../widgets/showConfetti.dart';
import '../../models/restaurant.dart';
import '../../models/users.dart';
import '../../widgets/brand_avatar_logo.dart';
import '../splash/animated_splash_screen.dart';
import 'start_identity_verification.dart';
import '../restaurants/restaurant_form_page.dart';
import '../../theme/app_theme.dart';

class StatusSelectionPage extends ConsumerStatefulWidget {
  final String country;
  final int objectID;
  final int user_roleID;

  const StatusSelectionPage({
    super.key,
    required this.country,
    required this.objectID,
    required this.user_roleID,
  });

  @override
  ConsumerState<StatusSelectionPage> createState() =>
      _StatusSelectionPageState();
}

class _StatusSelectionPageState extends ConsumerState<StatusSelectionPage> {
  Users? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final users = await Users.fetchUsersFromDB();
      if (mounted) {
        setState(() {
          _user = users.firstWhere((u) => u.userID == widget.objectID);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final List<String> statusOptions = [AppLocalizations.of(context)!.verification_individual, AppLocalizations.of(context)!.verification_restaurateur];
    final size = MediaQuery.of(context).size;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => AnimatedSplashScreen()),
              (Route<dynamic> route) => false,
            );
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: size.width > 600
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  SizedBox(height: size.height * 0.1),
                  if (size.width <= 600) const Center(child: BrandAvatarLogo()),
                  SizedBox(height: size.height * 0.03),
                  Padding(
                    padding: const EdgeInsets.only(left: 20.0),
                    child: Text(
                      AppLocalizations.of(context)!.verification_select_status,
                      style: AppTypography.displayMedium(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final status in statusOptions)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: SizedBox(
                              width: double.infinity,
                              height: 58,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.resolve(
                                    AppColors.brand,
                                    AppDarkColors.brand,
                                  ),
                                  foregroundColor: Colors.white,
                                  textStyle: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.lg),
                                  ),
                                ),
                                onPressed: () => _handleStatusSelected(status),
                                child: Text(status),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _handleStatusSelected(String status) async {
    final int roleID = status == AppLocalizations.of(context)!.verification_individual ? 2 : 3;

    if (_user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.verification_user_not_found),
          ),
        );
      }
      return;
    }

    if (roleID == 2) {
      final fictifName = "La cuisine de ${_user!.firstname}";
      try {
        final String createResult = await Restaurant.manageRestaurant(
          userID: _user!.userID,
          valid: 1,
          nb_orders: 0,
          note: 0.0,
          categories: "",
          description: "",
          location: "",
          name: fictifName,
        );
      } catch (e) {
      }
    }

    try {
      await Users.updateCountryAndRole(_user!.userID, widget.country, roleID);
      if (mounted) {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => StartIdentityVerification(
              objectID: widget.objectID,
              user_roleID: roleID,
            ),
          ),
        );
      }
    } catch (e) {
    }
  }
}
