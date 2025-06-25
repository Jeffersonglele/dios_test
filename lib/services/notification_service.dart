import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  // Configuration Back4App
  static const String _back4appApplicationId = '9qBeGGwSGOQ1iWOJ1UNUXt40NhgwwgbHJYGpV1zg';
  static const String _back4appRestApiKey = 'YKeFfBUqtkZBcEIUKPDtVIbsB5DU1gfBZlb0YFoa';
  static const String _back4appPushUrl = 'https://parseapi.back4app.com/push';

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

    print('Service de notifications initialisé');
  }

  static void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapée: ${response.payload}');
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
    required String orderDetails,
    required double totalAmount,
    int? orderId,
  }) async {
    try {
      // Envoyer la notification via l'API REST Back4App
      final response = await http.post(
        Uri.parse(_back4appPushUrl),
        headers: {
          'X-Parse-Application-Id': _back4appApplicationId,
          'X-Parse-REST-API-Key': _back4appRestApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'where': {
            'channels': ['restaurateurs', 'user_$restaurateurId']
          },
          'data': {
            'alert': {
              'title': '🍽️ Nouvelle commande reçue !',
              'body': 'Commande de $totalAmount€ chez $restaurantName',
            },
            'badge': 'Increment',
            'sound': 'default',
            'custom_data': {
              'type': 'new_order',
              'restaurant_name': restaurantName,
              'order_details': orderDetails,
              'total_amount': totalAmount,
              'restaurateur_id': restaurateurId,
              'order_id': orderId,
            }
          }
        }),
      );

      if (response.statusCode == 200) {
        print('Notification de commande envoyée au restaurateur $restaurateurId');

        // Afficher aussi une notification locale pour confirmation
        await _showLocalNotification(
          title: '🍽️ Nouvelle commande reçue !',
          body: 'Commande de $totalAmount€ chez $restaurantName',
        );
      } else {
        print('Erreur lors de l\'envoi de la notification: ${response.body}');
      }
    } catch (e) {
      print('Erreur lors de l\'envoi de la notification: $e');
    }
  }

  // Méthode pour s'abonner aux notifications (pour les restaurateurs)
  static Future<void> subscribeToRestaurantNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('loggedUserID');
      final userRole = prefs.getInt('userRole');

      if (userId != null && userRole == 2) { // Role 2 = Restaurateur
        // Créer une installation pour cet utilisateur
        final response = await http.post(
          Uri.parse('https://parseapi.back4app.com/installations'),
          headers: {
            'X-Parse-Application-Id': _back4appApplicationId,
            'X-Parse-REST-API-Key': _back4appRestApiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'channels': ['restaurateurs', 'user_$userId'],
            'deviceType': 'android', // ou 'ios'
            'appName': 'Dios Délices',
            'appVersion': '1.0.0',
          }),
        );

        if (response.statusCode == 201) {
          print('Installation créée et abonnée aux notifications pour le restaurateur $userId');
        } else {
          print('Erreur lors de la création de l\'installation: ${response.body}');
        }
      }
    } catch (e) {
      print('Erreur lors de l\'abonnement aux notifications: $e');
    }
  }
}