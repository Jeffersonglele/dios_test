import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../core/app_role.dart';
import 'session_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Configurer les notifications locales
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
    // Ici vous pouvez naviguer vers une page spécifique
    // Par exemple, vers la page des commandes du restaurateur
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

  // Méthode pour envoyer une notification de test
  static Future<void> sendTestNotification() async {
    await _showLocalNotification(
      title: 'Test Notification',
      body: 'Ceci est une notification de test',
    );
  }

  // Méthode pour envoyer une notification de commande au restaurateur
  static Future<void> sendOrderNotificationToRestaurateur({
    required int restaurateurId,
    required String restaurantName,
    required double totalAmount,
    String orderDetails = '',
    int? orderId,
  }) async {
    try {
      final cloudFunction = ParseCloudFunction('sendPushNotification');
      await cloudFunction.execute(parameters: {
        'channels': ['restaurateurs', 'user_$restaurateurId'],
        'title': 'Nouvelle commande !',
        'body': 'Commande de $totalAmount € chez $restaurantName',
        'data': {
          'type': 'new_order',
          'restaurant_name': restaurantName,
          'order_details': orderDetails,
          'total_amount': totalAmount,
          'restaurateur_id': restaurateurId,
          'order_id': orderId,
        },
      });

      if (kDebugMode) {
        debugPrint('Notification de commande envoyée au restaurateur $restaurateurId');
      }

      await _showLocalNotification(
        title: 'Nouvelle commande !',
        body: 'Commande de $totalAmount € chez $restaurantName',
      );
    } catch (e) {
      debugPrint('Erreur notification: $e');
    }
  }

  // Méthode pour s'abonner aux notifications (pour les restaurateurs)
  static Future<void> subscribeToRestaurantNotifications() async {
    try {
      final session = await SessionService.readSession();
      final userId = session.userId;
      final userRole = session.role;

      if (userId > 0 &&
          (userRole == AppRole.microRestaurant ||
              userRole == AppRole.individual)) {
        final installation = ParseObject('_Installation')
          ..set('channels', ['restaurateurs', 'user_$userId'])
          ..set('deviceType', 'android')
          ..set('appName', 'Dios Délices')
          ..set('appVersion', '1.0.0');
        await installation.save();

        if (kDebugMode) {
          debugPrint('Installation créée pour le restaurateur $userId');
        }
      }
    } catch (e) {
      debugPrint('Erreur abonnement notifications: $e');
    }
  }
}
