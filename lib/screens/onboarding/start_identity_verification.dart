import 'package:dios_delices/screens/onboarding/identity_verification.dart';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/constant.dart';
import '../../widgets/brand_avatar_logo.dart';
import '../../theme/app_theme.dart';

class StartIdentityVerification extends ConsumerStatefulWidget {
  final int objectID;
  final int user_roleID;

  const StartIdentityVerification(
      {super.key, required this.objectID, required this.user_roleID});
  @override
  StartIdentityVerificationState createState() =>
      StartIdentityVerificationState();
}

class StartIdentityVerificationState
    extends ConsumerState<StartIdentityVerification> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    var size = MediaQuery.of(context).size;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
        appBar: AppBar(),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: size.width > 600
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                SizedBox(height: size.height * 0.1),
                size.width > 600
                    ? Container()
                    : const Center(child: BrandAvatarLogo()),
                SizedBox(height: size.height * 0.03),
                Padding(
                  padding: const EdgeInsets.only(left: 20.0),
                  child: Text(
                    l10n.start_identity_instructions,
                    style: AppTypography.titleLarge(
                        color: colorScheme.onSurface),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(height: size.height * 0.05),
                Center(
                  child: Column(
                    children: [
                      SizedBox(
                        width: size.width * 0.8, // 80% de la largeur de l'écran
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                          ),
                          onPressed: () async {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => IdentityVerification(
                                  objectID: widget.objectID,
                                  user_roleID: widget.user_roleID,
                                ),
                              ),
                            );
                          },
                          child: Text(l10n.start_begin),
                        ),
                      ),
                      const SizedBox(height: 16), // Espace entre les boutons
                      SizedBox(
                        width: size.width * 0.8,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            foregroundColor: colorScheme.onSurface,
                            textStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text(l10n.start_cancel_return),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}
