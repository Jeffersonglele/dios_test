import 'package:flutter/material.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';

class HashtagTextInputFormatter extends StatefulWidget {
  final Function(List<String>) onHashtagsChanged;
  final List<String> initialHashtags;

  HashtagTextInputFormatter({
    required this.onHashtagsChanged,
    this.initialHashtags = const [],
  });

  @override
  _HashtagTextInputFormatterState createState() => _HashtagTextInputFormatterState();
}

class _HashtagTextInputFormatterState extends State<HashtagTextInputFormatter> {
  List<String> _selectedHashtags = [];
  final List<String> _availableHashtags = [
    '#crepes', '#africain', '#japonais', '#beignets', '#bubble tea', '#jus',
    '#vegan', '#salade', '#pizza', '#burger', '#dessert', '#healthy', '#soup',
  ];

  @override
  void initState() {
    super.initState();
    _selectedHashtags = List.from(widget.initialHashtags);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MultiSelectDialogField(
          items: _availableHashtags
              .map((hashtag) => MultiSelectItem<String>(hashtag, hashtag))
              .toList(),
          title: const Text(
            "Sélectionnez des hashtags",
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
          cancelText: Text("Annuler"), // Optional: Customize cancel button text
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
