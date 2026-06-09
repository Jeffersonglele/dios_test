import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../db/database_helper.dart';
import '../services/session_service.dart';

// Login widget dans ce projet (chemin correct)
import '../screens/auth/Login.dart';
import '../theme/app_theme.dart';

class LogoutFormDialog extends StatefulWidget {
  const LogoutFormDialog({super.key});

  @override
  _LogoutFormDialogState createState() => _LogoutFormDialogState();
}

class _LogoutFormDialogState extends State<LogoutFormDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..forward();

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl, curve: AppMotion.standard),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entryCtrl, curve: AppMotion.standard),
    );
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      // 1. D'abord fermer tous les dialogues ouverts
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }

      // 2. Effacer la session
      await SessionService.clearAll();

      // 3. Nettoyer la base de données (sans bloquer sur web)
      if (!kIsWeb) {
        // Sur mobile, on peut nettoyer le disque
        try {
          await DatabaseHelper.cleanUpDatabase(true);
        } catch (e) {
          print('Erreur nettoyage base: $e');
        }
      } else {
        // Sur web, simplement réinitialiser l'état
        print('Nettoyage base ignoré sur web');
      }

      // 4. Attendre un court instant pour que tout soit bien fermé
      await Future.delayed(const Duration(milliseconds: 100));

      // 5. Naviguer vers la page de login
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          CupertinoPageRoute(builder: (_) => const Login()),
          (route) => false,
        );
      }
    } catch (e) {
      print('Erreur lors de la déconnexion: $e');
      // En cas d'erreur, essayer quand même de naviguer vers login
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          CupertinoPageRoute(builder: (_) => const Login()),
          (route) => false,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.resolve(AppColors.card, AppDarkColors.card),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: AppColors.resolve(AppColors.border, AppDarkColors.border)
                    .withValues(alpha: 0.5),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _LogoutHeader(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Vous déconnecter ?',
                        style: AppTypography.titleLarge(
                          color: AppColors.resolve(
                              AppColors.ink, AppDarkColors.ink),
                        ).copyWith(fontSize: 20, letterSpacing: -0.3),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Votre session sera fermée.\nVous devrez vous reconnecter pour accéder à votre compte.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium(
                          color: AppColors.resolve(
                              AppColors.inkMuted, AppDarkColors.inkMuted),
                        ).copyWith(height: 1.5),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.resolve(
                                AppColors.error, AppDarkColors.error),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.resolve(
                                    AppColors.error, AppDarkColors.error)
                                .withValues(alpha: 0.6),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : Text(
                                  'Se déconnecter',
                                  style: AppTypography.labelLarge(
                                      color: Colors.white),
                                ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.resolve(
                                AppColors.inkMuted, AppDarkColors.inkMuted),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                          child: Text(
                            'Annuler',
                            style: AppTypography.labelLarge(
                              color: AppColors.resolve(
                                  AppColors.inkMuted, AppDarkColors.inkMuted),
                            ),
                          ),
                        ),
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
}

class _LogoutHeader extends StatelessWidget {
  const _LogoutHeader();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.xl),
      ),
      child: Container(
        width: double.infinity,
        height: 130,
        decoration: BoxDecoration(
          color: AppColors.errorLight,
        ),
        child: Stack(
          children: [
            Center(
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.error.withValues(alpha: 0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  size: 28,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
