import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig._();

  static const parseApplicationId =
      '9qBeGGwSGOQ1iWOJ1UNUXt40NhgwwgbHJYGpV1zg';
  static const parseClientKey = 'YKeFfBUqtkZBcEIUKPDtVIbsB5DU1gfBZlb0YFoa';
  static const parseServerUrl = 'https://parseapi.back4app.com';
  static const parseLiveQueryUrl =
      'wss://9qBeGGwSGOQ1iWOJ1UNUXt40NhgwwgbHJYGpV1zg.b4a.io';

  static const enableParseDebugLogs = false;
  static const enableVerboseAppLogs = false;

  static const vercelBackendUrl = 'https://dios-delices-backend.vercel.app';

  /// URL publique du backend Node.js.
  ///
  /// Pour le développement local, lancer Flutter avec par exemple :
  /// `--dart-define=NODE_API_URL=http://10.0.2.2:3000` sur émulateur Android.
  static const nodeBackendUrl = String.fromEnvironment(
    'NODE_API_URL',
    defaultValue: 'https://dios-delices.onrender.com',
  );

  /// Clé CARTO des fonds de carte (gratuite : carto.com/basemaps/apikey).
  /// Jamais écrite dans le code. Lue depuis `--dart-define=CARTO_API_KEY=xxxx`
  /// si fournie, sinon depuis le fichier `.env` (chargé dans `main`).
  /// Sans clé, l'app utilise les tuiles OpenStreetMap standard.
  static String get cartoApiKey {
    const fromDefine = String.fromEnvironment('CARTO_API_KEY');
    if (fromDefine.isNotEmpty) return fromDefine;
    return dotenv.env['CARTO_API_KEY'] ?? '';
  }
}
