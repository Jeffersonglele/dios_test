import 'package:dios_delices/Screen/FoodDetails.dart';
import 'package:dios_delices/Screen/MealsOfACategory.dart';
import 'package:flutter/material.dart';
import 'Screen/Signup.dart';
import 'Screen/Login.dart';
import 'Constant/Constant.dart';
import 'Screen/AnimatedSplashScreen.dart';

import 'package:flutter/services.dart';

Future main() async {
  SystemChrome.setEnabledSystemUIOverlays([]);
  runApp(new MaterialApp(
    title: 'dios_delices',
    debugShowCheckedModeBanner: false,
    theme: new ThemeData(
      primarySwatch: Colors.red,
    ),
    home: new AnimatedSplashScreen(),
    routes: <String, WidgetBuilder>{
      ANIMATED_SPLASH: (BuildContext context) => new AnimatedSplashScreen(),
      SIGNUP_SCREEN: (BuildContext context) => new SignUpView(),
      LOGIN: (BuildContext context) => new Login(),
      FOOD_DETAILS: (BuildContext context) => new FoodDetails(
            from_page: 0,
            meal_id: 0,
          ),
      MEALS_OF_A_CATEGORY: (BuildContext context) => new MealsOfACategory(
            category_id: 0,
          ),
    },
    initialRoute: "/",
  ));
}
