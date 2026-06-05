import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const forceOnboardingInDebug = true;

  static Future<LaunchDestination> resolveDestination() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool(_hasSeenOnboardingKey) ?? false;
    final session = await SessionService.readSession();
    final isVerified = prefs.getBool('userVerified') ?? false;

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
    if (isFirstLaunch) {
      return LaunchDestination.onboarding;
    }

    if (session.isLoggedIn && session.userId > 0 && session.role.id > 0) {
      if (!isVerified && (session.email?.isNotEmpty ?? false)) {
        return LaunchDestination.verification;
      }
      return LaunchDestination.home;
    }

    return LaunchDestination.signup;
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
