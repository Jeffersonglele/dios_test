import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/models/dispute.dart';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class MyDisputesPage extends StatefulWidget {
  const MyDisputesPage({super.key});

  @override
  State<MyDisputesPage> createState() => _MyDisputesPageState();
}

class _MyDisputesPageState extends State<MyDisputesPage> {
  List<Dispute> _disputes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDisputes();
  }

  Future<void> _loadDisputes() async {
    setState(() => _isLoading = true);
    try {
      final cloudFunction = ParseCloudFunction('getMyDisputes');
      final response = await cloudFunction.execute();
      if (response.success && response.result is List) {
        final data = response.result as List;
        setState(() {
          _disputes = data.map((e) => Dispute.fromMap(e as Map<String, dynamic>)).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'open':
        return AppLocalizations.of(context)!.dispute_status_open;
      case 'resolved_client':
        return AppLocalizations.of(context)!.dispute_status_resolved_client;
      case 'resolved_restaurant':
        return AppLocalizations.of(context)!.dispute_status_resolved_restaurant;
      case 'resolved_driver':
        return AppLocalizations.of(context)!.dispute_status_resolved_driver;
      case 'rejected':
        return AppLocalizations.of(context)!.dispute_status_rejected;
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.orange;
      case 'resolved_client':
        return Colors.green;
      case 'resolved_restaurant':
      case 'resolved_driver':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'missing_item':
        return AppLocalizations.of(context)!.dispute_type_missing;
      case 'not_delivered':
        return AppLocalizations.of(context)!.dispute_type_not_delivered;
      case 'bad_quality':
        return AppLocalizations.of(context)!.dispute_type_bad_quality;
      case 'other':
        return AppLocalizations.of(context)!.dispute_type_other;
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.dispute_my_disputes)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _disputes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.gavel, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(loc.dispute_no_disputes, style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _disputes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final dispute = _disputes[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(dispute.status).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _getStatusLabel(dispute.status),
                                    style: TextStyle(
                                      color: _getStatusColor(dispute.status),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '#${dispute.orderId}',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _getTypeLabel(dispute.type),
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              dispute.description,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                            ),
                            if (dispute.photoUrls.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 80,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: dispute.photoUrls.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                                  itemBuilder: (context, index) => ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      dispute.photoUrls[index],
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 80,
                                        height: 80,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.broken_image),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (dispute.resolutionNotes != null && dispute.resolutionNotes!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      loc.dispute_resolution_notes,
                                      style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(dispute.resolutionNotes!),
                                    if (dispute.refundAmount != null && dispute.refundAmount! > 0) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        '${loc.dispute_refund_amount}: ${dispute.refundAmount!.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} CDF',
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Colors.green,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Text(
                              '${loc.dispute_created}: ${dispute.createdAt.toLocal().toString().split('.')[0]}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                            ),
                            if (dispute.resolvedAt != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${loc.dispute_resolved}: ${dispute.resolvedAt!.toLocal().toString().split('.')[0]}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}