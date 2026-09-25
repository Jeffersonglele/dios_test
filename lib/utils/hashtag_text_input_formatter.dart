import 'package:dios_delices/models/category.dart';
import 'package:dios_delices/providers/theme_provider.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

class HashtagTextInputFormatter extends StatefulWidget {
  final Function(List<String>) onHashtagsChanged;
  final List<String> initialHashtags;

  const HashtagTextInputFormatter({
    super.key,
    required this.onHashtagsChanged,
    this.initialHashtags = const [],
  });

  @override
  State<HashtagTextInputFormatter> createState() =>
      _HashtagTextInputFormatterState();
}

class _HashtagTextInputFormatterState extends State<HashtagTextInputFormatter> {
  List<String> _selectedHashtags = [];
  List<Category> _availableCategories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedHashtags = List.from(widget.initialHashtags);
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await CategoryService.getAllCategories();
    if (mounted) {
      setState(() {
        _availableCategories = cats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return AnimatedBuilder(
      animation: darkModeNotifier,
      builder: (context, _) {
        final inkColor = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
        final inkMutedColor =
            AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
        final brandColor =
            AppColors.resolve(AppColors.brand, AppDarkColors.brand);
        final cardColor = AppColors.resolve(AppColors.card, AppDarkColors.card);
        final borderColor =
            AppColors.resolve(AppColors.border, AppDarkColors.border);
        final brandSurfaceColor = AppColors.resolve(
            AppColors.brandSurface, AppDarkColors.brandSurface);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MultiSelectDialogField(
              items: _availableCategories
                  .map((c) => MultiSelectItem<String>(c.name, c.name))
                  .toList(),
              title: Text(
                "Sélectionnez des catégories",
                style: AppTypography.headlineLarge(color: inkColor),
              ),
              dialogHeight: 250,
              initialValue: _selectedHashtags,
              onConfirm: (values) {
                setState(() {
                  _selectedHashtags = values.cast<String>();
                  widget.onHashtagsChanged(_selectedHashtags);
                });
              },
              buttonText: Text(
                "Sélectionnez",
                style: AppTypography.labelMedium(color: inkMutedColor),
              ),
              cancelText: Text(
                "Annuler",
                style: AppTypography.labelMedium(color: inkMutedColor),
              ),
              confirmText: Text(
                "Ok",
                style: AppTypography.labelLarge(color: brandColor),
              ),
              itemsTextStyle: AppTypography.bodyLarge(color: inkColor),
              selectedItemsTextStyle:
                  AppTypography.bodyLarge(color: brandColor),
              selectedColor: brandSurfaceColor,
              checkColor: brandColor,
              unselectedColor: borderColor,
              backgroundColor: cardColor,
              chipDisplay: MultiSelectChipDisplay.none(),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: borderColor, width: 1),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: _selectedHashtags.map((hashtag) {
                return Chip(
                  label: Text(
                    hashtag,
                    style: AppTypography.labelMedium(color: brandColor),
                  ),
                  backgroundColor: brandSurfaceColor,
                  deleteIconColor: inkMutedColor,
                  side: BorderSide(color: borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  onDeleted: () {
                    setState(() {
                      _selectedHashtags.remove(hashtag);
                      widget.onHashtagsChanged(_selectedHashtags);
                    });
                  },
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}
