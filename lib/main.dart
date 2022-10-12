/*import 'Screen/Login.dart';
import 'Constant/Constant.dart';
import 'Screen/AnimatedSplashScreen.dart';

import 'package:flutter/material.dart';
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
      ANIMATED_SPALSH: (BuildContext context) => new AnimatedSplashScreen(),
      // LOGIN_SCREEN: (BuildContext context) => new LoginPage(),
      LOGIN: (BuildContext context) => new Login()
    },
  ));
}*/

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
      ANIMATED_SPALSH: (BuildContext context) => new AnimatedSplashScreen(),
      LOGIN_SCREEN: (BuildContext context) => new SignUpView(),
      LOGIN: (BuildContext context) => new Login()
    },
  ));
}

/*void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: SignUpView(),
    );
  }
}*/
