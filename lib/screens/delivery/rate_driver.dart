import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:dios_delices/utils/toast.dart';

class RateDriverPage extends StatefulWidget {
  final int orderId;
  final int driverId;
  final String driverName;

  const RateDriverPage({
    super.key,
    required this.orderId,
    required this.driverId,
    required this.driverName,
  });

  @override
  State<RateDriverPage> createState() => _RateDriverPageState();
}

class _RateDriverPageState extends State<RateDriverPage> {
  int _selectedRating = 0;
  final _commentCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_selectedRating == 0) {
      Toast(context, AppLocalizations.of(context)!.driver_rating_hint, false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cloudFunction = ParseCloudFunction('rateDriver');
      final response = await cloudFunction.execute(parameters: {
        'orderId': widget.orderId,
        'score': _selectedRating,
        'comment': _commentCtrl.text.trim(),
      });

      if (mounted) {
        if (response.success && response.result is Map && response.result['success'] == true) {
          Toast(context, AppLocalizations.of(context)!.driver_rating_thanks, true);
          Navigator.pop(context, true);
        } else {
          Toast(context, response.result?['error'] ?? AppLocalizations.of(context)!.error_generic, false);
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
      appBar: AppBar(title: Text(loc.driver_rating_title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info livreur
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        widget.driverName.isNotEmpty ? widget.driverName[0].toUpperCase() : 'L',
                        style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.driverName,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(loc.driver_rating_hint, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Note
            Text(loc.driver_rating_label, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final star = index + 1;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedRating = star),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        star <= _selectedRating ? Icons.star : Icons.star_border,
                        size: 48,
                        color: star <= _selectedRating ? Colors.amber : Colors.grey[300],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Commentaire
            Text(loc.driver_rating_comment_hint, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _commentCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: loc.driver_rating_comment_hint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc.driver_rating_hint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const Spacer(),

            // Bouton envoyer
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRating,
                child: _isLoading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                      )
                    : Text(loc.driver_rating_submit),
              ),
            ),
          ],
        ),
      ),
    );
  }
}