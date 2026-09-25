import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_role.dart';
import '../screens/auth/login.dart';
import '../services/session_service.dart';

/// Surveille l'état du compte pendant que l'application est ouverte.
///
/// Une validation admin modifie le rôle sur Parse, mais ne révoque pas les
/// autres appareils. L'appareil concerné se déconnecte donc localement dès
/// qu'il détecte le passage client -> vendeur, puis l'utilisateur se reconnecte
/// pour être envoyé vers la bonne session.
class SessionGuard extends StatefulWidget {
  const SessionGuard({super.key, required this.child, required this.navigatorKey});

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<SessionGuard>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _checking = false;
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAccount());
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _checkAccount());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkAccount();
  }

  Future<void> _checkAccount() async {
    if (_checking || _redirecting) return;
    _checking = true;
    try {
      final session = await SessionService.readSession();
      if (!session.isLoggedIn || session.userId == 0) return;

      final server = await SessionService.fetchServerAccountState();
      if (server == null || server.userId != session.userId) return;

      final wasClient = session.role == AppRole.individual;
      final isNowSeller = server.roleId == AppRole.microRestaurant.id;
      if (!wasClient || !isNowSeller) return;

      _redirecting = true;
      await SessionService.logout();
      final navigator = widget.navigatorKey.currentState;
      if (navigator == null) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const Login()),
        (route) => false,
      );
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
