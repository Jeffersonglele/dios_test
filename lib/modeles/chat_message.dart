import 'dart:convert';
import 'package:hive/hive.dart';

class ChatMessage {
  final String messageId;
  final int senderId;
  final int receiverId;
  final String text;
  final String conversationId;
  final DateTime createdAt;
  bool isRead;

  ChatMessage({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.conversationId,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() => {
    'messageId': messageId,
    'senderId': senderId,
    'receiverId': receiverId,
    'text': text,
    'conversationId': conversationId,
    'createdAt': createdAt.toIso8601String(),
    'isRead': isRead,
  };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    messageId: map['messageId']?.toString() ?? '',
    senderId: int.tryParse(map['senderId']?.toString() ?? '0') ?? 0,
    receiverId: int.tryParse(map['receiverId']?.toString() ?? '0') ?? 0,
    text: map['text']?.toString() ?? '',
    conversationId: map['conversationId']?.toString() ?? '',
    createdAt: map['createdAt'] != null
        ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
        : DateTime.now(),
    isRead: map['isRead'] == true || map['isRead']?.toString() == 'true',
  );

  static const String boxName = 'chat_messages';

  static Future<Box<String>> _box() => Hive.openBox<String>(boxName);

  static Future<void> saveMessages(String conversationId, List<ChatMessage> msgs) async {
    final box = await _box();
    final json = jsonEncode(msgs.map((m) => m.toMap()).toList());
    await box.put(conversationId, json);
  }

  static Future<List<ChatMessage>> loadMessages(String conversationId) async {
    final box = await _box();
    final json = box.get(conversationId);
    if (json == null) return [];
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => ChatMessage.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  static Future<void> addMessage(String conversationId, ChatMessage msg) async {
    final msgs = await loadMessages(conversationId);
    final exists = msgs.any((m) => m.messageId == msg.messageId);
    if (!exists) {
      msgs.add(msg);
      await saveMessages(conversationId, msgs);
    }
  }

  static Future<List<ChatMessage>> getAllConversationsPreview(int myUserId) async {
    final box = await _box();
    final Map<String, ChatMessage> latest = {};
    for (final entry in box.toMap().entries) {
      final json = entry.value as String?;
      if (json == null || json.isEmpty) continue;
      final list = jsonDecode(json) as List<dynamic>;
      if (list.isEmpty) continue;
      final last = list.last as Map;
      final msg = ChatMessage.fromMap(Map<String, dynamic>.from(last));
      if (msg.senderId == myUserId || msg.receiverId == myUserId) {
        final existing = latest[msg.conversationId];
        if (existing == null || msg.createdAt.isAfter(existing.createdAt)) {
          latest[msg.conversationId] = msg;
        }
      }
    }
    final sorted = latest.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }
}
