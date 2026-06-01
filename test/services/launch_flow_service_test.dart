import 'package:dios_delices/core/app_role.dart';
import 'package:dios_delices/services/launch_flow_service.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LaunchFlowService.decideDestination', () {
    test('shows onboarding on first launch even when a session exists', () {
      final destination = LaunchFlowService.decideDestination(
        isFirstLaunch: true,
        session: const UserSession(
          userId: 1,
          role: AppRole.admin,
          country: 'France',
          isLoggedIn: true,
        ),
      );

      expect(destination, LaunchDestination.onboarding);
    });

    test('opens home when returning user is logged in', () {
      final destination = LaunchFlowService.decideDestination(
        isFirstLaunch: false,
        session: const UserSession(
          userId: 2,
          role: AppRole.individual,
          country: 'France',
          isLoggedIn: true,
        ),
      );

      expect(destination, LaunchDestination.home);
    });

    test('opens signup when returning user has no active session', () {
      final destination = LaunchFlowService.decideDestination(
        isFirstLaunch: false,
        session: const UserSession(
          userId: 0,
          role: AppRole.unknown,
          country: 'France',
        ),
      );

      expect(destination, LaunchDestination.signup);
    });
  });
}
