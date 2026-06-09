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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GestureDetector(
        onTap: widget.onTap ??
            () => showSearch(
                  context: context,
                  delegate: CustomSearchDelegate(),
                ),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(
                Icons.search_rounded,
                color: AppColors.inkMuted,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.search_input_hint,
                  style: AppTypography.bodyLarge(color: AppColors.inkSubtle),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brandSurface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: AppColors.brand,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }
}
