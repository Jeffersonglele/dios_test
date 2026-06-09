import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dios_delices/screens/DishDetails.dart';
import 'package:dios_delices/screens/MealsOfACategory.dart';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/auth/Signup.dart';
import 'screens/auth/Login.dart';
import 'constants/Constant.dart';
import 'screens/AnimatedSplashScreen.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'models/identity.dart';
import 'models/restaurant.dart';
import 'models/dish.dart';
import 'models/address.dart';
import 'models/users.dart';
import 'models/moyen_paiement.dart';
import 'models/commande.dart';
import 'models/ligne_commande.dart';
import 'models/pro_document.dart';
import 'package:flutter/services.dart';
import 'config/app_config.dart';
import 'services/notification_service.dart';
import 'services/session_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuration de la barre système
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.top],
  );

  // Initialisation Firebase (nécessaire pour les notifications push)
  try {
    await Firebase.initializeApp();
  } catch (e) {}

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
  } catch (e) {}

  // Flutter Web doesn't support `path_provider.getApplicationDocumentsDirectory()`.
  // Guard it to prevent MissingPluginException and still initialize Hive.
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

  // Initialisation des notifications
  try {
    await NotificationService.initialize();

    // S'abonner aux notifications si l'utilisateur est déjà connecté
    final session = await SessionService.readSession();
    if (session.isLoggedIn) {
      await NotificationService.subscribeToRestaurantNotifications();
    }
  } catch (e) {}

  // Demande de géolocalisation (comme pour les notifs)
  try {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    } else if (permission == LocationPermission.deniedForever) {}
  } catch (_) {}

  // Lecture du dark mode depuis SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('dark_mode') ?? false;
  final savedLang = prefs.getString('app_language') ?? 'fr';

  runApp(
    ProviderScope(
      overrides: [
        localeProvider.overrideWith((ref) => Locale(savedLang)),
      ],
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeNotifier = ref.read(themeModeProvider.notifier);
      if (widget.initialDarkMode &&
          ref.read(themeModeProvider) != ThemeMode.dark) {
        themeNotifier.toggleTheme();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final appLocale = ref.watch(localeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return MaterialApp(
      title: 'Dios Délices',
      debugShowCheckedModeBanner: false,
      locale: appLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
      ],
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
