import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../core/app_role.dart';
import '../../models/users.dart';
import '../../services/courier_application_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/toast.dart';
import '../splash/animated_splash_screen.dart';
import 'courier_onboarding_page.dart';

/// Dossier envoyé, en attente de la décision de l'administration.
/// « Vérifier mon statut » interroge le serveur : validé → espace de travail,
/// refusé → nouveau dossier avec le motif.
class WaitIdentityValidation extends StatefulWidget {
  const WaitIdentityValidation({super.key});

  @override
  State<WaitIdentityValidation> createState() => _WaitIdentityValidationState();
}

class _WaitIdentityValidationState extends State<WaitIdentityValidation> {
  bool _checking = false;

  Future<void> _checkStatus() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _checking = true);
    try {
      final state = await SessionService.fetchServerAccountState();
      if (!mounted) return;
      if (state == null) {
        Toast(context, l10n.error, false);
        return;
      }
      if (CourierApplicationService.isVerified(state.identity)) {
        final session = await SessionService.readSession();
        if (!mounted) return;
        Users.chooseCurvedNavigation(
            AppRole.livreur.id, session.country, context);
      } else if (state.identity.toLowerCase() == 'rejected') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CourierOnboardingPage()),
        );
      } else {
        Toast(context, l10n.courier_wait_still_pending, true);
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _goHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AnimatedSplashScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final surface = AppColors.resolve(AppColors.surface, AppDarkColors.surface);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: surface,
        leading: IconButton(
          icon: const Icon(Icons.home_rounded),
          onPressed: _goHome,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: brand.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.hourglass_top_rounded,
                      color: brand, size: 34),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.wait_identity_title,
                textAlign: TextAlign.center,
                style: AppTypography.headlineMedium(color: ink),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.wait_identity_body,
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge(color: muted)
                    .copyWith(height: 1.45),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _checking ? null : _checkStatus,
                  icon: _checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(l10n.courier_wait_check_status,
                      style: AppTypography.labelLarge(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _goHome,
                child: Text(l10n.confirmation_back_home,
                    style: AppTypography.labelMedium(color: muted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
