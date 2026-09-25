import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/models/category.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/toast.dart';
import 'package:flutter/material.dart';

class CategoryManagementPage extends StatefulWidget {
  const CategoryManagementPage({super.key});

  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  List<Category> _categories = [];
  bool _isLoading = true;
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final cats = await CategoryService.getAllCategories();
    if (mounted) {
      setState(() {
        _categories = cats;
        _isLoading = false;
      });
    }
  }

  Future<void> _add() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      Toast(
          context, AppLocalizations.of(context)!.category_name_required, false);
      return;
    }
    final success = await CategoryService.addCategory(name);
    if (mounted) {
      if (success) {
        _nameCtrl.clear();
        Toast(context, AppLocalizations.of(context)!.category_added, true);
        _load();
      } else {
        Toast(context, AppLocalizations.of(context)!.category_add_error, false);
      }
    }
  }

  Future<void> _delete(Category cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.category_delete_title),
        content: Text(
            AppLocalizations.of(context)!.category_delete_confirm(cat.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context)!.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(AppLocalizations.of(context)!.delete,
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final success = await CategoryService.deleteCategory(cat.categoryID);
    if (mounted) {
      if (success) {
        Toast(context, AppLocalizations.of(context)!.category_deleted, true);
        _load();
      } else {
        Toast(context, AppLocalizations.of(context)!.category_delete_error,
            false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.category_manage_title)),
      body: Column(
        children: [
          // Ajout
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.resolve(AppColors.card, AppDarkColors.card),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                  color:
                      AppColors.resolve(AppColors.border, AppDarkColors.border),
                  width: 0.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.category_new_hint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _add,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(AppLocalizations.of(context)!.category_add),
                ),
              ],
            ),
          ),
          // Liste
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _categories.isEmpty
                    ? Center(
                        child:
                            Text(AppLocalizations.of(context)!.category_empty))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _categories.length,
                          itemBuilder: (_, i) {
                            final c = _categories[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: AppColors.resolve(
                                    AppColors.card, AppDarkColors.card),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                border: Border.all(
                                    color: AppColors.resolve(
                                        AppColors.border, AppDarkColors.border),
                                    width: 0.5),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: ListTile(
                                  title: Text(c.name,
                                      style: AppTypography.labelMedium(
                                          color: AppColors.resolve(
                                              AppColors.ink,
                                              AppDarkColors.ink))),
                                  trailing: IconButton(
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: AppColors.error,
                                        size: 20),
                                    onPressed: () => _delete(c),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
