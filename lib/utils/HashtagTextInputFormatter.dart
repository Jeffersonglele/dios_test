import 'package:flutter/material.dart';

class HashtagTextInputFormatter extends StatefulWidget {
  @override
  _HashtagTextInputFormatterState createState() => _HashtagTextInputFormatterState();
}

class _HashtagTextInputFormatterState extends State<HashtagTextInputFormatter> {
  final TextEditingController _hashtagController = TextEditingController();
  List<String> _selectedHashtags = [];

  // Liste de hashtags disponibles pour la suggestion
  final List<String> _availableHashtags = [
    '#crepes',
    '#africain',
    '#japonais',
    '#beignets',
    '#bubble tea',
    '#jus',
    '#vegan',
    '#salade',
    '#pizza',
    '#burger',
    '#dessert',
    '#healthy',
    '#soup',
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
        // TextFormField pour afficher les hashtags sélectionnés
        TextFormField(
          controller: _hashtagController,
          readOnly: true,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.tag),
            hintText: 'Sélectionnez des hashtags',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          ),
          onTap: () {
            _showHashtagSelectionDialog();
          },
        ),
        const SizedBox(height: 5),
        // Afficher les hashtags sélectionnés sous forme de chips
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

  // Mettre à jour le contenu du TextFormField avec les hashtags sélectionnés
  void _updateHashtagController() {
    _hashtagController.text = _selectedHashtags.join(' ');
  }

  // Ouvrir une boîte de dialogue pour sélectionner des hashtags
  void _showHashtagSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sélectionnez des hashtags'),
          content: Container(
            // Limite la hauteur de la liste à 300 pixels pour permettre le défilement
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
