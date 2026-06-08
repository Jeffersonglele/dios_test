import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ── Styles texte réutilisables ──────────────────────────────
TextStyle kLoginTitleStyle(Size size) => AppTypography.displayMedium();

TextStyle bigTitleStyle(Size size) => AppTypography.displayLarge(
      color: AppColors.ink,
    );

TextStyle kLoginSubtitleStyle(Size size) => AppTypography.titleLarge();

TextStyle kLoginSubtitleStyle2(Size size) => AppTypography.bodyLarge(
      color: AppColors.inkMuted,
    );

TextStyle kLoginSubtitleStyle3(Size size) => AppTypography.titleMedium();

TextStyle kLoginSubtitleStyle4(Size size) => AppTypography.titleMedium(
      color: AppColors.brandDark,
    );

TextStyle kLoginSubtitleStyle5(Size size) => AppTypography.titleMedium(
      color: AppColors.inkMuted,
    );

TextStyle kLoginTermsAndPrivacyStyle(Size size) => AppTypography.bodyMedium(
      color: AppColors.inkMuted,
    );

TextStyle kHaveAnAccountStyle(Size size) => AppTypography.bodyLarge(
      color: AppColors.ink,
    );

TextStyle paragraph(Size size) => AppTypography.bodyLarge(
      color: AppColors.inkMuted,
    );

TextStyle kLoginOrSignUpTextStyle(Size size) => AppTypography.bodyLarge(
      color: AppColors.brand,
    );

TextStyle forgottenpasswordTextStyle(Size size) => AppTypography.labelLarge(
      color: AppColors.brand,
    );

TextStyle kTextFormFieldStyle() => AppTypography.bodyLarge();

// ── Routes nommées ─────────────────────────────────────────
String SIGNUP_SCREEN = '/LoginPage',
    LOGIN = '/Login',
    ANIMATED_SPLASH = '/AnimatedSplashScreen',
    CURVED_NAVIGATION = '/CurvedNavigation',
    FOOD_DETAILS = '/Cart',
    MEALS_OF_A_CATEGORY = '/MealsOfACategory';
