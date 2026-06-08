import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../auth/Login.dart';

class PasswordChangeSuccessScreen extends StatelessWidget {
  const PasswordChangeSuccessScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppDarkColors.surface : AppColors.surface;
    final inkMuted = isDark ? AppDarkColors.inkMuted : AppColors.inkMuted;

    return Scaffold(
      backgroundColor: surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.successLight,
                  boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: const Icon(Icons.check_rounded, color: AppColors.success, size: 48),
              ),
              const SizedBox(height: 28),
              Text('Password reset!', style: AppTypography.headlineMedium(), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text('Your password has been changed successfully. You can now log in.', style: AppTypography.bodyLarge(color: inkMuted), textAlign: TextAlign.center),
              const SizedBox(height: 32),
              SizedBox(width: double.infinity, height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg))),
                  onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const Login()), (_) => false),
                  child: Text(AppLocalizations.of(context)!.login, style: AppTypography.labelMedium(color: Colors.white)),
                )),
            ]),
          ),
        ),
      ),
    );
  }
}
