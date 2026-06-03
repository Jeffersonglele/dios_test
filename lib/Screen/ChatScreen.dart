import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../modeles/users.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../utils/strings.dart';

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
  final _scrollCtrl = ScrollController();
  bool isLoading = true;
  String _myUsername = '';
  int _myUserId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final session = await SessionService.readSession();
    _myUserId = session.userId;
    final users = await Users.fetchUsersFromDB();
    Users? me;
    for (final u in users) {
      if (u.userID == session.userId) {
        me = u;
        break;
      }
    }
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
      final resp =
          await func.execute(parameters: {'withUserID': widget.withUserID});
      if (resp.success && resp.result != null && mounted) {
        setState(() {
          messages = List<Map<String, dynamic>>.from(resp.result as List);
          isLoading = false;
        });
        _scrollToBottom();
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
      await func
          .execute(parameters: {'toUserID': widget.withUserID, 'text': text});
      await _loadMessages();
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: AppMotion.fast, curve: AppMotion.standard);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.brandSurface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              (widget.withUsername ?? '?')[0].toUpperCase(),
              style: AppTypography.titleMedium(color: AppColors.brand),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.withUsername ?? Strings.messages,
                style: AppTypography.titleMedium().copyWith(fontSize: 17)),
            Text(Strings.online,
                style: TextStyle(color: AppColors.success, fontSize: 11)),
          ]),
        ]),
      ),
      body: widget.withUserID != null ? _buildChat() : _buildConversationList(),
    );
  }

  Widget _buildConversationList() {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (conversations.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 64, color: AppColors.border),
          const SizedBox(height: 16),
          Text(Strings.noConversation, style: AppTypography.bodyMedium()),
          const SizedBox(height: 4),
          Text('Vos échanges apparaîtront ici.',
              style: AppTypography.bodyMedium(color: AppColors.inkSubtle)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: conversations.length,
      itemBuilder: (_, i) {
        final c = conversations[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.brandSurface,
              child: Text(c['username'].toString()[0].toUpperCase(),
                  style: AppTypography.labelMedium(color: AppColors.brand)),
            ),
            title: Text(c['username'] ?? 'Inconnu',
                style: AppTypography.labelMedium()),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.inkSubtle),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ChatScreen(
                        withUserID: c['userID'] as int,
                        withUsername: c['username'] as String?))),
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
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_rounded,
                            size: 48, color: AppColors.border),
                        const SizedBox(height: 12),
                        Text('Envoyez un premier message !',
                            style: AppTypography.bodyMedium()),
                      ]),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final fromMe = msg['fromUserID'] == _myUserId;
                    final showAvatar = i == 0 ||
                        messages[i - 1]['fromUserID'] != msg['fromUserID'];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: fromMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!fromMe && showAvatar) ...[
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.brandSurface,
                              child: Text(
                                (widget.withUsername ?? '?')[0].toUpperCase(),
                                style: AppTypography.labelMedium(
                                        color: AppColors.brand)
                                    .copyWith(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ] else if (!fromMe)
                            const SizedBox(width: 40),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.72,
                              ),
                              decoration: BoxDecoration(
                                // CÔTÉ EXPÉDITEUR = CRÈME CHAUD, CÔTÉ MOI = BRAND
                                color:
                                    fromMe ? AppColors.brand : AppColors.card,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(AppRadius.lg),
                                  topRight: const Radius.circular(AppRadius.lg),
                                  bottomLeft: Radius.circular(
                                      fromMe ? AppRadius.lg : AppRadius.sm),
                                  bottomRight: Radius.circular(
                                      fromMe ? AppRadius.sm : AppRadius.lg),
                                ),
                                border: fromMe
                                    ? null
                                    : Border.all(
                                        color: AppColors.border, width: 0.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: (fromMe
                                            ? AppColors.brand
                                            : AppColors.ink)
                                        .withValues(alpha: 0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                msg['text'] ?? '',
                                style: AppTypography.bodyLarge(
                                  color: fromMe ? Colors.white : AppColors.ink,
                                ),
                              ),
                            ),
                          ),
                          if (fromMe && showAvatar) ...[
                            const SizedBox(width: 8),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AppColors.brand,
                              child: Text(
                                _myUsername.isNotEmpty
                                    ? _myUsername[0].toUpperCase()
                                    : 'M',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ] else if (fromMe)
                            const SizedBox(width: 40),
                        ],
                      ),
                    );
                  },
                ),
        ),
        // ── Barre de saisie ──────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.card,
            border:
                Border(top: BorderSide(color: AppColors.border, width: 0.5)),
          ),
          child: SafeArea(
            child: Row(children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWarm,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: TextField(
                    controller: _msgCtrl,
                    style: AppTypography.bodyLarge(),
                    decoration: InputDecoration(
                      hintText: Strings.yourMessage,
                      hintStyle:
                          AppTypography.bodyMedium(color: AppColors.inkSubtle),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brand.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
