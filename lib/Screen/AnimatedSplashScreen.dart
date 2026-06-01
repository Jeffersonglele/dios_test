import 'dart:async';

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
import 'GuestBrowsePage.dart';

class AnimatedSplashScreen extends ConsumerStatefulWidget {
  const AnimatedSplashScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AnimatedSplashScreen> createState() =>
      _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends ConsumerState<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController animationController;
  late final Animation<double> logoScale;
  late final Animation<double> logoOpacity;
  late final Animation<Offset> contentSlide;

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

  Future<bool> isConnectedToInternet() async {
    final connectivityResults = await Connectivity().checkConnectivity();
    return !connectivityResults.contains(ConnectivityResult.none);
  }

  void startTime() {
    const splashDelay = Duration(milliseconds: 1800);
    Timer(splashDelay, getData);
  }

  Future<void> getData() async {
    if (!(await isConnectedToInternet())) {
      if (!mounted) return;
      Toast(context, Strings.of('internet_required'), false);
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await AppBootstrapService.syncInitialData();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      Toast(context, e.toString(), false);
      return;
    }

    final destination = await LaunchFlowService.resolveDestination();
    if (!mounted) return;

    setState(() {
      isLoading = false;
    });

    switch (destination) {
      case LaunchDestination.onboarding:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            showOnboarding = true;
          });
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
      case LaunchDestination.browse:
        _goToBrowse();
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
          opacity: animation,
          child: const SignUpView(),
        ),
      ),
    );
  }

  void _goToBrowse() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        reverseTransitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: const GuestBrowsePage(),
        ),
      ),
    );
  }

  void _goToNextStep() {
    if (currentStep == steps.length - 1) {
      _completeOnboarding();
      return;
    }

    setState(() {
      currentStep += 1;
    });
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (showOnboarding) {
      return _buildOnboarding(context);
    }

    return _buildSplash(context);
  }

  Widget _buildSplash(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/background.jpg',
            fit: BoxFit.cover,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.surface.withValues(alpha: 0.92),
                  AppColors.surface.withValues(alpha: 0.82),
                  const Color(0xFFFFDCC3).withValues(alpha: 0.96),
                ],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.2, -0.18),
                radius: 0.86,
                colors: [
                  Color(0x00FFFFFF),
                  Color(0x7AFFF8F3),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 800),
                    opacity: showContent ? 1 : 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LogoMark(size: 34),
                        const SizedBox(width: 12),
                        Text(
                          'Dios Délices',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: AppColors.ink,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: FadeTransition(
                      opacity: logoOpacity,
                      child: ScaleTransition(
                        scale: logoScale,
                        child: SizedBox(
                          width: 118,
                          height: 118,
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x1F8E2F1B),
                                  blurRadius: 28,
                                  offset: Offset(0, 16),
                                ),
                              ],
                            ),
                            child: _LogoMark(size: 118),
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
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.68),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 24,
                              offset: Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                          child: Column(
                            children: [
                              Text(
                                Strings.of('splash_title'),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontSize: 30,
                                  height: 1.18,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                Strings.of('splash_subtitle'),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: AppColors.inkMuted,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 28),
                              if (isLoading)
                                Column(
                                  children: [
                                    const SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      Strings.of('splash_loading'),
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
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

  Widget _buildOnboarding(BuildContext context) {
    final theme = Theme.of(context);
    final step = steps[currentStep];

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: Image.asset(
              step.imagePath,
              key: ValueKey(step.imagePath),
              fit: BoxFit.cover,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.18),
                  Colors.black.withValues(alpha: 0.08),
                  Colors.black.withValues(alpha: 0.74),
                ],
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0xE6261814),
                    Color(0xFF261814),
                  ],
                ),
              ),
              child: SizedBox(height: 360),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x17000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LogoMark(size: 30),
                          const SizedBox(width: 10),
                          Text(
                            'Dios Délices',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.ink.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: Column(
                          key: ValueKey(step.titleKey),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              Strings.of(step.titleKey),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontSize: 31,
                                height: 1.12,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              Strings.of(step.bodyKey),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.white.withValues(alpha: 0.82),
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      ...List.generate(
                        steps.length,
                        (dotIndex) => AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          width: currentStep == dotIndex ? 28 : 9,
                          height: 9,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: currentStep == dotIndex
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _completeOnboarding,
                        child: Text(
                          Strings.of('skip'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 128,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            fixedSize: const Size(128, 48),
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
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
