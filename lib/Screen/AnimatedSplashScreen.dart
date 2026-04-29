import 'package:flutter/material.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dios_delices/Screen/authentification/Signup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/app_bootstrap_service.dart';
import '../theme/app_theme.dart';
import '../utils/toast.dart';

class AnimatedSplashScreen extends ConsumerStatefulWidget {
  const AnimatedSplashScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends ConsumerState<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  bool isLoading = false;
  bool showContent = false;

  Future<bool> isConnectedToInternet() async {
    final connectivityResults = await Connectivity().checkConnectivity();
    return !connectivityResults.contains(ConnectivityResult.none);
  }

  late AnimationController animationController;
  late Animation<double> logoScale;
  late Animation<double> logoOpacity;
  late Animation<Offset> contentSlide;

  @override
  void initState() {
    super.initState();

    animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    final curved = CurvedAnimation(
      parent: animationController,
      curve: Curves.easeOutCubic,
    );

    logoScale = Tween<double>(begin: 0.84, end: 1).animate(curved);
    logoOpacity = Tween<double>(begin: 0.3, end: 1).animate(curved);
    contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(curved);

    animationController.forward();
    Future<void>.delayed(const Duration(milliseconds: 220), () {
      if (mounted) {
        setState(() {
          showContent = true;
        });
      }
    });
    startTime();
  }

  void startTime() {
    const splashDelay = Duration(milliseconds: 2300);
    Timer(splashDelay, getData);
  }

  Future<void> getData() async {
    if (!(await isConnectedToInternet())) {
      if (!mounted) return;
      Toast(context, "Connectez-vous à internet pour continuer", false);
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await AppBootstrapService.syncInitialData();

      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      Toast(context, e.toString(), false);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        reverseTransitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: const SignUpView(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF8F3),
                  Color(0xFFF7E3D4),
                  Color(0xFFE9B894),
                ],
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -30,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                color: Color(0x33C84C2F),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -90,
            bottom: -40,
            child: Container(
              width: 240,
              height: 240,
              decoration: const BoxDecoration(
                color: Color(0x22F2B15A),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 800),
                    opacity: showContent ? 1 : 0,
                    child: Text(
                      'Dios Délices',
                      style: theme.textTheme.titleLarge?.copyWith(
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: FadeTransition(
                      opacity: logoOpacity,
                      child: ScaleTransition(
                        scale: logoScale,
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(36),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1F000000),
                                blurRadius: 30,
                                offset: Offset(0, 16),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: Image.asset(
                              'assets/images/round_logo.png',
                              width: 132,
                              height: 132,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 34),
                  SlideTransition(
                    position: contentSlide,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 700),
                      opacity: showContent ? 1 : 0,
                      child: Column(
                        children: [
                          Text(
                            'La cuisine de quartier, plus chaleureuse et plus simple.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontSize: 32,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Découvrez, commandez et gérez vos micro-restaurants avec une expérience plus fluide.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: AppColors.inkMuted,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 30),
                          if (isLoading)
                            Column(
                              children: [
                                const SizedBox(
                                  width: 34,
                                  height: 34,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Préparation de votre expérience…',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
