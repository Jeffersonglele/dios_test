import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../core/app_role.dart';
import 'session_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    if (kDebugMode) {
      debugPrint('Service de notifications initialisé');
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      debugPrint('Notification tapée: ${response.payload}');
    }
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

  static Future<void> subscribeToRestaurantNotifications() async {
    try {
      final session = await SessionService.readSession();
      if (session.isLoggedIn && session.role == AppRole.microRestaurant) {
        // Enregistrer l'installation pour ce restaurateur
        final installation = ParseInstallation();
        installation
            .set('channels', ['restaurateurs', 'user_${session.userId}']);
        installation.set('deviceType', 'web');
        installation.set('appName', 'Dios Délices');
        await installation.save();

        if (kDebugMode) {
          debugPrint(
              'Installation créée pour le restaurateur ${session.userId}');
        }
      }
    } catch (e) {
      debugPrint('Erreur abonnement notifications: $e');
    }
  }

  static Future<void> sendOrderNotificationToRestaurateur({
    required int restaurateurId,
    required String restaurantName,
    required double totalAmount,
    int? orderId,
  }) async {
    await _showLocalNotification(
      title: 'Nouvelle commande !',
      body: 'Commande de $totalAmount € chez $restaurantName',
      payload: orderId?.toString(),
    );
  }
}
