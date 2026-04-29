import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

TextStyle kLoginTitleStyle(Size size) => GoogleFonts.playfairDisplay(
  fontSize: 44,
  fontWeight: FontWeight.w700,
  color: AppColors.ink,
);

TextStyle bigTitleStyle(Size size) => GoogleFonts.playfairDisplay(
      fontSize: size.height * 0.045,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    );

TextStyle kLoginSubtitleStyle(Size size) =>
    GoogleFonts.plusJakartaSans(
      fontSize: size.height * 0.028,
      color: AppColors.ink,
      fontWeight: FontWeight.w600,
    );

TextStyle kLoginSubtitleStyle2(Size size) =>
    GoogleFonts.plusJakartaSans(
      fontSize: size.height * 0.022,
      color: AppColors.inkMuted,
      height: 1.4,
    );

TextStyle kLoginSubtitleStyle3(Size size) => GoogleFonts.plusJakartaSans(
    fontSize: size.height * 0.020,
    fontWeight: FontWeight.w700,
    color: AppColors.ink);

TextStyle kLoginSubtitleStyle4(Size size) => GoogleFonts.plusJakartaSans(
    fontSize: size.height * 0.020,
    fontWeight: FontWeight.w700,
    color: AppColors.brandDark);

TextStyle kLoginSubtitleStyle5(Size size) =>
    GoogleFonts.plusJakartaSans(
      fontSize: 18,
      color: AppColors.inkMuted,
      fontWeight: FontWeight.w600,
    );

TextStyle kLoginTermsAndPrivacyStyle(Size size) =>
    GoogleFonts.plusJakartaSans(
      fontSize: 15,
      color: AppColors.inkMuted,
      height: 1.5,
    );

TextStyle kHaveAnAccountStyle(Size size) =>
    GoogleFonts.plusJakartaSans(
      fontSize: size.height * 0.022,
      color: AppColors.ink,
      fontWeight: FontWeight.w600,
    );

TextStyle paragraph(Size size) =>
    GoogleFonts.plusJakartaSans(
      fontSize: 16,
      color: AppColors.inkMuted,
      height: 1.45,
    );

TextStyle kLoginOrSignUpTextStyle(
  Size size,
) =>
    GoogleFonts.plusJakartaSans(
      fontSize: size.height * 0.022,
      fontWeight: FontWeight.w700,
      color: AppColors.brand,
    );

TextStyle forgottenpasswordTextStyle(
    Size size,
    ) =>
    GoogleFonts.plusJakartaSans(
      fontSize: size.height * 0.019,
      fontWeight: FontWeight.w700,
      color: AppColors.brand,
    );

TextStyle kTextFormFieldStyle() => GoogleFonts.plusJakartaSans(
  color: AppColors.ink,
  fontWeight: FontWeight.w600,
);

String SIGNUP_SCREEN = '/LoginPage',
    LOGIN = '/Login',
    ANIMATED_SPLASH = '/AnimatedSplashScreen',
    CURVED_NAVIGATION = '/CurvedNavigation',
    FOOD_DETAILS = '/Cart',
    MEALS_OF_A_CATEGORY = '/MealsOfACategory';
    //HOME_PAGE = '/HomePage';
