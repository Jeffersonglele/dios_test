import 'dart:io';
import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/utils/image_picker_helper.dart';
import 'package:dios_delices/utils/toast.dart';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class DeliveryProofPage extends StatefulWidget {
  final int orderId;
  final bool requiresCode;
  final String? deliveryCode;

  const DeliveryProofPage({
    super.key,
    required this.orderId,
    this.requiresCode = false,
    this.deliveryCode,
  });

  @override
  State<DeliveryProofPage> createState() => _DeliveryProofPageState();
}

class _DeliveryProofPageState extends State<DeliveryProofPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  File? _photo;
  bool _isLoading = false;

  AppLocalizations get loc => AppLocalizations.of(context)!;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final photo = await pickImageFromCamera(context);
    if (photo != null && mounted) {
      setState(() => _photo = photo);
    }
  }

  Future<void> _submitProof() async {
    if (!_formKey.currentState!.validate()) return;

    if (_photo == null) {
      Toast(context, loc.delivery_proof_photo_required, false);
      return;
    }

    if (widget.requiresCode) {
      if (_codeCtrl.text.length != 4) {
        Toast(context, loc.delivery_proof_invalid_code, false);
        return;
      }
      if (widget.deliveryCode != null && _codeCtrl.text != widget.deliveryCode) {
        Toast(context, loc.delivery_proof_invalid_code, false);
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      // Upload photo to Cloudinary/Parse
      final parseFile = ParseFile(File(_photo!.path), name: 'delivery_proof_${widget.orderId}.jpg');
      final uploadResponse = await parseFile.save();
      if (!uploadResponse.success || uploadResponse.result == null) {
        throw Exception('Échec upload photo');
      }
      final photoUrl = (uploadResponse.result as ParseFile).url!;

      // Call submitDeliveryProof
      final cloudFunction = ParseCloudFunction('submitDeliveryProof');
      final response = await cloudFunction.execute(parameters: {
        'orderId': widget.orderId,
        'photoUrl': photoUrl,
        'latitude': 0.0, // TODO: get from GPS
        'longitude': 0.0,
        'timestamp': DateTime.now().toIso8601String(),
        if (widget.requiresCode) 'deliveryCode': _codeCtrl.text,
      });

      if (mounted) {
        if (response.success && response.result is Map && response.result['success'] == true) {
          Toast(context, AppLocalizations.of(context)!.delivery_proof_submitted, true);
          Navigator.pop(context, true);
        } else {
          Toast(context, response.result?['error'] ?? 'Erreur', false);
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
      appBar: AppBar(title: Text(loc.delivery_proof_title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instruction
              Text(
                loc.delivery_proof_instruction,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[700]),
              ),
              const SizedBox(height: 24),

              // Photo
              Text(loc.delivery_proof_title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _takePhoto,
                child: Container(
                  width: double.infinity,
                  height: 250,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!, width: 2, style: BorderStyle.solid),
                  ),
                  child: _photo != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(_photo!, fit: BoxFit.cover, width: double.infinity, height: 250),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(loc.delivery_proof_take_photo, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                loc.delivery_proof_camera_only,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange[700]),
              ),
              const SizedBox(height: 24),

              // Code de livraison (si requis)
              if (widget.requiresCode) ...[
                Text(loc.delivery_proof_code_label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(letterSpacing: 16),
                  decoration: InputDecoration(
                    hintText: loc.delivery_proof_code_hint,
                    counterText: '',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.length != 4) return 'Code 4 chiffres requis';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  loc.delivery_proof_code_hint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
              ],

              const Spacer(),

              // Bouton confirmer
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitProof,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : Text(loc.delivery_proof_submit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}