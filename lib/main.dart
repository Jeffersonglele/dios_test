import 'package:dios_delices/Screen/FoodDetails.dart';
import 'package:dios_delices/Screen/MealsOfACategory.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Utilise Hive Flutter
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'Screen/Signup.dart';
import 'Screen/Login.dart';
import 'Constant/Constant.dart';
import 'Screen/AnimatedSplashScreen.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'modeles/restaurant.dart';
import 'modeles/users.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // S'assure que les widgets sont initialisés avant d'utiliser les services asynchrones


  // Initialisation de Parse avec les informations de Back4App
  const String keyApplicationId = '9qBeGGwSGOQ1iWOJ1UNUXt40NhgwwgbHJYGpV1zg'; // Application ID Back4App
  const String keyClientKey = 'YKeFfBUqtkZBcEIUKPDtVIbsB5DU1gfBZlb0YFoa'; // Client Key Back4App
  const String keyParseServerUrl = 'https://parseapi.back4app.com'; // Parse server URL

  try {
    await Firebase.initializeApp();

    await Parse().initialize(
      keyApplicationId,
      keyParseServerUrl,
      clientKey: keyClientKey,
      autoSendSessionId: true,
    );
    print('Parse initialized successfully');
  } catch (e) {
    print('Failed to initialize Parse: $e');
  }

  // Initialisation de Hive
  final appDocumentDirectory = await path_provider.getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDirectory.path); // Utilise Hive.initFlutter

  // Enregistre l'adapter Hive pour les utilisateurs
  Hive.registerAdapter(UsersAdapter());
  Hive.registerAdapter(RestaurantAdapter());

  // Ouvre une box Hive (par exemple pour stocker les utilisateurs)
  await Hive.openBox<Users>('users');

  runApp(
    ProviderScope( // Encapsule ici le MaterialApp dans le ProviderScope
      child: MaterialApp(
        title: 'dios_delices',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.red,
        ),
        home: AnimatedSplashScreen(),
        routes: <String, WidgetBuilder>{
          ANIMATED_SPLASH: (BuildContext context) => AnimatedSplashScreen(),
          SIGNUP_SCREEN: (BuildContext context) => SignUpView(),
          LOGIN: (BuildContext context) => Login(),
          FOOD_DETAILS: (BuildContext context) => FoodDetails(from_page: 0, meal_id: 0),
          MEALS_OF_A_CATEGORY: (BuildContext context) => MealsOfACategory(category_id: 0),
        },
        initialRoute: "/",
      ),
    ),
  );
}

