import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/theme_provider.dart';

// ────────────────────────────────────────────────────────────
// DESIGN TOKENS — Dios Délices
// Ambiance : chaleureux · gourmand · artisanal · premium
// ────────────────────────────────────────────────────────────

// ── COULEURS (mode clair) ───────────────────────────────────
class AppColors {
  const AppColors._();

  static Color resolve(Color light, Color dark) =>
      darkModeNotifier.value ? dark : light;

  // Brand
  static const brand = Color(0xFFC84C2F);
  static const brandLight = Color(0xFFE85D3F);
  static const brandDark = Color(0xFF8E2F1B);
  static const brandSurface = Color(0xFFFEF0EB);

  // Accent doré safran
  static const accent = Color(0xFFF2B15A);
  static const accentLight = Color(0xFFFDF0D5);

  // Fonds chauds
  static const surface = Color(0xFFFFF8F3);
  static const surfaceWarm = Color(0xFFFFF3EA);

  // Texte
  static const ink = Color(0xFF261814);
  static const inkMuted = Color(0xFF6D5B54);
  static const inkSubtle = Color(0xFF9B8B84);

  // États
  static const success = Color(0xFF2E8B57);
  static const successLight = Color(0xFFE8F5EE);
  static const error = Color(0xFFBE3A34);
  static const errorLight = Color(0xFFFDECEA);

  // Surfaces
  static const card = Color(0xFFFFFCFA);
  static const border = Color(0xFFE8D4C8);

  // Dégradé signature
  static const gradientStart = Color(0xFFFFF8F3);
  static const gradientEnd = Color(0xFFFFE8D6);
}

// ── COULEURS MODE SOMBRE ───────────────────────────────────
class AppDarkColors {
  const AppDarkColors._();

  static const brand = Color(0xFFE85D3F);
  static const brandLight = Color(0xFFF0705A);
  static const brandDark = Color(0xFFC84C2F);
  static const brandSurface = Color(0xFF3D1812);

  static const accent = Color(0xFFF2B15A);
  static const accentLight = Color(0xFF3D2A14);

  static const surface = Color(0xFF1A1410);
  static const surfaceWarm = Color(0xFF211914);

  static const ink = Color(0xFFEDE3D8);
  static const inkMuted = Color(0xFFB5A699);
  static const inkSubtle = Color(0xFF7A6E64);

  static const success = Color(0xFF4ADE80);
  static const successLight = Color(0xFF1A2E20);
  static const error = Color(0xFFF87171);
  static const errorLight = Color(0xFF2E1A1A);

  static const card = Color(0xFF241C16);
  static const border = Color(0xFF3D3229);

  // Dégradé signature (équivalent sombre)
  static const gradientStart = Color(0xFF1A1410);
  static const gradientEnd = Color(0xFF241710);
}

// ── TYPOGRAPHIE ────────────────────────────────────────────
class AppTypography {
  AppTypography._();

  // Display — Playfair Display (serif élégante)
  static TextStyle displayLarge({Color? color}) => GoogleFonts.playfairDisplay(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        height: 1.08,
        letterSpacing: -0.5,
        color: color ?? AppColors.ink,
      );

  static TextStyle displayMedium({Color? color}) => GoogleFonts.playfairDisplay(
        fontSize: 38,
        fontWeight: FontWeight.w700,
        height: 1.10,
        letterSpacing: -0.3,
        color: color ?? AppColors.ink,
      );

  static TextStyle headlineLarge({Color? color}) => GoogleFonts.playfairDisplay(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.15,
        color: color ?? AppColors.ink,
      );

  static TextStyle headlineMedium({Color? color}) =>
      GoogleFonts.playfairDisplay(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.18,
        color: color ?? AppColors.ink,
      );

  // Titles & Body — Plus Jakarta Sans
  static TextStyle titleLarge({Color? color}) => GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.2,
        color: color ?? AppColors.ink,
      );

  static TextStyle titleMedium({Color? color}) => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.30,
        letterSpacing: -0.1,
        color: color ?? AppColors.ink,
      );

  static TextStyle bodyLarge({Color? color}) => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.50,
        color: color ?? AppColors.ink,
      );

  static TextStyle bodyMedium({Color? color}) => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.45,
        letterSpacing: 0.1,
        color: color ?? AppColors.inkMuted,
      );

  static TextStyle labelLarge({Color? color}) => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.20,
        letterSpacing: 0.3,
        color: color ?? AppColors.ink,
      );

  static TextStyle labelMedium({Color? color}) => GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.20,
        letterSpacing: 0.2,
        color: color ?? AppColors.inkMuted,
      );

  static TextStyle titleSmall({Color? color}) => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.1,
        color: color ?? AppColors.ink,
      );

  static TextStyle bodySmall({Color? color}) => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.45,
        letterSpacing: 0.1,
        color: color ?? AppColors.inkMuted,
      );
}

// ── SPACING SCALE ──────────────────────────────────────────
class AppSpacing {
  const AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

// ── RADIUS SCALE ───────────────────────────────────────────
class AppRadius {
  const AppRadius._();
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double full = 9999;
}

// ── SHADOWS (chaudes, douces, pas grises) ──────────────────
class AppShadows {
  const AppShadows._();

  static BoxShadow subtle = BoxShadow(
    color: const Color(0xFF8E2F1B).withValues(alpha: 0.06),
    blurRadius: 8,
    offset: const Offset(0, 2),
  );

  static BoxShadow card = BoxShadow(
    color: const Color(0xFF6D5B54).withValues(alpha: 0.08),
    blurRadius: 16,
    offset: const Offset(0, 4),
  );

  static BoxShadow elevated = BoxShadow(
    color: const Color(0xFF8E2F1B).withValues(alpha: 0.10),
    blurRadius: 24,
    offset: const Offset(0, 8),
  );

  static BoxShadow floating = BoxShadow(
    color: const Color(0xFF8E2F1B).withValues(alpha: 0.14),
    blurRadius: 32,
    offset: const Offset(0, 12),
    spreadRadius: -2,
  );

  static List<BoxShadow> cardList = [card];
  static List<BoxShadow> floatingList = [floating];
}

// ── MOTION TOKENS ──────────────────────────────────────────
class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve decelerate = Curves.fastOutSlowIn;
  static const Curve accelerate = Curves.easeInCubic;
  static const Curve bounce = Curves.elasticOut;
}

// ── THÈME FLUTTER ──────────────────────────────────────────
class AppTheme {
  const AppTheme._();

  // Convenience constructors (used by tests)
  static ThemeData light() => lightTheme;
  static ThemeData dark() => darkTheme;

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: AppColors.brand,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: AppColors.ink,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      surfaceContainerHighest: AppColors.surfaceWarm,
      primaryContainer: AppColors.brandSurface,
      secondaryContainer: AppColors.accentLight,
    );

    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme().copyWith(
      displayLarge: AppTypography.displayLarge(),
      displayMedium: AppTypography.displayMedium(),
      headlineLarge: AppTypography.headlineLarge(),
      headlineMedium: AppTypography.headlineMedium(),
      titleLarge: AppTypography.titleLarge(),
      titleMedium: AppTypography.titleMedium(),
      bodyLarge: AppTypography.bodyLarge(),
      bodyMedium: AppTypography.bodyMedium(),
      labelLarge: AppTypography.labelLarge(),
      labelMedium: AppTypography.labelMedium(),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: baseTextTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _DiosPageTransition(),
          TargetPlatform.iOS: _DiosPageTransition(),
          TargetPlatform.macOS: _DiosPageTransition(),
        },
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.labelLarge(color: Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandDark,
          side: const BorderSide(color: AppColors.border, width: 1.3),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.labelLarge(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brand,
          textStyle: AppTypography.labelLarge(color: AppColors.brand),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: AppTypography.bodyMedium(color: AppColors.inkSubtle),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        prefixIconColor: AppColors.brandDark,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: AppTypography.bodyMedium(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brand,
        circularTrackColor: AppColors.border,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.brand;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: AppColors.border, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.brand;
          return AppColors.border;
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.card,
        selectedColor: AppColors.brandSurface,
        surfaceTintColor: Colors.transparent,
        labelStyle: AppTypography.labelMedium(),
        secondaryLabelStyle: AppTypography.labelMedium(color: AppColors.brand),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: AppDarkColors.brand,
      onPrimary: Colors.white,
      secondary: AppDarkColors.accent,
      onSecondary: AppDarkColors.ink,
      error: AppDarkColors.error,
      onError: Colors.white,
      surface: AppDarkColors.surface,
      onSurface: AppDarkColors.ink,
      surfaceContainerHighest: AppDarkColors.surfaceWarm,
      primaryContainer: AppDarkColors.brandSurface,
      secondaryContainer: AppDarkColors.accentLight,
    );

    final baseTextTheme =
        GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme)
            .copyWith(
      displayLarge: AppTypography.displayLarge(color: AppDarkColors.ink),
      displayMedium: AppTypography.displayMedium(color: AppDarkColors.ink),
      headlineLarge: AppTypography.headlineLarge(color: AppDarkColors.ink),
      headlineMedium: AppTypography.headlineMedium(color: AppDarkColors.ink),
      titleLarge: AppTypography.titleLarge(color: AppDarkColors.ink),
      titleMedium: AppTypography.titleMedium(color: AppDarkColors.ink),
      bodyLarge: AppTypography.bodyLarge(color: AppDarkColors.ink),
      bodyMedium: AppTypography.bodyMedium(color: AppDarkColors.inkMuted),
      labelLarge: AppTypography.labelLarge(color: AppDarkColors.ink),
      labelMedium: AppTypography.labelMedium(color: AppDarkColors.inkMuted),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppDarkColors.surface,
      textTheme: baseTextTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _DiosPageTransition(),
          TargetPlatform.iOS: _DiosPageTransition(),
          TargetPlatform.macOS: _DiosPageTransition(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppDarkColors.surface,
        foregroundColor: AppDarkColors.ink,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppDarkColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppDarkColors.border, width: 0.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppDarkColors.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.labelLarge(color: Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppDarkColors.ink,
          side: const BorderSide(color: AppDarkColors.border),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.labelLarge(color: AppDarkColors.ink),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppDarkColors.brand,
          textStyle: AppTypography.labelLarge(color: AppDarkColors.brand),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppDarkColors.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: AppTypography.bodyMedium(color: AppDarkColors.inkSubtle),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppDarkColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppDarkColors.brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppDarkColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppDarkColors.error, width: 1.5),
        ),
        prefixIconColor: AppDarkColors.brand,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppDarkColors.ink,
        contentTextStyle:
            AppTypography.bodyMedium(color: AppDarkColors.surface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppDarkColors.brand,
      ),
      dividerTheme: const DividerThemeData(
        color: AppDarkColors.border,
        thickness: 1,
        space: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppDarkColors.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppDarkColors.brand;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: AppDarkColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppDarkColors.brand;
          return AppDarkColors.border;
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppDarkColors.card,
        selectedColor: AppDarkColors.brandSurface,
        labelStyle: AppTypography.labelMedium(color: AppDarkColors.inkMuted),
        secondaryLabelStyle:
            AppTypography.labelMedium(color: AppDarkColors.brand),
        side: const BorderSide(color: AppDarkColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

// ── TRANSITION DE PAGE SIGNATURE ───────────────────────────
class _DiosPageTransition extends PageTransitionsBuilder {
  const _DiosPageTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedIn = CurvedAnimation(
      parent: animation,
      curve: AppMotion.standard,
      reverseCurve: AppMotion.accelerate,
    );

    return AnimatedBuilder(
      animation: curvedIn,
      child: child,
      builder: (context, cachedChild) {
        return Transform.translate(
          offset: Offset((1 - curvedIn.value) * 24, 0),
          child: Transform.scale(
            scale: 0.97 + (0.03 * curvedIn.value),
            child: Opacity(
              opacity: 0.6 + (0.4 * curvedIn.value),
              child: cachedChild!,
            ),
          ),
        );
      },
    );
  }
}
