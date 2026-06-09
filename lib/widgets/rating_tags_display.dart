import 'dart:convert';

import 'package:dios_delices/services/comment_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/rating_tags.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class CharacteristicsDisplay extends StatelessWidget {
  final int targetType;
  final int targetID;
  final double height;

  const CharacteristicsDisplay({
    super.key,
    required this.targetType,
    required this.targetID,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: CommentService.getTargetCharacteristics(
        targetType: targetType,
        targetID: targetID,
      ),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final data = snap.data!;
        final note = (data['note'] ?? 0).toDouble();
        final raw = data['characteristics'];
        List<dynamic> chars = [];
        if (raw is List) {
          chars = raw;
        } else if (raw is String && raw.isNotEmpty) {
          try {
            chars = jsonDecode(raw) as List<dynamic>;
          } catch (_) {}
        }

        if (chars.isEmpty && note <= 0) return const SizedBox.shrink();

        final tags = tagsForTargetType(targetType);
        return Container(
          constraints: BoxConstraints(maxHeight: height),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (chars.isNotEmpty && tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: chars.take(6).map((c) {
                      final tagLabel = c['tag'] ?? '';
                      final pct = c['pct'] ?? 0;
                      final matches = tags.where(
                          (t) => t.label == tagLabel);
                      final tag = matches.isNotEmpty ? matches.first : null;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.brandSurface,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (tag != null)
                              Icon(tag.icon,
                                  size: 12, color: AppColors.brand),
                            if (tag != null) const SizedBox(width: 4),
                            Text('$tagLabel $pct%',
                                style: AppTypography.labelMedium(
                                        color: AppColors.brand)
                                    .copyWith(fontSize: 11)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class PaginatedComments extends StatefulWidget {
  final int targetType;
  final int targetID;

  const PaginatedComments({
    super.key,
    required this.targetType,
    required this.targetID,
  });

  @override
  State<PaginatedComments> createState() => _PaginatedCommentsState();
}

class _PaginatedCommentsState extends State<PaginatedComments> {
  List<CommentData> _comments = [];
  bool _isLoading = true;
  int _page = 0;
  int _totalCount = 0;
  static const _pageSize = 5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      CommentService.getCommentsByTarget(
        targetType: widget.targetType,
        targetID: widget.targetID,
        limit: _pageSize,
        skip: _page * _pageSize,
      ),
      CommentService.getCommentCount(
        targetType: widget.targetType,
        targetID: widget.targetID,
      ),
    ]);
    if (!mounted) return;
    setState(() {
      _comments = results[0] as List<CommentData>;
      _totalCount = results[1] as int;
      _isLoading = false;
    });
  }

  void _previous() {
    if (_page > 0) {
      setState(() => _page--);
      _load();
    }
  }

  void _next() {
    if ((_page + 1) * _pageSize < _totalCount) {
      setState(() => _page++);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(l10n.no_reviews_yet,
            style: AppTypography.bodyMedium()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(_comments.length, (i) {
          final c = _comments[i];
          final tags = tagsForTargetType(widget.targetType);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.brandSurface,
                  child: Text(
                    c.username.isNotEmpty
                        ? c.username[0].toUpperCase()
                        : '?',
                    style: AppTypography.labelMedium(color: AppColors.brand),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(c.username,
                            style: AppTypography.labelMedium().copyWith(
                                fontSize: 13)),
                        const Spacer(),
                        Row(
                            children: List.generate(5, (si) => Icon(
                                  si < c.note
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  size: 14,
                                  color: AppColors.accent,
                                ))),
                      ]),
                      if (c.tags.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: c.tags.map((t) {
                            final matches = tags.where(
                                (ta) => ta.label == t);
                            final tag = matches.isNotEmpty ? matches.first : null;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.brandSurface,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (tag != null)
                                    Icon(tag.icon,
                                        size: 10, color: AppColors.brand),
                                  if (tag != null) const SizedBox(width: 2),
                                  Text(t,
                                      style: AppTypography.labelMedium(
                                              color: AppColors.brand)
                                          .copyWith(fontSize: 10)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      if (c.commentaire.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(c.commentaire,
                            style: AppTypography.bodyMedium().copyWith(
                                fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const Divider(height: 1),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.reviews_count(_totalCount),
                style: AppTypography.bodyMedium().copyWith(
                    fontSize: 12, color: AppColors.inkMuted)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_page > 0)
                  TextButton.icon(
                    onPressed: _previous,
                    icon: const Icon(Icons.chevron_left_rounded, size: 16),
                    label: Text(l10n.previous,
                        style: const TextStyle(fontSize: 12)),
                  ),
                if ((_page + 1) * _pageSize < _totalCount)
                  TextButton.icon(
                    onPressed: _next,
                    icon: const Icon(Icons.chevron_right_rounded, size: 16),
                    label: Text(l10n.next,
                        style: const TextStyle(fontSize: 12)),
                    iconAlignment: IconAlignment.end,
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
