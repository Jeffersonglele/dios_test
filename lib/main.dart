import 'package:dios_delices/Screen/DishDetails.dart';
import 'package:dios_delices/Screen/MealsOfACategory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import 'config/app_config.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('fr', null);

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
  } catch (e) {
    debugPrint('Failed to initialize Parse: $e');
  }

  // NOTE: On Flutter Web, path_provider does not provide a documents directory.
  // Hive can be initialized with an in-memory store instead.
  if (kIsWeb) {
    await Hive.initFlutter();
  } else {
    final appDocumentDirectory =
        await path_provider.getApplicationDocumentsDirectory();
    await Hive.initFlutter(appDocumentDirectory.path);
  }

  Hive.registerAdapter(UsersAdapter());
  Hive.registerAdapter(RestaurantAdapter());
  Hive.registerAdapter(DishAdapter());
  Hive.registerAdapter(AddressAdapter());
  Hive.registerAdapter(IdentityAdapter());
  Hive.registerAdapter(CommandeAdapter());
  Hive.registerAdapter(MoyenPaiementAdapter());
  Hive.registerAdapter(LigneCommandeAdapter());

  await NotificationService.initialize();

  // Détection du dark mode au lancement
  final prefs = await SharedPreferences.getInstance();
  final darkMode = prefs.getBool('dark_mode') ?? false;

  runApp(MyApp(initialDarkMode: darkMode));
}

class MyApp extends StatefulWidget {
  final bool initialDarkMode;
  const MyApp({super.key, required this.initialDarkMode});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _darkMode;

  @override
  void initState() {
    super.initState();
    _darkMode = widget.initialDarkMode;
    _listenDarkMode();
  }

  void _listenDarkMode() async {
    // Écoute les changements de SharedPreferences
    SharedPreferences.getInstance().then((prefs) {
      // Relit périodiquement (ou utilise une autre approche)
      // Pour une solution plus robuste, on pourrait utiliser un ChangeNotifier
    });
  }

  @override
  Widget build(BuildContext context) {
    // Relit à chaque build pour réagir aux changements du toggle Settings
    return FutureBuilder<bool>(
      future: SharedPreferences.getInstance()
          .then((p) => p.getBool('dark_mode') ?? false),
      builder: (context, snapshot) {
        final isDark = snapshot.data ?? _darkMode;
        return ProviderScope(
          child: MaterialApp(
            title: 'Dios Délices',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            builder: (context, child) {
              final media = MediaQuery.of(context);
              final factor = media.textScaleFactor.clamp(0.8, 1.5);
              // Force le system UI overlay pour le dark mode
              final brightness = isDark ? Brightness.dark : Brightness.light;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness:
                      isDark ? Brightness.light : Brightness.dark,
                  systemNavigationBarColor:
                      isDark ? AppDarkColors.surface : AppColors.surface,
                  systemNavigationBarIconBrightness:
                      isDark ? Brightness.light : Brightness.dark,
                ),
                child: MediaQuery(
                  data: media.copyWith(
                    textScaleFactor: factor,
                    platformBrightness: brightness,
                  ),
                  child: child!,
                ),
              );
            },
            home: const SafeArea(child: AnimatedSplashScreen()),
            routes: <String, WidgetBuilder>{
              ANIMATED_SPLASH: (BuildContext context) =>
                  const AnimatedSplashScreen(),
              SIGNUP_SCREEN: (BuildContext context) => const SignUpView(),
              LOGIN: (BuildContext context) => const Login(),
              FOOD_DETAILS: (BuildContext context) =>
                  DishDetails(from_page: 0, dish_id: 0),
              MEALS_OF_A_CATEGORY: (BuildContext context) =>
                  const MealsOfACategory(),
            },
            initialRoute: "/",
          ),
        );
      },
    );
  }
}
