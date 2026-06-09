import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../models/users.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

class WelcomeScreen extends StatefulWidget {
  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late ConfettiController _confettiController;
  bool _showButton = false;

  @override
  void initState() {
    super.initState();

    _confettiController = ConfettiController(duration: const Duration(seconds: 5));
    _confettiController.play();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showButton = true);
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final session = await SessionService.readSession();
    if (mounted) {
      await Users.updateDerniereConnexion(session.userId);
      Users.chooseCurvedNavigation(session.role.id, session.country, context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: [Colors.red, Colors.green, Colors.blue, Colors.orange],
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.brandSurface,
                        border: Border.all(color: AppColors.brand.withValues(alpha: 0.2), width: 2),
                      ),
                      child: const Icon(Icons.check_rounded, color: AppColors.brand, size: 44),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.welcome_title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.welcome_subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, color: Colors.black54),
                    ),
                    const SizedBox(height: 32),
                    if (_showButton)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _continue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(l10n.welcome_discover, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
