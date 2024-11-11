import 'package:dios_delices/Screen/DishDetails.dart';
import 'package:dios_delices/Screen/MealsOfACategory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'Screen/authentification/Signup.dart';
import 'Screen/authentification/Login.dart';
import 'Constant/Constant.dart';
import 'Screen/AnimatedSplashScreen.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'modeles/restaurant.dart';
import 'modeles/dish.dart';
import 'modeles/users.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('fr', null);

  // Activer le mode edgeToEdge pour ne pas être en plein écran, en gardant la barre d'état visible
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.top],
  );

  const String keyApplicationId = '9qBeGGwSGOQ1iWOJ1UNUXt40NhgwwgbHJYGpV1zg';
  const String keyClientKey = 'YKeFfBUqtkZBcEIUKPDtVIbsB5DU1gfBZlb0YFoa';
  const String keyParseServerUrl = 'https://parseapi.back4app.com';

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

  final appDocumentDirectory = await path_provider.getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDirectory.path);

  Hive.registerAdapter(UsersAdapter());
  Hive.registerAdapter(RestaurantAdapter());
  Hive.registerAdapter(DishAdapter());

  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'dios_delices',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: SafeArea(
        child: AnimatedSplashScreen(), // Assure que tous les écrans démarrent avec SafeArea
      ),
      routes: <String, WidgetBuilder>{
        ANIMATED_SPLASH: (BuildContext context) => AnimatedSplashScreen(),
        SIGNUP_SCREEN: (BuildContext context) => SignUpView(),
        LOGIN: (BuildContext context) => Login(),
        FOOD_DETAILS: (BuildContext context) => DishDetails(from_page: 0, dish_id: 0),
        MEALS_OF_A_CATEGORY: (BuildContext context) => MealsOfACategory(category_id: 0),
      },
      initialRoute: "/",
    );
  }
}
