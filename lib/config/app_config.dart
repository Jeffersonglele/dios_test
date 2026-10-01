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
}
