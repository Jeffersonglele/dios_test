import 'package:dios_delices/models/ligne_commande.dart';
import 'package:dios_delices/services/comment_service.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/currency_util.dart';
import 'package:dios_delices/utils/rating_tags.dart';
import 'package:dios_delices/utils/toast.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RatingDialog extends StatefulWidget {
  final int targetType;
  final int targetID;
  final String title;
  final List<LigneCommande>? lignes;
  final Map<int, String>? dishNames;

  const RatingDialog({
    super.key,
    required this.targetType,
    required this.targetID,
    this.title = 'Noter',
    this.lignes,
    this.dishNames,
  });

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _note = 5;
  final _commentCtrl = TextEditingController();
  Set<String> _selectedTags = {};
  String _country = 'RDC';

  List<RatingTag> get _tags => tagsForTargetType(widget.targetType);

  @override
  void initState() {
    super.initState();
    _loadCountry();
  }

  Future<void> _loadCountry() async {
    final session = await SessionService.readSession();
    if (mounted) setState(() => _country = session.country);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = await SessionService.readSession();
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('currentUser_name') ?? '';

    if (session.userId == null) {
      if (mounted) {
        Toast(context, AppLocalizations.of(context)!.user_not_connected, false);
      }
      return;
    }

    final result = await CommentService.addComment(
      userID: session.userId!,
      targetType: widget.targetType,
      targetID: widget.targetID,
      note: _note,
      commentaire: _commentCtrl.text.trim(),
      username: username,
      tags: _selectedTags.toList(),
    );

    if (mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRestaurant = widget.targetType == 1;
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl)),
      title: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(isRestaurant
              ? Icons.restaurant_rounded
              : Icons.delivery_dining_rounded,
              color: AppColors.accent, size: 18),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(widget.title,
            style: AppTypography.titleMedium(
                color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
      ]),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Plats commandés (restaurant only) ────────
            if (isRestaurant &&
                widget.lignes != null &&
                widget.lignes!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.resolve(
                      AppColors.surfaceWarm, AppDarkColors.surfaceWarm),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.ordered_dishes,
                        style: AppTypography.labelMedium(
                            color: AppColors.resolve(
                                AppColors.inkMuted, AppDarkColors.inkMuted))),
                    const SizedBox(height: AppSpacing.sm),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: widget.lignes!.length > 4 ? 140 : double.infinity,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          children: widget.lignes!.map((l) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: AppColors.brandSurface,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Center(
                                    child: Text('${l.quantite}',
                                        style: AppTypography.labelMedium(
                                                color: AppColors.brand)
                                            .copyWith(fontSize: 10)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    (l.nomPlat?.trim().isNotEmpty == true
                                            ? l.nomPlat!.trim()
                                            : null) ??
                                        widget.dishNames?[l.platID] ??
                                        l10n.dish_num(l.platID),
                                    style: AppTypography.bodyMedium(
                                            color: AppColors.resolve(
                                                AppColors.ink, AppDarkColors.ink))
                                        .copyWith(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  CurrencyUtil.formatPrice(l.prixUnitaire, _country),
                                  style: AppTypography.labelMedium(
                                          color: AppColors.brand)
                                      .copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                          )).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            // ── Étoiles ──────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return GestureDetector(
                  onTap: () => setState(() => _note = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      i < _note
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: AppColors.resolve(
                          AppColors.accent, AppDarkColors.accent),
                      size: 38,
                    ),
                  ),
                );
              }),
            ),
            // ── Tags ─────────────────────────────────────
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.local_offer_rounded, size: 14,
                      color: AppColors.resolve(
                          AppColors.inkMuted, AppDarkColors.inkMuted)),
                  const SizedBox(width: 6),
                  Text(l10n.features,
                      style: AppTypography.labelMedium(
                          color: AppColors.resolve(
                              AppColors.inkMuted, AppDarkColors.inkMuted))),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _tags.map((tag) {
                  final selected = _selectedTags.contains(tag.label);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        _selectedTags.remove(tag.label);
                      } else {
                        _selectedTags.add(tag.label);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.resolve(
                                AppColors.brand, AppDarkColors.brand)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? AppColors.resolve(
                                  AppColors.brand, AppDarkColors.brand)
                              : AppColors.resolve(AppColors.border,
                                      AppDarkColors.border)
                                  .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(tag.icon, size: 13,
                              color: selected
                                  ? Colors.white
                                  : AppColors.resolve(AppColors.inkMuted,
                                      AppDarkColors.inkMuted)),
                          const SizedBox(width: 4),
                          Text(tag.label,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.resolve(AppColors.inkMuted,
                                          AppDarkColors.inkMuted))),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            // ── Commentaire ──────────────────────────────
            const SizedBox(height: 16),
            TextField(
              controller: _commentCtrl,
              decoration: InputDecoration(
                labelText: l10n.your_review,
                hintText: l10n.share_experience_hint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(
                      color: AppColors.resolve(
                          AppColors.border, AppDarkColors.border)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(
                      color: AppColors.resolve(
                          AppColors.border, AppDarkColors.border)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(
                      color: AppColors.resolve(
                          AppColors.brand, AppDarkColors.brand),
                      width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(l10n.cancel,
              style: TextStyle(
                  color: AppColors.resolve(
                      AppColors.inkMuted, AppDarkColors.inkMuted))),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.resolve(
                AppColors.brand, AppDarkColors.brand),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: Text(l10n.send),
        ),
      ],
    );
  }
}
