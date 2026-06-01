import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dios_delices/Screen/authentification/Signup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../modeles/users.dart';
import '../services/app_bootstrap_service.dart';
import '../services/launch_flow_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../utils/toast.dart';
import '../widgets/brand_avatar_logo.dart';
import '../utils/strings.dart';

class AnimatedSplashScreen extends ConsumerStatefulWidget {
  const AnimatedSplashScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AnimatedSplashScreen> createState() =>
      _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends ConsumerState<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoRotate;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;

  bool isLoading = false;
  bool showContent = false;
  bool showOnboarding = false;
  int currentStep = 0;

  final List<_OnboardingStep> steps = const [
    _OnboardingStep(
      imagePath: 'assets/images/background.jpg',
      titleKey: 'onboarding_step_1_title',
      bodyKey: 'onboarding_step_1_body',
    ),
    _OnboardingStep(
      imagePath: 'assets/images/meals/pancakes.jpeg',
      titleKey: 'onboarding_step_2_title',
      bodyKey: 'onboarding_step_2_body',
    ),
    _OnboardingStep(
      imagePath: 'assets/images/meals/pizza.jpeg',
      titleKey: 'onboarding_step_3_title',
      bodyKey: 'onboarding_step_3_body',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // Animation 3D : rotation + scale du logo
    final curved = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.55, curve: AppMotion.standard),
    );
    final textCurve = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.7, curve: AppMotion.standard),
    );

    _logoScale = Tween<double>(begin: 0.4, end: 1).animate(curved);
    _logoRotate = Tween<double>(begin: -0.12, end: 0).animate(curved);
    _textOpacity = Tween<double>(begin: 0, end: 1).animate(textCurve);
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(textCurve);

    _controller.forward();
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => showContent = true);
    });
    startTime();
  }

  Future<bool> isConnectedToInternet() async {
    final results = await Connectivity().checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  void startTime() {
    Timer(const Duration(milliseconds: 2200), getData);
  }

  Future<void> getData() async {
    if (!(await isConnectedToInternet())) {
      if (!mounted) return;
      Toast(context, Strings.of('internet_required'), false);
      return;
    }

    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      await AppBootstrapService.syncInitialData();
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      Toast(context, e.toString(), false);
      return;
    }

    final destination = await LaunchFlowService.resolveDestination();
    if (!mounted) return;
    setState(() => isLoading = false);

    switch (destination) {
      case LaunchDestination.onboarding:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => showOnboarding = true);
        });
        break;
      case LaunchDestination.signup:
        _goToSignup();
        break;
      case LaunchDestination.home:
        final session = await SessionService.readSession();
        if (!mounted) return;
        Users.chooseCurvedNavigation(session.role.id, session.country, context);
        break;
    }
  }

  Future<void> _completeOnboarding() async {
    await LaunchFlowService.markOnboardingSeen();
    if (!mounted) return;
    _goToSignup();
  }

  void _goToSignup() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        reverseTransitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: AppMotion.standard,
          ),
          child: const SignUpView(),
        ),
      ),
    );
  }

  void _goToNextStep() {
    if (currentStep == steps.length - 1) {
      _completeOnboarding();
      return;
    }
    setState(() => currentStep += 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (showOnboarding) return _buildOnboarding(context);
    return _buildSplash(context);
  }

  // ═══════════════════════════════════════════════════════════
  // SPLASH — Logo 3D animé + fond dégradé signature
  // ═══════════════════════════════════════════════════════════
  Widget _buildSplash(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fond dégradé signature (crème → pêche pâle)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.surface,
                  AppColors.gradientEnd,
                  AppColors.surface,
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
            child: SizedBox.expand(),
          ),
          // Particules décoratives subtiles
          ...List.generate(6, (i) {
            final rng = math.Random(i * 7);
            return Positioned(
              left: 30 + rng.nextDouble() * 300,
              top: 80 + rng.nextDouble() * 500,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 12 + rng.nextDouble() * 8),
                duration: Duration(seconds: 2 + rng.nextInt(2)),
                builder: (_, v, __) => Transform.translate(
                  offset: Offset(0, math.sin(v * 0.5) * 4),
                  child: Container(
                    width: 5 + rng.nextDouble() * 6,
                    height: 5 + rng.nextDouble() * 6,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
          // Contenu principal
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo + marque haut de page
                  AnimatedOpacity(
                    duration: AppMotion.slow,
                    opacity: showContent ? 1 : 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LogoMark(size: 34),
                        const SizedBox(width: 12),
                        Text(
                          'Dios Délices',
                          style: AppTypography.titleLarge().copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 2),
                  // Logo 3D animé
                  Center(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001) // perspective
                            ..rotateY(_logoRotate.value)
                            ..scale(_logoScale.value),
                          child: child,
                        );
                      },
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.card,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brandDark.withValues(alpha: 0.22),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: _LogoMark(size: 106),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  // Slogan
                  FadeTransition(
                    opacity: _textOpacity,
                    child: SlideTransition(
                      position: _textSlide,
                      child: Column(
                        children: [
                          Text(
                            'Neighborhood cooking,',
                            textAlign: TextAlign.center,
                            style: AppTypography.displayMedium().copyWith(
                              fontSize: 32,
                              height: 1.12,
                            ),
                          ),
                          Text(
                            'warmer and simpler.',
                            textAlign: TextAlign.center,
                            style: AppTypography.displayMedium().copyWith(
                              fontSize: 32,
                              height: 1.12,
                              color: AppColors.brand,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            Strings.of('splash_subtitle'),
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyLarge(
                              color: AppColors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 40),
                          // Indicateur de chargement
                          if (isLoading)
                            Column(
                              children: [
                                const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  Strings.of('splash_loading'),
                                  style: AppTypography.bodyMedium(),
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

  // ═══════════════════════════════════════════════════════════
  // ONBOARDING — 3 slides immersifs plein écran
  // ═══════════════════════════════════════════════════════════
  Widget _buildOnboarding(BuildContext context) {
    final step = steps[currentStep];

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Image immersive avec transition fluide
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            switchInCurve: AppMotion.standard,
            switchOutCurve: AppMotion.accelerate,
            child: Image.asset(
              step.imagePath,
              key: ValueKey(step.imagePath),
              fit: BoxFit.cover,
            ),
          ),
          // Overlay dégradé chaud (pas noir froid)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x00261814),
                  Color(0x66261814),
                  Color(0xCC261814),
                  Color(0xFF261814),
                ],
                stops: [0.0, 0.35, 0.7, 1.0],
              ),
            ),
            child: SizedBox.expand(),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge marque
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.card.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: AppShadows.floatingList,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LogoMark(size: 28),
                        const SizedBox(width: 10),
                        Text(
                          'Dios Délices',
                          style: AppTypography.titleMedium().copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Carte de contenu avec fond chaud semi-transparent
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: AppMotion.standard,
                    child: Container(
                      key: ValueKey(step.titleKey),
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppColors.ink.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Strings.of(step.titleKey),
                            style: AppTypography.headlineLarge(
                              color: Colors.white,
                            ).copyWith(height: 1.12),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            Strings.of(step.bodyKey),
                            style: AppTypography.bodyLarge(
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Indicateur de progression + boutons
                  Row(
                    children: [
                      // Dots animés
                      ...List.generate(
                        steps.length,
                        (dotIndex) => AnimatedContainer(
                          duration: AppMotion.normal,
                          width: currentStep == dotIndex ? 32 : 10,
                          height: 10,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: currentStep == dotIndex
                                ? AppColors.accent
                                : Colors.white.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Skip
                      TextButton(
                        onPressed: _completeOnboarding,
                        child: Text(
                          Strings.of('skip'),
                          style: AppTypography.labelLarge(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Bouton suivant / démarrer
                      SizedBox(
                        width: 140,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.ink,
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            textStyle: AppTypography.labelLarge(
                              color: AppColors.ink,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                          onPressed: _goToNextStep,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              currentStep == steps.length - 1
                                  ? Strings.of('start')
                                  : Strings.of('next'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingStep {
  const _OnboardingStep({
    required this.imagePath,
    required this.titleKey,
    required this.bodyKey,
  });
  final String imagePath;
  final String titleKey;
  final String bodyKey;
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return BrandAvatarLogo(
      radius: size / 2,
      glow: size >= 80,
      elevation: size >= 80 ? 8 : 3,
    );
  }
}
