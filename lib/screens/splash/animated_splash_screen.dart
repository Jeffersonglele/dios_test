import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dios_delices/providers/theme_provider.dart';
import 'package:dios_delices/screens/auth/signup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/users.dart';
import '../../services/app_bootstrap_service.dart';
import '../../services/launch_flow_service.dart';
import '../../services/session_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/toast.dart';
import '../../widgets/brand_avatar_logo.dart';
import '../../l10n/app_localizations.dart';
import '../onboarding/verification_page.dart';

// ═══════════════════════════════════════════════════════════
// AnimatedSplashScreen
// ═══════════════════════════════════════════════════════════

class AnimatedSplashScreen extends ConsumerStatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  ConsumerState<AnimatedSplashScreen> createState() =>
      _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends ConsumerState<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _splashController;
  late final AnimationController _pulseController;
  late final PageController _pageController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _pulse;

  bool _isLoading = false;
  bool _showOnboarding = false;
  double _currentPage = 0.0;

  static const List<_OnboardingStep> _steps = [
    _OnboardingStep(
      imagePath: 'assets/images/onboarding/slide1.png',
      accentColor: Color(0xFFFFF0E4),
      accentColorDark: Color(0xFF2A1812),
      titleKey: 'onboarding_step_1_title',
      bodyKey: 'onboarding_step_1_body',
    ),
    _OnboardingStep(
      imagePath: 'assets/images/onboarding/slide2.png',
      accentColor: Color(0xFFF0F7ED),
      accentColorDark: Color(0xFF14221A),
      titleKey: 'onboarding_step_2_title',
      bodyKey: 'onboarding_step_2_body',
    ),
    _OnboardingStep(
      imagePath: 'assets/images/onboarding/slide3.png',
      accentColor: Color(0xFFFFF4DC),
      accentColorDark: Color(0xFF2A1F10),
      titleKey: 'onboarding_step_3_title',
      bodyKey: 'onboarding_step_3_body',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initAnimations();
    _pageController.addListener(() {
      if (mounted) setState(() => _currentPage = _pageController.page ?? 0.0);
    });
    _splashController.forward();
    _bootstrapApp();
  }

  void _initAnimations() {
    _splashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.0, 0.55, curve: AppMotion.standard),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.45, 0.90, curve: AppMotion.standard),
      ),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _splashController,
        curve: const Interval(0.45, 0.90, curve: AppMotion.standard),
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _bootstrapApp() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    final isConnected = await _checkConnectivity();
    if (!isConnected) {
      if (!mounted) return;
      Toast(context, AppLocalizations.of(context)!.internet_required, false);
      return;
    }
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await AppBootstrapService.syncInitialData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Toast(context, e.toString(), false);
      return;
    }

    // Notification consent popup
    try {
      if (!await NotificationService.isPermissionGranted) {
        final prefs = await SharedPreferences.getInstance();
        final asked = prefs.getBool('notification_consent_asked') ?? false;
        if (!asked) {
          await prefs.setBool('notification_consent_asked', true);
          if (mounted) {
            final accept = await _showNotificationConsentDialog();
            if (accept ?? false) {
              await NotificationService.requestPermissions();
            }
          }
        }
      }
    } catch (_) {}

    final destination = await LaunchFlowService.resolveDestination();
    if (!mounted) return;
    setState(() => _isLoading = false);
    switch (destination) {
      case LaunchDestination.onboarding:
        setState(() => _showOnboarding = true);
        break;
      case LaunchDestination.signup:
        _navigateToSignup();
        break;
      case LaunchDestination.home:
        final session = await SessionService.readSession();
        if (!mounted) return;
        Users.chooseCurvedNavigation(session.role.id, session.country, context);
        break;
      case LaunchDestination.verification:
        final session = await SessionService.readSession();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerificationPage(
              email: session.email ?? '',
              userID: session.userId,
              roleID: session.role.id,
              country: session.country,
            ),
          ),
        );
        break;
    }
  }

  Future<bool> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  Future<bool?> _showNotificationConsentDialog() async {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.resolve(AppColors.brand, AppDarkColors.brand)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.notifications_active_rounded,
                color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(l10n.enable_notifications_title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600))),
        ]),
        content: Text(
          l10n.enable_notifications_body,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.later,
                style: TextStyle(
                    color: AppColors.resolve(
                        AppColors.inkMuted, AppDarkColors.inkMuted))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  AppColors.resolve(AppColors.brand, AppDarkColors.brand),
              foregroundColor:
                  AppColors.resolve(AppColors.card, AppDarkColors.card),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: Text(l10n.enable_button),
          ),
        ],
      ),
    );
  }

  void _navigateToSignup() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity:
              CurvedAnimation(parent: animation, curve: AppMotion.standard),
          child: const SignUpView(),
        ),
      ),
    );
  }

  void _onNextStep() {
    final next = _currentPage.round() + 1;
    if (next >= _steps.length) {
      _completeOnboarding();
    } else {
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: AppMotion.standard,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    await LaunchFlowService.markOnboardingSeen();
    if (!mounted) return;
    _navigateToSignup();
  }

  @override
  void dispose() {
    _splashController.dispose();
    _pulseController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: darkModeNotifier,
      builder: (context, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: AppMotion.standard,
          switchOutCurve: AppMotion.accelerate,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          child: _showOnboarding
              ? _OnboardingView(
                  key: const ValueKey('onboarding'),
                  steps: _steps,
                  pageController: _pageController,
                  currentPage: _currentPage,
                  onNext: _onNextStep,
                  onSkip: _completeOnboarding,
                )
              : _SplashView(
                  key: const ValueKey('splash'),
                  splashController: _splashController,
                  pulseController: _pulseController,
                  logoScale: _logoScale,
                  logoOpacity: _logoOpacity,
                  textOpacity: _textOpacity,
                  textSlide: _textSlide,
                  pulse: _pulse,
                  isLoading: _isLoading,
                ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SPLASH VIEW
// ═══════════════════════════════════════════════════════════

class _SplashView extends StatelessWidget {
  const _SplashView({
    super.key,
    required this.splashController,
    required this.pulseController,
    required this.logoScale,
    required this.logoOpacity,
    required this.textOpacity,
    required this.textSlide,
    required this.pulse,
    required this.isLoading,
  });

  final AnimationController splashController;
  final AnimationController pulseController;
  final Animation<double> logoScale;
  final Animation<double> logoOpacity;
  final Animation<double> textOpacity;
  final Animation<Offset> textSlide;
  final Animation<double> pulse;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: darkModeNotifier,
      builder: (context, _) {
        final gradStart =
            AppColors.resolve(AppColors.brandLight, AppDarkColors.brandDark);
        final gradEnd = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
        return Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      gradStart,
                      gradEnd,
                    ],
                  ),
                ),
                child: const SizedBox.expand(),
              ),
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(flex: 3),
                    Center(
                      child: AnimatedBuilder(
                        animation: Listenable.merge(
                            [splashController, pulseController]),
                        builder: (context, child) {
                          final introFinished = splashController.value >= 0.55;
                          final scale =
                              introFinished ? pulse.value : logoScale.value;
                          final opacity = introFinished
                              ? 1.0
                              : logoOpacity.value.clamp(0.0, 1.0);
                          return Transform.scale(
                            scale: scale,
                            child: Opacity(opacity: opacity, child: child),
                          );
                        },
                        child: const _SplashLogo(),
                      ),
                    ),
                    const Spacer(flex: 3),
                    Center(
                      child: FadeTransition(
                        opacity: textOpacity,
                        child: SlideTransition(
                          position: textSlide,
                          child: _SplashTagline(isLoading: isLoading),
                        ),
                      ),
                    ),
                    const Spacer(flex: 2),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Logo : cercle blanc avec ombre douce ──────────────────
class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: AppColors.brandDark.withValues(alpha: 0.30),
                blurRadius: 40,
                spreadRadius: -4,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: BrandAvatarLogo(radius: 40, glow: false, elevation: 0),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          AppLocalizations.of(context)!.appTitle,
          style: AppTypography.titleLarge().copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ── Slogan + indicateur chargement ───────────────────────
class _SplashTagline extends StatelessWidget {
  const _SplashTagline({required this.isLoading});
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final parts =
        AppLocalizations.of(context)!.onboarding_splash_subtitle.split('\n');
    final resolvedAccent =
        AppColors.resolve(AppColors.accent, AppDarkColors.accent);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: '${parts[0]}\n',
                style: AppTypography.displayMedium().copyWith(
                  fontSize: 30,
                  height: 1.18,
                  color: Colors.white,
                ),
              ),
              TextSpan(
                text: parts.length > 1 ? parts[1] : '',
                style: AppTypography.displayMedium().copyWith(
                  fontSize: 30,
                  height: 1.18,
                  color: resolvedAccent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          AppLocalizations.of(context)!.splash_subtitle,
          textAlign: TextAlign.center,
          style: AppTypography.bodyLarge(
            color: AppColors.resolve(AppColors.card, AppDarkColors.card)
                .withValues(alpha: 0.78),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AnimatedSize(
          duration: AppMotion.normal,
          curve: Curves.easeInOut,
          child:
              isLoading ? const _LoadingIndicator() : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ── Loader blanc ──────────────────────────────────────────
class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Colors.white),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          AppLocalizations.of(context)!.splash_loading,
          style: AppTypography.bodyMedium(
            color: AppColors.resolve(AppColors.card, AppDarkColors.card)
                .withValues(alpha: 0.78),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ONBOARDING VIEW
// ═══════════════════════════════════════════════════════════

class _OnboardingView extends StatefulWidget {
  const _OnboardingView({
    super.key,
    required this.steps,
    required this.pageController,
    required this.currentPage,
    required this.onNext,
    required this.onSkip,
  });

  final List<_OnboardingStep> steps;
  final PageController pageController;
  final double currentPage;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  State<_OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<_OnboardingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _entryOpacity;
  late final Animation<Offset> _entrySlide;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _entryOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: AppMotion.standard),
    );
    _entrySlide = Tween<Offset>(
      begin: const Offset(0.0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entryController, curve: AppMotion.standard),
    );
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_entryController, darkModeNotifier]),
      builder: (context, _) {
        final isLast = widget.currentPage.round() == widget.steps.length - 1;
        final screenH = MediaQuery.of(context).size.height;
        final Color bgColor =
            _interpolateStepColor(widget.currentPage, widget.steps);

        return Scaffold(
          backgroundColor: bgColor,
          body: FadeTransition(
            opacity: _entryOpacity,
            child: SlideTransition(
              position: _entrySlide,
              child: Column(
                children: [
                  // ── Zone image — 55% de l'écran ──────────────
                  _OnboardingImageZone(
                    steps: widget.steps,
                    pageController: widget.pageController,
                    currentPage: widget.currentPage,
                    bgColor: bgColor,
                    height: screenH * 0.55,
                    onSkip: widget.onSkip,
                  ),
                  // ── Zone texte basse ─────────────────────────
                  Expanded(
                    child: _OnboardingBottomSheet(
                      steps: widget.steps,
                      currentPage: widget.currentPage,
                      isLast: isLast,
                      onNext: widget.onNext,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Color _interpolateStepColor(
      double currentPage, List<_OnboardingStep> steps) {
    final int idx = currentPage.floor().clamp(0, steps.length - 1);
    final int nextIdx = (idx + 1).clamp(0, steps.length - 1);
    final double t = (currentPage - idx).clamp(0.0, 1.0);
    final isDark = darkModeNotifier.value;
    final Color start =
        isDark ? steps[idx].accentColorDark : steps[idx].accentColor;
    final Color end =
        isDark ? steps[nextIdx].accentColorDark : steps[nextIdx].accentColor;
    return Color.lerp(start, end, t)!;
  }
}

// ═══════════════════════════════════════════════════════════
// Zone image
// — Badge marque supprimé
// — Skip seul, fond opaque, en haut à droite
// ═══════════════════════════════════════════════════════════
class _OnboardingImageZone extends StatelessWidget {
  const _OnboardingImageZone({
    required this.steps,
    required this.pageController,
    required this.currentPage,
    required this.bgColor,
    required this.height,
    required this.onSkip,
  });

  final List<_OnboardingStep> steps;
  final PageController pageController;
  final double currentPage;
  final Color bgColor;
  final double height;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          PageView.builder(
            controller: pageController,
            itemCount: steps.length,
            itemBuilder: (_, index) => Image.asset(
              steps[index].imagePath,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          // ── Fondu bas pour raccorder avec la feuille ────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 100,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, bgColor],
                ),
              ),
            ),
          ),

          // ── Bouton Skip seul — haut droite, fond opaque ─
          Positioned(
            top: MediaQuery.of(context).padding.top + AppSpacing.md,
            right: AppSpacing.lg,
            child: _SolidSkipButton(onSkip: onSkip),
          ),
        ],
      ),
    );
  }
}

// ── Bouton Skip — fond opaque garanti lisible ─────────────
class _SolidSkipButton extends StatelessWidget {
  const _SolidSkipButton({required this.onSkip});
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSkip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.resolve(AppColors.card, AppDarkColors.card)
              .withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
              color: AppColors.resolve(AppColors.border, AppDarkColors.border),
              width: 0.8),
          boxShadow: [AppShadows.subtle],
        ),
        child: Text(
          AppLocalizations.of(context)!.skip,
          style: AppTypography.labelMedium(
                  color: AppColors.resolve(
                      AppColors.inkMuted, AppDarkColors.inkMuted))
              .copyWith(
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Feuille basse : texte + dots + bouton
// ═══════════════════════════════════════════════════════════
class _OnboardingBottomSheet extends StatelessWidget {
  const _OnboardingBottomSheet({
    required this.steps,
    required this.currentPage,
    required this.isLast,
    required this.onNext,
  });

  final List<_OnboardingStep> steps;
  final double currentPage;
  final bool isLast;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.surface, AppDarkColors.surface),
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Poignée ───────────────────────────────────
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      AppColors.resolve(AppColors.border, AppDarkColors.border),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Bloc texte animé (scrollable) ─────────────
            Flexible(
              child: SingleChildScrollView(
                child: Stack(
                  children: List.generate(steps.length, (index) {
                    final delta = (index - currentPage).abs();
                    final opacity = (1.0 - delta * 1.5).clamp(0.0, 1.0);
                    final slideOffset = (currentPage - index) * 0.04;
                    return Opacity(
                      opacity: opacity,
                      child: Transform.translate(
                        offset: Offset(slideOffset * 30, 0),
                        child: IgnorePointer(
                          ignoring: index != currentPage.round(),
                          child: _OnboardingTextBlock(
                            title: AppLocalizations.of(context)!
                                .localized(steps[index].titleKey),
                            body: AppLocalizations.of(context)!
                                .localized(steps[index].bodyKey),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── [Dots] ──────── [Bouton Suivant/Commencer] ─
            Row(
              children: [
                _ElasticDots(
                  totalSteps: steps.length,
                  currentPage: currentPage,
                ),
                const Spacer(),
                _NextButton(
                  isLast: isLast,
                  onNext: onNext,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dots élastiques ───────────────────────────────────────
class _ElasticDots extends StatelessWidget {
  const _ElasticDots({
    required this.totalSteps,
    required this.currentPage,
  });

  final int totalSteps;
  final double currentPage;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalSteps, (i) {
        final delta = (currentPage - i).abs();
        final widthFactor = (1.0 - delta).clamp(0.0, 1.0);
        final dotWidth = 8.0 + 20.0 * widthFactor;
        final isActive = currentPage.round() == i;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: AppMotion.standard,
          width: dotWidth,
          height: 8,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.resolve(AppColors.brand, AppDarkColors.brand)
                : AppColors.resolve(AppColors.border, AppDarkColors.border),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

// ── Bouton Suivant / Commencer ────────────────────────────
// Utilise minWidth au lieu d'une largeur fixe : le bouton
// s'élargit automatiquement si le texte traduit est plus long.
class _NextButton extends StatelessWidget {
  const _NextButton({required this.isLast, required this.onNext});
  final bool isLast;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor:
            AppColors.resolve(AppColors.brand, AppDarkColors.brand),
        foregroundColor: AppColors.resolve(AppColors.card, AppDarkColors.card),
        elevation: 0,
        minimumSize: const Size(148, 52),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        textStyle: AppTypography.labelLarge().copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      onPressed: onNext,
      child: Text(
        isLast
            ? AppLocalizations.of(context)!.start
            : AppLocalizations.of(context)!.next,
        maxLines: 1,
        overflow: TextOverflow.visible,
        softWrap: false,
      ),
    );
  }
}

// ── Extension pour la résolution dynamique ────────────────
extension AppLocalizationsDynamic on AppLocalizations {
  String localized(String key) {
    switch (key) {
      case 'onboarding_step_1_title':
        return onboarding_step_1_title;
      case 'onboarding_step_1_body':
        return onboarding_step_1_body;
      case 'onboarding_step_2_title':
        return onboarding_step_2_title;
      case 'onboarding_step_2_body':
        return onboarding_step_2_body;
      case 'onboarding_step_3_title':
        return onboarding_step_3_title;
      case 'onboarding_step_3_body':
        return onboarding_step_3_body;
      default:
        return key;
    }
  }
}

// ── Bloc texte ────────────────────────────────────────────
class _OnboardingTextBlock extends StatelessWidget {
  const _OnboardingTextBlock({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AppTypography.headlineMedium(
                  color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))
              .copyWith(
            height: 1.15,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          body,
          style: AppTypography.bodyMedium(
              color: AppColors.resolve(
                  AppColors.inkMuted, AppDarkColors.inkMuted)),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Modèles internes
// ═══════════════════════════════════════════════════════════
class _OnboardingStep {
  const _OnboardingStep({
    required this.imagePath,
    required this.accentColor,
    required this.accentColorDark,
    required this.titleKey,
    required this.bodyKey,
  });

  final String imagePath;
  final Color accentColor;
  final Color accentColorDark;
  final String titleKey;
  final String bodyKey;
}
