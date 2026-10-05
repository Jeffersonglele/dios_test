class ChatMessage {
  final int? id;
  final int? orderId;
  final int? fromUserId;
  final int? toUserId;
  final String? text;
  final String messageType; // 'TEXT', 'IMAGE', 'AUDIO'
  final String? mediaUrl;
  final int? mediaDuration; // in seconds
  final String? mediaMimeType;
  final int? mediaSize;
  final bool read;
  final DateTime? readAt;
  final DateTime? deliveredAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ChatMessage({
    this.id,
    this.orderId,
    this.fromUserId,
    this.toUserId,
    this.text,
    this.messageType = 'TEXT',
    this.mediaUrl,
    this.mediaDuration,
    this.mediaMimeType,
    this.mediaSize,
    this.read = false,
    this.readAt,
    this.deliveredAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isText => messageType.toUpperCase() == 'TEXT';
  bool get isImage => messageType.toUpperCase() == 'IMAGE';
  bool get isAudio => messageType.toUpperCase() == 'AUDIO';

  String get formattedDuration {
    if (mediaDuration == null || mediaDuration! <= 0) return '0:00';
    final minutes = mediaDuration! ~/ 60;
    final seconds = mediaDuration! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? ''),
      orderId: json['orderId'] is int ? json['orderId'] as int : int.tryParse(json['orderId']?.toString() ?? ''),
      fromUserId: json['fromUserId'] is int ? json['fromUserId'] as int : int.tryParse(json['fromUserId']?.toString() ?? ''),
      toUserId: json['toUserId'] is int ? json['toUserId'] as int : int.tryParse(json['toUserId']?.toString() ?? ''),
      text: json['text'] as String?,
      messageType: (json['messageType'] as String?)?.toUpperCase() ?? 'TEXT',
      mediaUrl: json['mediaUrl'] as String?,
      mediaDuration: json['mediaDuration'] is int ? json['mediaDuration'] as int : int.tryParse(json['mediaDuration']?.toString() ?? ''),
      mediaMimeType: json['mediaMimeType'] as String?,
      mediaSize: json['mediaSize'] is int ? json['mediaSize'] as int : int.tryParse(json['mediaSize']?.toString() ?? ''),
      read: json['read'] == true || json['read'] == 1,
      readAt: json['readAt'] != null ? DateTime.tryParse(json['readAt'].toString()) : null,
      deliveredAt: json['deliveredAt'] != null ? DateTime.tryParse(json['deliveredAt'].toString()) : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (orderId != null) 'orderId': orderId,
      if (fromUserId != null) 'fromUserId': fromUserId,
      if (toUserId != null) 'toUserId': toUserId,
      if (text != null) 'text': text,
      'messageType': messageType,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (mediaDuration != null) 'mediaDuration': mediaDuration,
      if (mediaMimeType != null) 'mediaMimeType': mediaMimeType,
      if (mediaSize != null) 'mediaSize': mediaSize,
      'read': read,
      if (readAt != null) 'readAt': readAt!.toIso8601String(),
      if (deliveredAt != null) 'deliveredAt': deliveredAt!.toIso8601String(),
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  ChatMessage copyWith({
    int? id,
    int? orderId,
    int? fromUserId,
    int? toUserId,
    String? text,
    String? messageType,
    String? mediaUrl,
    int? mediaDuration,
    String? mediaMimeType,
    int? mediaSize,
    bool? read,
    DateTime? readAt,
    DateTime? deliveredAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      text: text ?? this.text,
      messageType: messageType ?? this.messageType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaDuration: mediaDuration ?? this.mediaDuration,
      mediaMimeType: mediaMimeType ?? this.mediaMimeType,
      mediaSize: mediaSize ?? this.mediaSize,
      read: read ?? this.read,
      readAt: readAt ?? this.readAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
