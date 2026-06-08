import 'package:dios_delices/models/category.dart';
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

class _HashtagTextInputFormatterState
    extends State<HashtagTextInputFormatter> {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MultiSelectDialogField(
          items: _availableCategories
              .map((c) => MultiSelectItem<String>(c.name, c.name))
              .toList(),
          title: const Text(
            "Sélectionnez des catégories",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          dialogHeight: 250,
          initialValue: _selectedHashtags,
          onConfirm: (values) {
            setState(() {
              _selectedHashtags = values.cast<String>();
              widget.onHashtagsChanged(_selectedHashtags);
            });
          },
          buttonText: Text("Sélectionnez"),
          cancelText: Text("Annuler"),
          chipDisplay: MultiSelectChipDisplay.none(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey, width: 1),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8.0,
          children: _selectedHashtags.map((hashtag) {
            return Chip(
              label: Text(hashtag),
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
  }
}
