import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

TextStyle kLoginTitleStyle(Size size) => GoogleFonts.lato(
  fontSize: 48,
  fontWeight: FontWeight.bold,
  color: Colors.black
);

TextStyle bigTitleStyle(Size size) => GoogleFonts.ubuntu(
      fontSize: size.height * 0.045,
      fontWeight: FontWeight.bold,
    );

TextStyle kLoginSubtitleStyle(Size size) =>
    GoogleFonts.ubuntu(fontSize: size.height * 0.030);

TextStyle kLoginSubtitleStyle2(Size size) =>
    GoogleFonts.ptSerif(fontSize: size.height * 0.030, color: Colors.grey);

TextStyle kLoginSubtitleStyle3(Size size) => GoogleFonts.ubuntu(
    fontSize: size.height * 0.020, fontWeight: FontWeight.bold);

TextStyle kLoginSubtitleStyle4(Size size) => GoogleFonts.ubuntu(
    fontSize: size.height * 0.020, fontWeight: FontWeight.bold);

TextStyle kLoginSubtitleStyle5(Size size) =>
    GoogleFonts.ubuntu(fontSize: 18);

TextStyle kLoginTermsAndPrivacyStyle(Size size) =>
    GoogleFonts.ubuntu(fontSize: 15, color: Colors.grey, height: 1.5);

TextStyle kHaveAnAccountStyle(Size size) =>
    GoogleFonts.ubuntu(fontSize: size.height * 0.022, color: Colors.black);

TextStyle paragraph(Size size) =>
    GoogleFonts.ubuntu(fontSize: 16);

TextStyle kLoginOrSignUpTextStyle(
  Size size,
) =>
    GoogleFonts.ubuntu(
      fontSize: size.height * 0.022,
      fontWeight: FontWeight.w500,
      color: Colors.red,
    );

TextStyle forgottenpasswordTextStyle(
    Size size,
    ) =>
    GoogleFonts.ubuntu(
      fontSize: size.height * 0.019,
      fontWeight: FontWeight.w500,
      color: Colors.red,
    );

TextStyle kTextFormFieldStyle() => const TextStyle(color: Colors.black);

String SIGNUP_SCREEN = '/LoginPage',
    LOGIN = '/Login',
    ANIMATED_SPLASH = '/AnimatedSplashScreen',
    CURVED_NAVIGATION = '/CurvedNavigation',
    FOOD_DETAILS = '/Cart',
    MEALS_OF_A_CATEGORY = '/MealsOfACategory';
    //HOME_PAGE = '/HomePage';
