import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Informations de plateforme nécessaires aux variantes natives de l'interface.
///
/// Le design natif iOS est activé à partir d'iOS 18. L'API Liquid Glass
/// officielle est utilisée automatiquement à partir d'iOS 26 ; iOS 18–25
/// utilisent le même composant avec un matériau SwiftUI compatible.
class DeviceInfo {
  DeviceInfo._();

  static final DeviceInfo instance = DeviceInfo._();
  static const _channel = MethodChannel('app.navbar/navigate');

  int _iosMajorVersion = 0;
  bool _initialized = false;

  int get iosMajorVersion => _iosMajorVersion;
  bool get isInitialized => _initialized;

  bool get useNativeIOSNavBar =>
      defaultTargetPlatform == TargetPlatform.iOS && _iosMajorVersion >= 18;

  static Future<void> init() async {
    if (instance._initialized) return;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final version = await _channel
            .invokeMethod<int>('getIOSVersion')
            .timeout(const Duration(seconds: 2));
        instance._iosMajorVersion = version ?? 0;
      } on MissingPluginException {
        instance._iosMajorVersion = 0;
      } on PlatformException {
        instance._iosMajorVersion = 0;
      } on TimeoutException {
        instance._iosMajorVersion = 0;
      }
    }

    instance._initialized = true;
  }
}
