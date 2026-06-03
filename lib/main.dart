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
import 'services/session_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation du format de date français
  await initializeDateFormatting('fr', null);

  // Configuration de la barre système
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.top],
  );

  // Initialisation Parse
  try {
    await Parse().initialize(
      AppConfig.parseApplicationId,
      AppConfig.parseServerUrl,
      clientKey: AppConfig.parseClientKey,
      autoSendSessionId: true,
      liveQueryUrl: AppConfig.parseLiveQueryUrl,
      debug: kDebugMode && AppConfig.enableParseDebugLogs,
    );
    debugPrint('✅ Parse initialized successfully');
  } catch (e) {
    debugPrint('❌ Failed to initialize Parse: $e');
  }

  // Initialisation Hive
  try {
    if (kIsWeb) {
      await Hive.initFlutter();
    } else {
      final appDocumentDirectory =
          await path_provider.getApplicationDocumentsDirectory();
      await Hive.initFlutter(appDocumentDirectory.path);
    }

    // Enregistrement des adaptateurs
    Hive.registerAdapter(UsersAdapter());
    Hive.registerAdapter(RestaurantAdapter());
    Hive.registerAdapter(DishAdapter());
    Hive.registerAdapter(AddressAdapter());
    Hive.registerAdapter(IdentityAdapter());
    Hive.registerAdapter(CommandeAdapter());
    Hive.registerAdapter(MoyenPaiementAdapter());
    Hive.registerAdapter(LigneCommandeAdapter());

    debugPrint('✅ Hive initialized successfully');
  } catch (e) {
    debugPrint('❌ Failed to initialize Hive: $e');
  }

  // Initialisation des notifications
  try {
    await NotificationService.initialize();

    // S'abonner aux notifications si l'utilisateur est déjà connecté
    final session = await SessionService.readSession();
    if (session.isLoggedIn) {
      await NotificationService.subscribeToRestaurantNotifications();
    }
    debugPrint('✅ Notifications initialized successfully');
  } catch (e) {
    debugPrint('❌ Failed to initialize notifications: $e');
  }

  // Lecture du dark mode depuis SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('dark_mode') ?? false;

  runApp(
    ProviderScope(
      child: MyApp(initialDarkMode: isDarkMode),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  final bool initialDarkMode;
  const MyApp({super.key, required this.initialDarkMode});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // Initialiser le thème avec la valeur de SharedPreferences
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeNotifier = ref.read(themeModeProvider.notifier);
      final targetMode =
          widget.initialDarkMode ? ThemeMode.dark : ThemeMode.light;
      // Comparer et changer si nécessaire
      // Utiliser un paramètre stocké pour éviter d'appeler toggleTheme inutilement
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return MaterialApp(
      title: 'Dios Délices',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final factor = media.textScaleFactor.clamp(0.8, 1.5);

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor:
                isDark ? AppDarkColors.surface : AppColors.surface,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
          ),
          child: MediaQuery(
            data: media.copyWith(
              textScaleFactor: factor,
              platformBrightness: isDark ? Brightness.dark : Brightness.light,
            ),
            child: child!,
          ),
        );
      },
      home: const SafeArea(child: AnimatedSplashScreen()),
      routes: <String, WidgetBuilder>{
        ANIMATED_SPLASH: (BuildContext context) => const AnimatedSplashScreen(),
        SIGNUP_SCREEN: (BuildContext context) => const SignUpView(),
        LOGIN: (BuildContext context) => const Login(),
        FOOD_DETAILS: (BuildContext context) =>
            DishDetails(from_page: 0, dish_id: 0),
        MEALS_OF_A_CATEGORY: (BuildContext context) => const MealsOfACategory(),
      },
      initialRoute: "/",
    );
  }
}
