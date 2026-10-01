import 'package:flutter/material.dart';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/screens/search/custom_search_delegate.dart';
import 'package:dios_delices/theme/app_theme.dart';

class SearchInput extends StatefulWidget {
  const SearchInput({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  State<SearchInput> createState() => _SearchInputState();
}

class _SearchInputState extends State<SearchInput> {
  @override
  Widget build(BuildContext context) {
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final inkSubtle =
        AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GestureDetector(
        onTap: widget.onTap ??
            () => showSearch(
                  context: context,
                  delegate: CustomSearchDelegate(),
                ),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: inkMuted, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.search_input_hint,
                  style: AppTypography.bodyLarge(color: inkSubtle),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
