import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/app_config.dart';
import '../models/chat_message.dart';
import 'session_service.dart';

/// Service singleton gérant la connexion WebSocket (Socket.io) avec le backend Node.js.
///
/// Fonctionnalités :
/// - Authentification JWT avec reconnexion automatique
/// - Suivi GPS et statuts de commande en temps réel
/// - Messagerie instantanée in-app (Chat multimédia, accusés de lecture, saisie)
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  String? _currentOrderId;
  String? _currentChatOrderId;

  // ── Streams Suivi Livraison ────────────────────────────────
  final StreamController<Map<String, dynamic>> _courierMovedController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _driverLocationUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _deliveryStatusController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  // ── Streams Chat In-App ────────────────────────────────────
  final StreamController<ChatMessage> _newMessageController =
      StreamController<ChatMessage>.broadcast();

  final StreamController<Map<String, dynamic>> _messagesReadController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _userTypingController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _joinedChatController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<String> _chatErrorController =
      StreamController<String>.broadcast();

  bool get isConnected => _socket?.connected ?? false;

  /// Flux de positions GPS du livreur en direct
  Stream<Map<String, dynamic>> get onCourierMoved => _courierMovedController.stream;

  /// Flux de positions GPS du livreur en direct (événement normalisé spec)
  Stream<Map<String, dynamic>> get onDriverLocationUpdated =>
      _driverLocationUpdatedController.stream;

  /// Flux d'événements de cycle de livraison
  Stream<Map<String, dynamic>> get onDeliveryStatusChanged => _deliveryStatusController.stream;

  /// État de connexion Socket.io
  Stream<bool> get onConnectionChanged => _connectionController.stream;

  /// Flux des nouveaux messages reçus en temps réel
  Stream<ChatMessage> get onNewMessage => _newMessageController.stream;

  /// Flux des accusés de lecture
  Stream<Map<String, dynamic>> get onMessagesRead => _messagesReadController.stream;

  /// Flux de l'indicateur de saisie ("est en train d'écrire...")
  Stream<Map<String, dynamic>> get onUserTyping => _userTypingController.stream;

  /// Flux de confirmation d'adhésion au salon de discussion
  Stream<Map<String, dynamic>> get onJoinedChat => _joinedChatController.stream;

  /// Flux des erreurs de chat
  Stream<String> get onChatError => _chatErrorController.stream;

  // ── Connexion ──────────────────────────────────────────────
  Future<void> connect({String? customToken}) async {
    if (_socket != null && _socket!.connected) return;

    if (_socket != null && !_socket!.connected) {
      _socket!.connect();
      return;
    }

    try {
      final token = customToken ?? await SessionService.readNodeToken();
      if (token == null || token.isEmpty) {
        print('[SocketService] Aucun token JWT disponible — connexion socket ignorée');
        return;
      }

      final serverUrl = _resolveServerUrl();

      _socket = IO.io(
        serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(15)
            .setReconnectionDelay(2000)
            .setReconnectionDelayMax(10000)
            .setAuth({'token': token})
            .setExtraHeaders({'Authorization': 'Bearer $token'})
            .build(),
      );

      _socket!.onConnect((_) {
        print('[SocketService] ✔ Connecté au serveur Socket.io');
        _connectionController.add(true);

        if (_currentOrderId != null) {
          joinOrderTracking(_currentOrderId!);
          joinOrderRoom(_currentOrderId!);
        }
        if (_currentChatOrderId != null) {
          joinOrderChat(_currentChatOrderId!);
        }
      });

      _socket!.onConnectError((error) {
        print('[SocketService] Erreur de connexion: $error');
        _connectionController.add(false);
      });

      _socket!.onDisconnect((_) {
        print('[SocketService] ✖ Déconnecté du serveur');
        _connectionController.add(false);
      });

      _socket!.onReconnect((_) {
        print('[SocketService] ↻ Reconnecté au serveur');
        _connectionController.add(true);
        if (_currentOrderId != null) {
          joinOrderTracking(_currentOrderId!);
          joinOrderRoom(_currentOrderId!);
        }
        if (_currentChatOrderId != null) {
          joinOrderChat(_currentChatOrderId!);
        }
      });

      _socket!.on('error', (data) {
        print('[SocketService] Erreur serveur socket: $data');
      });

      // ── Écouteurs de suivi ─────────────────────────────────
      _socket!.on('courier_moved', (data) {
        if (data is Map<String, dynamic>) {
          _courierMovedController.add(data);
        } else if (data is Map) {
          _courierMovedController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.on('driver_location_updated', (data) {
        final map = data is Map<String, dynamic>
            ? data
            : data is Map
                ? Map<String, dynamic>.from(data)
                : null;
        if (map == null) return;
        _driverLocationUpdatedController.add(map);
        // Assure la compatibilité ascendante : retransmet aussi via onCourierMoved
        final lat = map['lat'] ?? map['latitude'];
        final lng = map['lng'] ?? map['longitude'];
        if (lat != null && lng != null) {
          _courierMovedController.add({
            ...map,
            if (!map.containsKey('latitude')) 'latitude': lat,
            if (!map.containsKey('longitude')) 'longitude': lng,
          });
        }
      });

      _socket!.on('delivery_status_changed', (data) {
        if (data is Map<String, dynamic>) {
          _deliveryStatusController.add(data);
        } else if (data is Map) {
          _deliveryStatusController.add(Map<String, dynamic>.from(data));
        }
      });

      // ── Écouteurs de Chat ──────────────────────────────────
      _socket!.on('new_message', (data) {
        try {
          if (data is Map<String, dynamic>) {
            _newMessageController.add(ChatMessage.fromJson(data));
          } else if (data is Map) {
            _newMessageController.add(ChatMessage.fromJson(Map<String, dynamic>.from(data)));
          }
        } catch (e) {
          print('[SocketService] Erreur parsing new_message: $e');
        }
      });

      _socket!.on('messages_read', (data) {
        if (data is Map<String, dynamic>) {
          _messagesReadController.add(data);
        } else if (data is Map) {
          _messagesReadController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.on('user_typing', (data) {
        if (data is Map<String, dynamic>) {
          _userTypingController.add(data);
        } else if (data is Map) {
          _userTypingController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.on('joined_chat', (data) {
        if (data is Map<String, dynamic>) {
          _joinedChatController.add(data);
        } else if (data is Map) {
          _joinedChatController.add(Map<String, dynamic>.from(data));
        }
      });

      _socket!.on('chat_error', (data) {
        final msg = data is Map ? (data['message']?.toString() ?? 'Erreur chat') : data.toString();
        _chatErrorController.add(msg);
      });
    } catch (e) {
      print('[SocketService] Échec d\'initialisation du socket: $e');
    }
  }

  // ── Déconnexion ────────────────────────────────────────────
  void disconnect() {
    if (_currentOrderId != null) {
      leaveOrderTracking(_currentOrderId!);
    }
    if (_currentChatOrderId != null) {
      leaveOrderChat(_currentChatOrderId!);
    }
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _currentOrderId = null;
    _currentChatOrderId = null;
    _connectionController.add(false);
  }

  // ── Gestion du Suivi Livraison ──────────────────────────────
  void joinOrderTracking(String orderId) {
    _currentOrderId = orderId;
    if (_socket == null || !_socket!.connected) return;
    _socket!.emit('join_order_tracking', {'orderId': orderId});
  }

  void leaveOrderTracking(String orderId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('leave_order_tracking', {'orderId': orderId});
    }
    if (_currentOrderId == orderId) {
      _currentOrderId = null;
    }
  }

  /// Rejoint la room de suivi d'une commande (spec v2).
  void joinOrderRoom(String orderId) {
    _currentOrderId ??= orderId;
    if (_socket == null || !_socket!.connected) return;
    _socket!.emit('join_order_room', orderId);
  }

  /// Quitte la room de suivi d'une commande (spec v2).
  void leaveOrderRoom(String orderId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('leave_order_room', orderId);
    }
  }

  /// Émet la position GPS du livreur vers le serveur (spec v2).
  /// Corps : { orderId, lat, lng, heading }
  void emitUpdateLocation({
    required dynamic orderId,
    required double lat,
    required double lng,
    double? heading,
  }) {
    emit('update_location', {
      'orderId': orderId.toString(),
      'lat': lat,
      'lng': lng,
      if (heading != null && !heading.isNaN) 'heading': heading,
    });
  }

  void emitCourierLocation({
    required String orderId,
    required double latitude,
    required double longitude,
    double? accuracyM,
    double? heading,
  }) {
    emit('courier_location_update', {
      'orderId': orderId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracyM': accuracyM,
      'heading': heading,
    });
  }

  // ── Gestion du Chat In-App ─────────────────────────────────
  /// Rejoindre la room de discussion pour une commande
  void joinOrderChat(String orderId) {
    _currentChatOrderId = orderId;
    if (_socket == null || !_socket!.connected) return;
    _socket!.emit('join_order_chat', {'orderId': orderId});
    print('[SocketService] Émission join_order_chat pour commande #$orderId');
  }

  /// Quitter la room de discussion
  void leaveOrderChat(String orderId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('leave_order_chat', {'orderId': orderId});
    }
    if (_currentChatOrderId == orderId) {
      _currentChatOrderId = null;
    }
    print('[SocketService] Quitté le salon de chat pour commande #$orderId');
  }

  /// Envoyer un message texte ou multimédia (Image / Audio)
  void sendChatMessage({
    required dynamic orderId,
    String? text,
    String messageType = 'TEXT',
    String? mediaUrl,
    int? mediaDuration,
    String? mediaMimeType,
    int? mediaSize,
    int? toUserId,
  }) {
    emit('send_message', {
      'orderId': orderId.toString(),
      if (text != null && text.isNotEmpty) 'text': text,
      'messageType': messageType,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (mediaDuration != null) 'mediaDuration': mediaDuration,
      if (mediaMimeType != null) 'mediaMimeType': mediaMimeType,
      if (mediaSize != null) 'mediaSize': mediaSize,
      if (toUserId != null) 'toUserId': toUserId,
    });
  }

  /// Marquer des messages comme lus
  void markMessagesAsRead({
    required dynamic orderId,
    required List<dynamic> messageIds,
  }) {
    if (messageIds.isEmpty) return;
    emit('mark_as_read', {
      'orderId': orderId.toString(),
      'messageIds': messageIds,
    });
  }

  /// Émettre le statut de saisie ("est en train d'écrire...")
  void sendTypingStatus({
    required dynamic orderId,
    required bool isTyping,
  }) {
    emit('user_typing', {
      'orderId': orderId.toString(),
      'isTyping': isTyping,
    });
  }

  // ── Émission générique ─────────────────────────────────────
  void emit(String event, dynamic data) {
    if (_socket == null || !_socket!.connected) {
      print('[SocketService] Impossible d\'émettre $event — socket non connecté');
      return;
    }
    _socket!.emit(event, data);
  }

  String _resolveServerUrl() {
    const override = String.fromEnvironment('SOCKET_SERVER_URL');
    if (override.isNotEmpty) return override;
    return AppConfig.nodeBackendUrl.replaceFirst(RegExp(r'/+$'), '');
  }

  void dispose() {
    disconnect();
    _courierMovedController.close();
    _driverLocationUpdatedController.close();
    _deliveryStatusController.close();
    _connectionController.close();
    _newMessageController.close();
    _messagesReadController.close();
    _userTypingController.close();
    _joinedChatController.close();
    _chatErrorController.close();
  }
}
