import 'package:flutter/material.dart';

class HashtagTextInputFormatter extends StatefulWidget {
  final Function(List<String>) onHashtagsChanged; // Callback pour notifier les hashtags sélectionnés

  HashtagTextInputFormatter({required this.onHashtagsChanged});

  @override
  _HashtagTextInputFormatterState createState() => _HashtagTextInputFormatterState();
}

class _HashtagTextInputFormatterState extends State<HashtagTextInputFormatter> {
  final TextEditingController _hashtagController = TextEditingController();
  List<String> _selectedHashtags = [];

  final List<String> _availableHashtags = [
    '#crepes', '#africain', '#japonais', '#beignets', '#bubble tea', '#jus',
    '#vegan', '#salade', '#pizza', '#burger', '#dessert', '#healthy', '#soup',
  ];

  @override
  void dispose() {
    _hashtagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _hashtagController,
          readOnly: true,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.tag),
            hintText: 'Sélectionnez des hashtags',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          ),
          onTap: _showHashtagSelectionDialog,
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 8.0,
          children: _selectedHashtags.map((hashtag) {
            return Chip(
              label: Text(hashtag),
              deleteIcon: Icon(Icons.cancel),
              onDeleted: () {
                setState(() {
                  _selectedHashtags.remove(hashtag);
                  _updateHashtagController();
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  void _updateHashtagController() {
    _hashtagController.text = _selectedHashtags.join(' ');
    widget.onHashtagsChanged(_selectedHashtags); // Appelle le callback pour notifier le parent
  }

  void _showHashtagSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sélectionnez des hashtags'),
          content: Container(
            width: double.maxFinite,
            height: 300.0,
            child: SingleChildScrollView(
              child: Column(
                children: _availableHashtags.map((hashtag) {
                  return CheckboxListTile(
                    title: Text(hashtag),
                    value: _selectedHashtags.contains(hashtag),
                    onChanged: (bool? selected) {
                      setState(() {
                        if (selected == true) {
                          if (!_selectedHashtags.contains(hashtag)) {
                            _selectedHashtags.add(hashtag);
                          }
                        } else {
                          _selectedHashtags.remove(hashtag);
                        }
                        _updateHashtagController();
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              child: Text('Fermer'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
