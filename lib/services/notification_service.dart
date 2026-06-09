import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'session_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // handled by FCM system tray for background/terminated
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    await initMessaging();
    await requestPermissions();
  }

  static Future<void> requestPermissions() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Android 13+ : demande explicite du runtime POST_NOTIFICATIONS
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } catch (_) {}
    }

    // iOS : demande explicite via flutter_local_notifications
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final iOSPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        await iOSPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      } catch (_) {}
    }
  }

  static Future<bool> get isPermissionGranted async {
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  static Future<void> initMessaging() async {
    final messaging = FirebaseMessaging.instance;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationData(initialMessage.data);
    }
  }

  static void _onForegroundMessage(RemoteMessage message) {
    _showLocalNotification(
      title: message.notification?.title ?? 'Dios Délices',
      body: message.notification?.body ?? '',
      payload: message.data['type']?.toString(),
    );
  }

  static void _onMessageOpenedApp(RemoteMessage message) {
    _handleNotificationData(message.data);
  }

  static void _handleNotificationData(Map<String, dynamic> data) {
    // Future: navigate based on type
  }

  static void _onNotificationTapped(NotificationResponse response) {
    // Future: navigate based on payload
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'dios_delices_channel',
      'Dios Délices Notifications',
      channelDescription: 'Notifications pour les commandes et mises à jour',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  static Future<void> sendTestNotification() async {
    await _showLocalNotification(
      title: 'Test Notification',
      body: 'Ceci est une notification de test',
    );
  }

  static Future<void> sendOrderNotificationToRestaurateur({
    required int restaurateurId,
    required String restaurantName,
    required double totalAmount,
    String orderDetails = '',
    int? orderId,
    String currencySymbol = '€',
  }) async {
    try {
      final cloudFunction = ParseCloudFunction('sendPushNotification');
      await cloudFunction.execute(parameters: {
        'userId': restaurateurId,
        'title': 'Nouvelle commande !',
        'body': 'Commande de $totalAmount $currencySymbol chez $restaurantName',
        'data': {
          'type': 'new_order',
          'restaurant_name': restaurantName,
          'order_details': orderDetails,
          'total_amount': totalAmount,
          'restaurateur_id': restaurateurId,
          'order_id': orderId,
        },
      });

      await _showLocalNotification(
        title: 'Nouvelle commande !',
        body: 'Commande de $totalAmount $currencySymbol chez $restaurantName',
      );
    } catch (_) {}
  }

  static Future<void> subscribeToRestaurantNotifications() async {
    try {
      final session = await SessionService.readSession();
      final userId = session.userId;
      final userRole = session.role;

      if (userId <= 0) return;

      final messaging = FirebaseMessaging.instance;
      final fcmToken = await messaging.getToken();

      final installation = await ParseInstallation.currentInstallation();
      installation.set('userID', userId);
      installation.set('channels', ['restaurateurs', 'user_$userId']);
      if (fcmToken != null) {
        installation.deviceToken = fcmToken;
      }
      await installation.save();

      messaging.onTokenRefresh.listen((newToken) async {
        final inst = await ParseInstallation.currentInstallation();
        inst.deviceToken = newToken;
        inst.set('userID', userId);
        inst.set('channels', ['restaurateurs', 'user_$userId']);
        await inst.save();
      });
    } catch (_) {}
  }
}
