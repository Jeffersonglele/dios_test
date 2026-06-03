import 'package:geolocator/geolocator.dart';
import 'package:dios_delices/providers/theme_provider.dart';
import 'package:dios_delices/Screen/DishDetails.dart';
import 'package:dios_delices/Screen/MealsOfACategory.dart';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'config/app_config.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  await NotificationService.initialize();

  // Demande de géolocalisation (comme pour les notifs)
  try {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    } else if (permission == LocationPermission.deniedForever) {
      debugPrint('Géolocalisation refusée définitivement — aller dans Réglages > Confidentialité > Localisation');
    }
  } catch (_) {}

  final prefs = await SharedPreferences.getInstance();
  darkModeNotifier.value = prefs.getBool('dark_mode') ?? false;
  final savedLocale = prefs.getString('app_language') ?? 'fr';
  localeNotifier.value = Locale(savedLocale);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    darkModeNotifier.addListener(_onChanged);
    localeNotifier.addListener(_onChanged);
  }

  @override
  void dispose() {
    darkModeNotifier.removeListener(_onChanged);
    localeNotifier.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: darkModeNotifier,
      builder: (context, isDark, _) {
        return ValueListenableBuilder<Locale>(
          valueListenable: localeNotifier,
          builder: (context, locale, _) {
            return ProviderScope(
              key: ValueKey('$isDark-$locale'),
              child: MaterialApp(
                key: ValueKey('$isDark-$locale'),
                title: 'Dios Délices',
                debugShowCheckedModeBanner: false,
                locale: locale,
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
                theme: AppTheme.light(),
                darkTheme: AppTheme.dark(),
                themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
                builder: (context, child) {
                  final media = MediaQuery.of(context);
                  final factor = media.textScaleFactor.clamp(0.8, 1.5);
                  final brightness = isDark ? Brightness.dark : Brightness.light;
                  return AnnotatedRegion<SystemUiOverlayStyle>(
                    value: SystemUiOverlayStyle(
                      statusBarColor: isDark ? AppDarkColors.surface : AppColors.surface,
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
                home: const AnimatedSplashScreen(),
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
      },
    );
  }
}
