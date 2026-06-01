import 'package:shared_preferences/shared_preferences.dart';

import 'session_service.dart';

enum LaunchDestination {
  onboarding,
  signup,
  home,
  browse,
}

class LaunchFlowService {
  const LaunchFlowService._();

  static const _hasSeenOnboardingKey = 'hasSeenOnboarding';

  static Future<LaunchDestination> resolveDestination() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool(_hasSeenOnboardingKey) ?? false;
    final session = await SessionService.readSession();

    return decideDestination(
      isFirstLaunch: !hasSeenOnboarding,
      session: session,
    );
  }

  static LaunchDestination decideDestination({
    required bool isFirstLaunch,
    required UserSession session,
  }) {
    if (isFirstLaunch) {
      return LaunchDestination.onboarding;
    }

    if (session.isLoggedIn && session.userId > 0 && session.role.id > 0) {
      return LaunchDestination.home;
    }

    return LaunchDestination.browse;
  }

  static Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenOnboardingKey, true);
  }
}
