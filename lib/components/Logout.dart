import 'package:dios_delices/Screen/AnimatedSplashScreen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';

class LogoutFormDialog extends StatefulWidget {
  const LogoutFormDialog({Key? key}) : super(key: key);

  @override
  _LogoutFormDialogState createState() => _LogoutFormDialogState();
}

class _LogoutFormDialogState extends State<LogoutFormDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
        decoration: BoxDecoration(
          color: AppColors.resolve(AppColors.card, AppDarkColors.card),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: AppColors.resolve(AppColors.border, AppDarkColors.border).withValues(alpha: 0.5),
          ),
          boxShadow: AppShadows.floatingList,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.resolve(AppColors.errorLight, AppDarkColors.errorLight),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.logout_rounded,
                size: 26,
                color: AppColors.resolve(AppColors.error, AppDarkColors.error),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "Déconnexion",
              style: AppTypography.titleLarge(
                color: AppColors.resolve(AppColors.ink, AppDarkColors.ink),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Vous allez être déconnecté(e) et\nl'application sera fermée.",
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(
                color: AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      side: BorderSide(
                        color: AppColors.resolve(AppColors.border, AppDarkColors.border),
                      ),
                      foregroundColor: AppColors.resolve(AppColors.ink, AppDarkColors.ink),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: const Text("Annuler"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await SessionService.clearAll();
                      await DatabaseHelper.cleanUpDatabase(true);
                      if (!mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => const AnimatedSplashScreen(),
                        ),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: AppColors.resolve(AppColors.error, AppDarkColors.error),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: Text(
                      "Se déconnecter",
                      style: AppTypography.labelLarge(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
