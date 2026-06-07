import 'package:dios_delices/theme/app_theme.dart';
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
        Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppColors.brandSurface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.rate_review_rounded,
                  color: AppColors.brand, size: 16),
            ),
            const SizedBox(width: 10),
            Text('Avis et commentaires',
                style: AppTypography.titleMedium(
                    color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
          ],
        ),
        const SizedBox(height: 16),
        // ── Nouvel avis ────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.resolve(AppColors.card, AppDarkColors.card),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
                color: AppColors.resolve(AppColors.border, AppDarkColors.border),
                width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () => setState(() => _rating = index + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: AppColors.resolve(AppColors.accent, AppDarkColors.accent),
                        size: 32,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Votre avis...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(
                              color: AppColors.resolve(AppColors.border, AppDarkColors.border)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _submitComment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
                      foregroundColor: Colors.white,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                    child: const Text('Envoyer'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // ── Liste des avis ────
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_comments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: AppColors.resolve(AppColors.card, AppDarkColors.card),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(children: [
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 32,
                  color: AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle)),
              const SizedBox(height: 8),
              Text("Aucun avis pour le moment.",
                  style: AppTypography.bodyMedium(
                      color: AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle))),
            ]),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: _comments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final comment = _comments[i];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.resolve(AppColors.card, AppDarkColors.card),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                        color: AppColors.resolve(AppColors.border, AppDarkColors.border)
                            .withValues(alpha: 0.3),
                        width: 0.5),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.brandSurface,
                        child: Text(
                          comment.username.isNotEmpty
                              ? comment.username[0].toUpperCase()
                              : '?',
                          style: AppTypography.labelMedium(color: AppColors.brand)
                              .copyWith(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(comment.username,
                                      style: AppTypography.labelMedium(
                                          color: AppColors.resolve(
                                              AppColors.ink, AppDarkColors.ink))
                                          .copyWith(fontSize: 13)),
                                ),
                                Text(_formatDate(comment.createdAt),
                                    style: AppTypography.bodyMedium(
                                            color: AppColors.resolve(
                                                AppColors.inkSubtle, AppDarkColors.inkSubtle))
                                        .copyWith(fontSize: 10)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: List.generate(5, (j) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 1),
                                  child: Icon(
                                    j < comment.note
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    size: 13,
                                    color: AppColors.resolve(
                                        AppColors.accent, AppDarkColors.accent),
                                  ),
                                );
                              }),
                            ),
                            if (comment.commentaire.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(comment.commentaire,
                                  style: AppTypography.bodyMedium(
                                          color: AppColors.resolve(
                                              AppColors.ink, AppDarkColors.ink))
                                      .copyWith(fontSize: 12)),
                            ],
                            if (comment.tags.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                runSpacing: 2,
                                children: comment.tags.map((tag) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.brandSurface,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(tag,
                                      style: AppTypography.bodyMedium(color: AppColors.brand)
                                          .copyWith(fontSize: 10)),
                                )).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
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