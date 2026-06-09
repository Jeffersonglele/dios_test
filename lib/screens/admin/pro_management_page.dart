import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/toast.dart';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ProManagementPage extends StatefulWidget {
  final String? country;
  const ProManagementPage({super.key, this.country});

  @override
  State<ProManagementPage> createState() => _ProManagementPageState();
}

class _ProManagementPageState extends State<ProManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allDocs = [];
  bool _loading = true;

  static const _statusPending = 'pending';
  static const _statusValidated = 'validated';
  static const _statusRejected = 'rejected';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetch();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final fn = ParseCloudFunction('getAllProDocuments');
      final res = await fn.execute(parameters: {
        if (widget.country != null && widget.country!.isNotEmpty)
          'country': widget.country,
      });
      if (res.success && mounted) {
        setState(() {
          _allDocs = List<Map<String, dynamic>>.from(res.result ?? []);
          _loading = false;
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _filtered(String status) {
    return _allDocs.where((d) => d['status'] == status).toList();
  }

  Future<void> _validate(Map<String, dynamic> doc) async {
    final l10n = AppLocalizations.of(context)!;
    final remarkController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.admin_pro_validate),
        content: TextField(
          controller: remarkController,
          decoration: InputDecoration(
            hintText: '${l10n.admin_pro_remark_hint} (${l10n.optional})',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brand, foregroundColor: Colors.white),
            child: Text(l10n.admin_pro_validate),
          ),
        ],
      ),
    );
    remarkController.dispose();
    if (ok != true || !mounted) return;

    try {
      final fn = ParseCloudFunction('validateRestaurantProDocuments');
      final res = await fn.execute(parameters: {
        'userID': doc['userID'],
        'valid': true,
        if (remarkController.text.trim().isNotEmpty) 'remark': remarkController.text.trim(),
      });
      if (res.success && mounted) {
        Toast(context, l10n.admin_pro_validated(doc['userName'] ?? ''), true);
        _fetch();
      }
    } catch (e) {
      if (mounted) Toast(context, '$e', false);
    }
  }

  Future<void> _reject(Map<String, dynamic> doc) async {
    final l10n = AppLocalizations.of(context)!;
    final remarkController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.admin_pro_reject),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: remarkController,
            validator: (v) => (v == null || v.trim().isEmpty) ? l10n.required : null,
            decoration: InputDecoration(hintText: l10n.admin_pro_remark_hint),
            maxLines: 2,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: Text(l10n.admin_pro_reject),
          ),
        ],
      ),
    );
    remarkController.dispose();
    if (ok != true || !mounted) return;

    try {
      final fn = ParseCloudFunction('validateRestaurantProDocuments');
      final res = await fn.execute(parameters: {
        'userID': doc['userID'],
        'valid': false,
        'remark': remarkController.text.trim(),
      });
      if (res.success && mounted) {
        Toast(context, l10n.admin_pro_rejected(doc['userName'] ?? ''), true);
        _fetch();
      }
    } catch (e) {
      if (mounted) Toast(context, '$e', false);
    }
  }

  Widget _buildCard(Map<String, dynamic> doc) {
    final l10n = AppLocalizations.of(context)!;
    final status = doc['status'] ?? '';
    final hasDocs = (doc['pieceIdentiteUrl'] as String?)?.isNotEmpty == true ||
        (doc['kbisUrl'] as String?)?.isNotEmpty == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.resolve(AppColors.card, AppDarkColors.card),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doc['userName'] ?? '', style: AppTypography.titleMedium()),
                    if ((doc['restaurantName'] as String?)?.isNotEmpty == true)
                      Text(doc['restaurantName'] ?? '', style: AppTypography.bodyMedium(color: AppColors.inkMuted)),
                  ],
                ),
              ),
              _StatusBadge(status: status, l10n: l10n),
            ],
          ),
          const SizedBox(height: 8),
          if ((doc['description'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(l10n.admin_pro_description, style: AppTypography.labelMedium()),
            const SizedBox(height: 2),
            Text(doc['description'] ?? '', style: AppTypography.bodyMedium(color: AppColors.inkMuted), maxLines: 4, overflow: TextOverflow.ellipsis),
          ],
          if (hasDocs) ...[
            const SizedBox(height: 10),
            Text(l10n.admin_pro_documents, style: AppTypography.labelMedium()),
            const SizedBox(height: 4),
            Row(
              children: [
                if ((doc['pieceIdentiteUrl'] as String?)?.isNotEmpty == true)
                  _DocLink(label: 'ID', url: doc['pieceIdentiteUrl']),
                if ((doc['kbisUrl'] as String?)?.isNotEmpty == true)
                  _DocLink(label: 'KBIS', url: doc['kbisUrl']),
                if ((doc['siretUrl'] as String?)?.isNotEmpty == true)
                  _DocLink(label: 'SIRET', url: doc['siretUrl']),
              ],
            ),
          ],
          if (status == _statusPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reject(doc),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: Text(l10n.admin_pro_reject),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _validate(doc),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(l10n.admin_pro_validate),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pending = _filtered(_statusPending).length;
    final validated = _filtered(_statusValidated).length;
    final rejected = _filtered(_statusRejected).length;

    return Scaffold(
      backgroundColor: AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      appBar: AppBar(
        title: Text(l10n.admin_pro_requests, style: AppTypography.titleSmall()),
        backgroundColor: AppColors.resolve(AppColors.surface, AppDarkColors.surface),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.brand,
          unselectedLabelColor: AppColors.inkMuted,
          indicatorColor: AppColors.brand,
          tabs: [
            Tab(text: '${l10n.admin_pro_requests_pending} ($pending)'),
            Tab(text: '${l10n.admin_pro_requests_validated} ($validated)'),
            Tab(text: '${l10n.admin_pro_requests_rejected} ($rejected)'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
          : RefreshIndicator(
              onRefresh: _fetch,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildList(_filtered(_statusPending), l10n),
                  _buildList(_filtered(_statusValidated), l10n),
                  _buildList(_filtered(_statusRejected), l10n),
                ],
              ),
            ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> docs, AppLocalizations l10n) {
    if (docs.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Center(child: Text(l10n.admin_pro_no_requests, style: AppTypography.bodyLarge(color: AppColors.inkMuted))),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (_, i) => _buildCard(docs[i]),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final AppLocalizations l10n;
  const _StatusBadge({required this.status, required this.l10n});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case 'validated':
        bg = AppColors.successLight;
        fg = AppColors.success;
        label = l10n.admin_pro_status_validated;
        break;
      case 'rejected':
        bg = AppColors.errorLight;
        fg = AppColors.error;
        label = l10n.admin_pro_status_rejected;
        break;
      default:
        bg = AppColors.accentLight;
        fg = AppColors.accent;
        label = l10n.admin_pro_status_pending;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(label, style: AppTypography.labelMedium(color: fg)),
    );
  }
}

class _DocLink extends StatelessWidget {
  final String label;
  final String url;
  const _DocLink({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.brandSurface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.brand),
              const SizedBox(width: 4),
              Text(l10n.admin_pro_view_document, style: AppTypography.labelMedium(color: AppColors.brand)),
              const SizedBox(width: 2),
              Text(label, style: AppTypography.labelMedium(color: AppColors.brand)),
            ],
          ),
        ),
      ),
    );
  }
}
