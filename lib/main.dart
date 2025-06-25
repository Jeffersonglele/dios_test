import 'package:dios_delices/Screen/DishDetails.dart';
import 'package:dios_delices/Screen/MealsOfACategory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'Screen/authentification/Signup.dart';
import 'Screen/authentification/Login.dart';
import 'Constant/Constant.dart';
import 'Screen/AnimatedSplashScreen.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'modeles/identity.dart';
import 'modeles/restaurant.dart';
import 'modeles/dish.dart';
import 'modeles/address.dart';
import 'modeles/users.dart';
import 'modeles/moyen_paiement.dart';
import 'modeles/commande.dart';
import 'modeles/ligne_commande.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:get/get.dart';
import 'utils/translations.dart';

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
      liveQueryUrl: 'wss://9qBeGGwSGOQ1iWOJ1UNUXt40NhgwwgbHJYGpV1zg.b4a.io',
      debug: true,
    );
    print('Parse initialized successfully');
  } catch (e) {
    print('Failed to initialize Parse: $e');
  }

  final appDocumentDirectory =
      await path_provider.getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDirectory.path);

  Hive.registerAdapter(UsersAdapter());
  Hive.registerAdapter(RestaurantAdapter());
  Hive.registerAdapter(DishAdapter());
  Hive.registerAdapter(AddressAdapter());
  Hive.registerAdapter(IdentityAdapter());
  Hive.registerAdapter(CommandeAdapter());
  Hive.registerAdapter(MoyenPaiementAdapter());
  Hive.registerAdapter(LigneCommandeAdapter());

  Stripe.publishableKey =
      'pk_test_51Qj31pENxCrc0ZmbmKeHf4HU8kI0ha1ee9hj7VGkgd16U5nmM7mJ3k4SyLGV4cwAhfCsvqgdgGffMLVsQRDXKbzA00D2w1iGG0';
  await Stripe.instance.applySettings();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: GetMaterialApp(
        title: 'Dios Délices Vendeur',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.red,
        ),
        home: SafeArea(
          child:
              AnimatedSplashScreen(), // Assure que tous les écrans démarrent avec SafeArea
        ),
        translations: MyTranslations(), // <--- ajoute cette ligne
        locale: Get.deviceLocale, // <--- détecte automatiquement la langue
        fallbackLocale: Locale('en', 'US'),
        routes: <String, WidgetBuilder>{
          ANIMATED_SPLASH: (BuildContext context) => AnimatedSplashScreen(),
          SIGNUP_SCREEN: (BuildContext context) => SignUpView(),
          LOGIN: (BuildContext context) => Login(),
          FOOD_DETAILS: (BuildContext context) =>
              DishDetails(from_page: 0, dish_id: 0),
          MEALS_OF_A_CATEGORY: (BuildContext context) =>
              MealsOfACategory(category_id: 0),
        },
        initialRoute: "/",
      ),
    );
  }
}