import 'package:dios_delices/Screen/DishDetails.dart';
import 'package:dios_delices/Screen/MealsOfACategory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Utilise Hive Flutter
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'Screen/authentification/Signup.dart';
import 'Screen/authentification/Login.dart';
import 'Constant/Constant.dart';
import 'Screen/AnimatedSplashScreen.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'modeles/restaurant.dart';
import 'modeles/dish.dart';
import 'modeles/users.dart';
import 'package:flutter/services.dart'; // Import pour SystemChrome
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // S'assure que les widgets sont initialisés avant d'utiliser les services asynchrones

  // Initialisez les formats de date pour la localisation (français)
  await initializeDateFormatting('fr', null);

  // Activer la barre d'état pour ne pas être en plein écran
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays: [SystemUiOverlay.top]);

  // Initialisation de Parse avec les informations de Back4App
  const String keyApplicationId = '9qBeGGwSGOQ1iWOJ1UNUXt40NhgwwgbHJYGpV1zg'; // Application ID Back4App
  const String keyClientKey = 'YKeFfBUqtkZBcEIUKPDtVIbsB5DU1gfBZlb0YFoa'; // Client Key Back4App
  const String keyParseServerUrl = 'https://parseapi.back4app.com'; // Parse server URL

  try {
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
  Hive.registerAdapter(DishAdapter());

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
          FOOD_DETAILS: (BuildContext context) => DishDetails(from_page: 0, dish_id: 0),
          MEALS_OF_A_CATEGORY: (BuildContext context) => MealsOfACategory(category_id: 0),
        },
        initialRoute: "/",
      ),
    ),
  );
}
