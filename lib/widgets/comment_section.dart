import 'package:dios_delices/services/comment_service.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:flutter/material.dart';
import '../utils/toast.dart';

class CommentSection extends StatefulWidget {
  final int targetType;
  final int targetID;

  const CommentSection({
    super.key,
    required this.targetType,
    required this.targetID,
  });

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  List<CommentData> _comments = [];
  bool _isLoading = true;
  final _commentController = TextEditingController();
  int _rating = 5;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    final comments = await CommentService.getCommentsByTarget(
      targetType: widget.targetType,
      targetID: widget.targetID,
    );
    if (!mounted) return;
    setState(() {
      _comments = comments;
      _isLoading = false;
    });
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      Toast(context, "Veuillez écrire un commentaire.", false);
      return;
    }

    final session = await SessionService.readSession();
    if (!session.isLoggedIn) {
      Toast(context, "Connectez-vous pour laisser un avis.", false);
      return;
    }

    final result = await CommentService.addComment(
      userID: session.userId,
      targetType: widget.targetType,
      targetID: widget.targetID,
      note: _rating,
      commentaire: text,
      username: "User #${session.userId}",
    );

    if (!mounted) return;

    if (result == "success") {
      _commentController.clear();
      setState(() => _rating = 5);
      Toast(context, "Commentaire ajouté !", true);
      await _loadComments();
    } else {
      Toast(context, result, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Avis et commentaires',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(5, (index) {
            return IconButton(
              icon: Icon(
                index < _rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
              ),
              onPressed: () => setState(() => _rating = index + 1),
            );
          }),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Votre avis...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _submitComment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Envoyer'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_comments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text("Aucun avis pour le moment."),
          )
        else
          ..._comments.map((comment) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.shade100,
                    child: Text(
                      comment.username.isNotEmpty
                          ? comment.username[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(comment.username)),
                      Row(
                        children: List.generate(5, (i) {
                          return Icon(
                            i < comment.note ? Icons.star : Icons.star_border,
                            size: 16,
                            color: Colors.amber,
                          );
                        }),
                      ),
                    ],
                  ),
                  subtitle: Text(comment.commentaire),
                  trailing: Text(
                    _formatDate(comment.createdAt),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              )),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return "Aujourd'hui";
    if (diff.inDays == 1) return "Hier";
    return "${date.day}/${date.month}/${date.year}";
  }
}