import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dios_delices/providers/theme_provider.dart';
import 'package:dios_delices/screens/auth/signup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/users.dart';
import '../../services/app_bootstrap_service.dart';
import '../../services/launch_flow_service.dart';
import '../../services/session_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/toast.dart';
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
      imagePath: 'assets/images/onboarding/slide4.png',
      accentColor: Color(0xFFF0F7ED),
      accentColorDark: Color(0xFF14221A),
      titleKey: 'onboarding_step_2_title',
      bodyKey: 'onboarding_step_2_body',
    ),
    _OnboardingStep(
      imagePath: 'assets/images/onboarding/slide5.png',
      accentColor: Color(0xFFFFF0E4),
      accentColorDark: Color(0xFF2A1812),
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
// SPLASH VIEW — épuré : fond crème signature, icône de l'app,
// logotype et une seule accroche. Le chargement est signalé par
// trois points discrets, sans texte.
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
        final bgTop = AppColors.resolve(
            AppColors.gradientStart, AppDarkColors.gradientStart);
        final bgBottom =
            AppColors.resolve(AppColors.gradientEnd, AppDarkColors.gradientEnd);
        final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
        final accent =
            AppColors.resolve(AppColors.accent, AppDarkColors.accent);

        final isDark = darkModeNotifier.value;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          // Fond clair : icônes de barre d'état sombres (et inversement).
          value:
              isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          child: Scaffold(
            backgroundColor: bgTop,
            body: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [bgTop, bgBottom],
                    ),
                  ),
                ),
                // Halos chauds très diffus : profondeur sans bruit visuel.
                Positioned(
                  top: -140,
                  right: -120,
                  child: _SoftGlow(
                      size: 360, color: brand.withValues(alpha: 0.10)),
                ),
                Positioned(
                  bottom: -160,
                  left: -140,
                  child: _SoftGlow(
                      size: 380, color: accent.withValues(alpha: 0.20)),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      const Spacer(flex: 5),
                      AnimatedBuilder(
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
                        child: const _SplashAppIcon(),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      FadeTransition(
                        opacity: textOpacity,
                        child: SlideTransition(
                          position: textSlide,
                          child: const _SplashWordmark(),
                        ),
                      ),
                      const Spacer(flex: 4),
                      SizedBox(
                        height: 24,
                        child: AnimatedOpacity(
                          duration: AppMotion.normal,
                          opacity: isLoading ? 1 : 0,
                          child: _DotsLoader(color: brand),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Halo radial (dégradé vers transparent), sans flou coûteux.
class _SoftGlow extends StatelessWidget {
  const _SoftGlow({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

// ── Icône de l'app avec ombre portée chaude ───────────────
class _SplashAppIcon extends StatelessWidget {
  const _SplashAppIcon();

  @override
  Widget build(BuildContext context) {
    const size = 116.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandDark.withValues(alpha: 0.30),
            blurRadius: 40,
            spreadRadius: -6,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/logo_circulaire.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

// ── Logotype teinté + accroche unique ─────────────────────
class _SplashWordmark extends StatelessWidget {
  const _SplashWordmark();

  @override
  Widget build(BuildContext context) {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Le fichier est carré avec beaucoup de marge transparente :
        // BoxFit.cover dans une boîte basse ne garde que la bande du texte.
        Semantics(
          label: AppLocalizations.of(context)!.appTitle,
          image: true,
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(brand, BlendMode.srcIn),
            child: Image.asset(
              'assets/images/logo-without-bg.png',
              width: 236,
              height: 46,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        Text(
          AppLocalizations.of(context)!.home_tagline,
          textAlign: TextAlign.center,
          style: AppTypography.headlineMedium(color: inkMuted).copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

// ── Loader : trois points qui ondulent ────────────────────
class _DotsLoader extends StatefulWidget {
  const _DotsLoader({required this.color});
  final Color color;

  @override
  State<_DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<_DotsLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context)!.splash_loading,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Chaque point est décalé d'un tiers de cycle.
            final t = (_ctrl.value - i * 0.18) % 1.0;
            final wave = t < 0.5 ? t * 2 : (1 - t) * 2; // 0 → 1 → 0
            final v = Curves.easeInOut.transform(wave);
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              transform: Matrix4.translationValues(0, -4 * v, 0),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.35 + 0.65 * v),
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ONBOARDING VIEW — style "Burt" : fond dégradé plein écran,
// collage photo agrandi, typo large, barre flottante dots +
// bouton rond discret. Carrousel à 3 étapes conservé (swipe + dots).
// Skip mutualisé au niveau du Stack (même traitement que le
// bottom bar) : une seule instance, position stable pendant le
// swipe, plus de duplication par étape.
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

        return Scaffold(
          body: FadeTransition(
            opacity: _entryOpacity,
            child: SlideTransition(
              position: _entrySlide,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: widget.pageController,
                    itemCount: widget.steps.length,
                    itemBuilder: (_, index) => _OnboardingPage(
                      step: widget.steps[index],
                    ),
                  ),
                  // Skip mutualisé ici : une seule instance, position fixe
                  // pendant le swipe, identique au traitement du bottom bar.
                  Positioned(
                    top: 0,
                    right: 0,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.sm,
                          right: AppSpacing.lg,
                        ),
                        child: _SolidSkipButton(onSkip: widget.onSkip),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _OnboardingBottomBar(
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
}

// ═══════════════════════════════════════════════════════════
// Une page d'onboarding complète : image plein cadre en haut
// (65% de la hauteur, edge-to-edge, sans card), bloc texte
// plat en dessous (35%). Le Skip n'est plus ici : il vit une
// seule fois au niveau du Stack dans _OnboardingView.
// ═══════════════════════════════════════════════════════════
class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.step});

  final _OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    final isDark = darkModeNotifier.value;
    final baseColor = isDark ? step.accentColorDark : step.accentColor;

    return ColoredBox(
      color: baseColor,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 65,
              child: _OnboardingHeroImage(imagePath: step.imagePath),
            ),
            Expanded(
              flex: 35,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  112, // laisse la place au bottom bar flottant (dots + flèche)
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: _OnboardingTextBlock(
                    title:
                        AppLocalizations.of(context)!.localized(step.titleKey),
                    body: AppLocalizations.of(context)!.localized(step.bodyKey),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Visuel principal — plein cadre, edge-to-edge, sans card ─
class _OnboardingHeroImage extends StatelessWidget {
  const _OnboardingHeroImage({required this.imagePath});
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Image.asset(
        imagePath,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

// ── Contrôles flottants : dots + bouton rond (sans bannière) ─
class _OnboardingBottomBar extends StatelessWidget {
  const _OnboardingBottomBar({
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Row(
          children: [
            _ElasticDots(totalSteps: steps.length, currentPage: currentPage),
            const Spacer(),
            _NextArrowButton(isLast: isLast, onNext: onNext),
          ],
        ),
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
        final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: AppMotion.standard,
          width: dotWidth,
          height: 8,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: isActive ? brand : brand.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

// ── Bouton Suivant — icône flèche, cohérent avec le collage ─
// Flèche vers la droite en temps normal, coche sur la dernière
// étape pour signaler l'action différente (démarrer l'app).
class _NextArrowButton extends StatelessWidget {
  const _NextArrowButton({required this.isLast, required this.onNext});
  final bool isLast;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onNext,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(
            isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
            color: AppColors.resolve(AppColors.card, AppDarkColors.card),
            size: 24,
          ),
        ),
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
            fontSize: 28,
            fontWeight: FontWeight.w900,
            height: 1.12,
            letterSpacing: -0.6,
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
