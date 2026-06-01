import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../modeles/users.dart';
import '../services/session_service.dart';

class ChatScreen extends StatefulWidget {
  final int? withUserID;
  final String? withUsername;

  const ChatScreen({super.key, this.withUserID, this.withUsername});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Map<String, dynamic>> messages = [];
  List<Map<String, dynamic>> conversations = [];
  final TextEditingController _msgCtrl = TextEditingController();
  bool isLoading = true;
  String _myUsername = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = await SessionService.readSession();
    final users = await Users.fetchUsersFromDB();
    Users? me;
    for (final u in users) { if (u.userID == session.userId) { me = u; break; } }
    if (mounted) setState(() => _myUsername = me?.username ?? '');

    if (widget.withUserID != null) {
      await _loadMessages();
    } else {
      await _loadConversations();
    }
  }

  Future<void> _loadConversations() async {
    try {
      final func = ParseCloudFunction('getMyConversations');
      final resp = await func.execute();
      if (resp.success && resp.result != null && mounted) {
        setState(() {
          conversations = List<Map<String, dynamic>>.from(resp.result as List);
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadMessages() async {
    try {
      final func = ParseCloudFunction('getConversation');
      final resp = await func.execute(parameters: {'withUserID': widget.withUserID});
      if (resp.success && resp.result != null && mounted) {
        setState(() {
          messages = List<Map<String, dynamic>>.from(resp.result as List);
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || widget.withUserID == null) return;
    _msgCtrl.clear();
    try {
      final func = ParseCloudFunction('sendMessage');
      await func.execute(parameters: {
        'toUserID': widget.withUserID,
        'text': text,
      });
      await _loadMessages();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.withUsername ?? 'Messages'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: widget.withUserID != null ? _buildChat() : _buildConversationList(),
    );
  }

  Widget _buildConversationList() {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (conversations.isEmpty) {
      return const Center(child: Text('Aucune conversation.', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      itemCount: conversations.length,
      itemBuilder: (ctx, i) {
        final c = conversations[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.deepOrange.shade50,
            child: Text(c['username'].toString()[0].toUpperCase(),
                style: const TextStyle(color: Colors.deepOrange)),
          ),
          title: Text(c['username'] ?? 'Inconnu'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                withUserID: c['userID'] as int,
                withUsername: c['username'] as String?,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChat() {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? const Center(child: Text('Aucun message. Envoyez un message !'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) {
                    final msg = messages[i];
                    final isMe = msg['fromUserID'] == widget.withUserID ? false : true;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.deepOrange : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 3)],
                        ),
                        child: Text(
                          msg['text'] ?? '',
                          style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.grey.shade200, spreadRadius: 1, blurRadius: 5)],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Votre message...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.deepOrange,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
