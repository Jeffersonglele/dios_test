import 'dart:io';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/models/dispute.dart';
import 'package:dios_delices/utils/image_picker_helper.dart';
import 'package:dios_delices/utils/toast.dart';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class OpenDisputePage extends StatefulWidget {
  final int orderId;
  const OpenDisputePage({super.key, required this.orderId});

  @override
  State<OpenDisputePage> createState() => _OpenDisputePageState();
}

class _OpenDisputePageState extends State<OpenDisputePage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionCtrl = TextEditingController();
  String _selectedType = 'missing_item';
  final List<File> _photos = [];
  bool _isLoading = false;

  static const List<Map<String, String>> _disputeTypes = [
    {'value': 'missing_item', 'label': 'Produit manquant'},
    {'value': 'not_delivered', 'label': 'Non livré'},
    {'value': 'bad_quality', 'label': 'Mauvaise qualité'},
    {'value': 'other', 'label': 'Autre'},
  ];

  Future<void> _pickPhoto() async {
    if (_photos.length >= 5) {
      Toast(context, AppLocalizations.of(context)!.dispute_max_photos, false);
      return;
    }
    final photo = await pickImageFromCamera(context);
    if (photo != null && mounted) {
      setState(() => _photos.add(photo));
    }
  }

  Future<void> _submitDispute() async {
    if (!_formKey.currentState!.validate()) return;

    if (['missing_item', 'not_delivered'].contains(_selectedType) && _photos.isEmpty) {
      Toast(context, AppLocalizations.of(context)!.dispute_photo_required, false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload photos
      final photoUrls = <String>[];
      for (final photo in _photos) {
        final parseFile = ParseFile(File(photo.path), name: 'dispute_${widget.orderId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        final uploadResponse = await parseFile.save();
        if (uploadResponse.success && uploadResponse.result != null) {
          photoUrls.add((uploadResponse.result as ParseFile).url!);
        }
      }

      // Call openDispute
      final cloudFunction = ParseCloudFunction('openDispute');
      final response = await cloudFunction.execute(parameters: {
        'orderId': widget.orderId,
        'type': _selectedType,
        'description': _descriptionCtrl.text.trim(),
        'photoUrls': photoUrls,
      });

      if (mounted) {
        if (response.success && response.result is Map && response.result['success'] == true) {
          Toast(context, AppLocalizations.of(context)!.dispute_submitted, true);
          Navigator.pop(context, true);
        } else {
          Toast(context, response.result?['error'] ?? AppLocalizations.of(context)!.dispute_submit_error, false);
        }
      }
    } catch (e) {
      if (mounted) Toast(context, 'Erreur: $e', false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.dispute_title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info
              Text(
                loc.dispute_subtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[700]),
              ),
              const SizedBox(height: 24),

              // Type
              Text(loc.dispute_type_label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: _disputeTypes.map((type) => DropdownMenuItem(
                  value: type['value'],
                  child: Text(type['label']!),
                )).toList(),
                onChanged: (v) => setState(() => _selectedType = v!),
                validator: (v) => v == null ? 'Sélectionnez un type' : null,
              ),
              const SizedBox(height: 24),

              // Description
              Text(loc.dispute_description_label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: loc.dispute_description_hint,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return loc.dispute_description_required;
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Photos
              Text(loc.dispute_photo_label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              if (['missing_item', 'not_delivered'].contains(_selectedType))
                Text(loc.dispute_photo_required, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red[700])),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ..._photos.map((photo) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(photo, width: 100, height: 100, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 4, right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _photos.remove(photo)),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  )).toList(),
                  if (_photos.length < 5)
                    GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!, width: 2, style: BorderStyle.solid),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, size: 32, color: Colors.grey[400]),
                            const SizedBox(height: 4),
                            Text('Ajouter', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              if (_photos.isNotEmpty) const SizedBox(height: 8),
              if (['missing_item', 'not_delivered'].contains(_selectedType) && _photos.isEmpty)
                Text(loc.dispute_photo_required, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red[700])),
              const SizedBox(height: 24),

              const Spacer(),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitDispute,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : Text(AppLocalizations.of(context)!.dispute_submit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}