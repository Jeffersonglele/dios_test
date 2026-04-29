import 'package:dios_delices/Screen/DishDetails.dart';
import 'package:dios_delices/Screen/MealsOfACategory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
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
import 'config/app_config.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('fr', null);

  // Activer le mode edgeToEdge pour ne pas être en plein écran, en gardant la barre d'état visible
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.top],
  );

  try {
    await Parse().initialize(
      AppConfig.parseApplicationId,
      AppConfig.parseServerUrl,
      clientKey: AppConfig.parseClientKey,
      autoSendSessionId: true,
      liveQueryUrl: AppConfig.parseLiveQueryUrl,
      debug: kDebugMode && AppConfig.enableParseDebugLogs,
    );
    if (kDebugMode && AppConfig.enableVerboseAppLogs) {
      debugPrint('Parse initialized successfully');
    }
  } catch (e) {
    debugPrint('Failed to initialize Parse: $e');
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

  Stripe.publishableKey = AppConfig.stripePublishableKey;
  await Stripe.instance.applySettings();

  await NotificationService.initialize();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: GetMaterialApp(
        title: 'Dios Délices Vendeur',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: SafeArea(
          child:
              const AnimatedSplashScreen(), // Assure que tous les écrans démarrent avec SafeArea
        ),
        translations: MyTranslations(), // <--- ajoute cette ligne
        locale: Get.deviceLocale, // <--- détecte automatiquement la langue
        fallbackLocale: const Locale('en', 'US'),
        routes: <String, WidgetBuilder>{
          ANIMATED_SPLASH: (BuildContext context) => const AnimatedSplashScreen(),
          SIGNUP_SCREEN: (BuildContext context) => const SignUpView(),
          LOGIN: (BuildContext context) => const Login(),
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
