import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'node_auth_service.dart';
import 'session_service.dart';

enum LaunchDestination {
  onboarding,
  signup,
  verification,
  home,
}

class LaunchFlowService {
  const LaunchFlowService._();

  static const _hasSeenOnboardingKey = 'hasSeenOnboarding';

  /// Mettre à `true` uniquement pour retravailler l'onboarding : il est
  /// alors affiché à chaque lancement en mode debug.
  static const forceOnboardingInDebug = false;

  static Future<LaunchDestination> resolveDestination() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool(_hasSeenOnboardingKey) ?? false;
    final session = await SessionService.readSession();
    var isVerified = prefs.getBool('userVerified') ?? false;
    if (!isVerified && session.isLoggedIn) {
      isVerified = await _verifiedOnServer();
      if (isVerified) await prefs.setBool('userVerified', true);
    }

    return decideDestination(
      isFirstLaunch:
          !hasSeenOnboarding || (kDebugMode && forceOnboardingInDebug),
      session: session,
      isVerified: isVerified,
    );
  }

  static LaunchDestination decideDestination({
    required bool isFirstLaunch,
    required UserSession session,
    bool isVerified = false,
  }) {
    // Un utilisateur connecté va directement dans son espace : l'onboarding
    // ne concerne que la toute première ouverture, avant tout compte.
    if (session.isLoggedIn && session.userId > 0 && session.role.id > 0) {
      if (!isVerified && (session.email?.isNotEmpty ?? false)) {
        return LaunchDestination.verification;
      }
      return LaunchDestination.home;
    }

    if (isFirstLaunch) {
      return LaunchDestination.onboarding;
    }

    return LaunchDestination.signup;
  }

  /// Compte connecté avant que le drapeau local existe : le serveur fait foi.
  /// En cas d'échec réseau, on ne bloque pas l'utilisateur.
  static Future<bool> _verifiedOnServer() async {
    final token = await SessionService.readNodeToken();
    if (token == null) return false;
    try {
      final me = await NodeAuthService.me(token)
          .timeout(const Duration(seconds: 6));
      final status = me['status']?.toString().toLowerCase() ?? '';
      return status == 'verified' || me['emailVerified'] == true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> markOnboardingSeen() async {
    if (kDebugMode && forceOnboardingInDebug) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenOnboardingKey, true);
  }

  static Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hasSeenOnboardingKey);
  }
}
