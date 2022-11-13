import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
      LOGIN: (BuildContext context) => new Login()
    },
  ));
}
