import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../authentification/Login.dart';

class PasswordChangeSuccessScreen extends StatelessWidget {
  const PasswordChangeSuccessScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
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
                  boxShadow: [
                    BoxShadow(color: AppColors.success.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: const Icon(Icons.check_rounded, color: AppColors.success, size: 48),
              ),
              const SizedBox(height: 28),
              Text('Mot de passe réinitialisé !', style: AppTypography.headlineMedium(), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text('Votre mot de passe a été changé avec succès. Vous pouvez maintenant vous connecter.',
                  style: AppTypography.bodyLarge(color: AppColors.inkMuted), textAlign: TextAlign.center),
              const SizedBox(height: 32),
              SizedBox(width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushAndRemoveUntil(context,
                      MaterialPageRoute(builder: (_) => const Login()), (_) => false),
                  child: const Text('Se connecter'),
                )),
            ]),
          ),
        ),
      ),
    );
  }
}
