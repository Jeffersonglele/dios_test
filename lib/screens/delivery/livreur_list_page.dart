import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/services/node_admin_service.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../../widgets/courier_card.dart';
import 'livreur_fiche_page.dart';

/// Statut du dossier livreur renvoyé par GET /admin/couriers.
enum CourierFileStatus { validated, pending, rejected, missing }

CourierFileStatus courierFileStatusOf(Object? raw) {
  switch (raw?.toString()) {
    case 'validated':
      return CourierFileStatus.validated;
    case 'pending':
      return CourierFileStatus.pending;
    case 'rejected':
      return CourierFileStatus.rejected;
    default:
      return CourierFileStatus.missing;
  }
}

/// Pastille de statut du dossier (validé, à valider, refusé, sans dossier).
class CourierFileStatusPill extends StatelessWidget {
  const CourierFileStatusPill({super.key, required this.status});
  final CourierFileStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (Color color, IconData icon, String label) = switch (status) {
      CourierFileStatus.validated => (
          AppColors.resolve(AppColors.success, AppDarkColors.success),
          Icons.verified_rounded,
          l10n.courier_admin_validated
        ),
      CourierFileStatus.pending => (
          AppColors.resolve(AppColors.accent, AppDarkColors.accent),
          Icons.hourglass_top_rounded,
          l10n.courier_admin_to_review
        ),
      CourierFileStatus.rejected => (
          AppColors.resolve(AppColors.error, AppDarkColors.error),
          Icons.block_rounded,
          l10n.courier_admin_rejected
        ),
      CourierFileStatus.missing => (
          AppColors.resolve(AppColors.inkSubtle, AppDarkColors.inkSubtle),
          Icons.description_outlined,
          l10n.courier_admin_no_file
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: AppTypography.labelMedium(color: color)
                .copyWith(fontSize: 11, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

/// Photo du livreur avec la pastille « en ligne ».
class CourierPhotoAvatar extends StatelessWidget {
  const CourierPhotoAvatar({
    super.key,
    required this.photoUrl,
    required this.initials,
    this.online = false,
    this.radius = 26,
  });
  final String? photoUrl;
  final String initials;
  final bool online;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final photo = photoUrl;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: brand.withValues(alpha: 0.12),
          foregroundImage:
              photo == null || photo.isEmpty ? null : NetworkImage(photo),
          child: Text(initials,
              style: AppTypography.titleSmall(color: brand)
                  .copyWith(fontWeight: FontWeight.w800)),
        ),
        if (online)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.5,
              height: radius * 0.5,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(color: card, width: 2.5),
              ),
            ),
          ),
      ],
    );
  }
}

String courierInitials(Map<String, dynamic> c) {
  final letters = [c['firstname'], c['lastname']]
      .map((v) => v?.toString().trim() ?? '')
      .where((v) => v.isNotEmpty)
      .map((v) => v[0].toUpperCase())
      .join();
  return letters.isEmpty ? '?' : letters;
}

String courierName(Map<String, dynamic> c) {
  final name = [c['firstname'], c['lastname']]
      .map((v) => v?.toString().trim() ?? '')
      .where((v) => v.isNotEmpty)
      .join(' ');
  return name.isNotEmpty ? name : (c['username']?.toString() ?? 'Livreur');
}

class LivreurListPage extends StatefulWidget {
  final String? country;
  const LivreurListPage({super.key, this.country});

  @override
  State<LivreurListPage> createState() => _LivreurListPageState();
}

enum _Filter { all, online, toReview, validated, rejected, missing }

class _LivreurListPageState extends State<LivreurListPage> {
  List<Map<String, dynamic>> _couriers = [];
  bool _isLoading = true;
  String? _error;
  String _query = '';
  _Filter _filter = _Filter.all;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final token = await SessionService.readNodeToken();
      if (token == null) throw Exception('session');
      final list =
          await NodeAdminService.getCouriers(token, country: widget.country);
      if (!mounted) return;
      setState(() {
        _couriers = list;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = AppLocalizations.of(context)!.error;
      });
    }
  }

  CourierFileStatus _status(Map<String, dynamic> c) =>
      courierFileStatusOf(c['fileStatus']);

  bool _online(Map<String, dynamic> c) => c['isOnline'] == true;

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    return _couriers.where((c) {
      final matches = switch (_filter) {
        _Filter.all => true,
        _Filter.online => _online(c),
        _Filter.toReview => _status(c) == CourierFileStatus.pending,
        _Filter.validated => _status(c) == CourierFileStatus.validated,
        _Filter.rejected => _status(c) == CourierFileStatus.rejected,
        _Filter.missing => _status(c) == CourierFileStatus.missing,
      };
      if (!matches) return false;
      if (q.isEmpty) return true;
      final haystack = [
        courierName(c),
        c['telephone'],
        c['email'],
        c['vehiclePlate'],
      ].map((v) => v?.toString().toLowerCase() ?? '').join(' ');
      return haystack.contains(q);
    }).toList()
      // Les dossiers à valider en premier.
      ..sort((a, b) {
        final pa = _status(a) == CourierFileStatus.pending ? 0 : 1;
        final pb = _status(b) == CourierFileStatus.pending ? 0 : 1;
        return pa.compareTo(pb);
      });
  }

  int _count(bool Function(Map<String, dynamic>) test) =>
      _couriers.where(test).length;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final surface = AppColors.resolve(AppColors.surface, AppDarkColors.surface);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        backgroundColor: surface,
        title: Text(l10n.livreur_management_title,
            style: AppTypography.titleSmall(color: ink)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      _StatTile(
                        value: _count(_online),
                        label: l10n.livreur_filter_online,
                        color: AppColors.resolve(
                            AppColors.success, AppDarkColors.success),
                      ),
                      const SizedBox(width: 10),
                      _StatTile(
                        value: _count((c) =>
                            _status(c) == CourierFileStatus.pending),
                        label: l10n.courier_admin_to_review,
                        color: AppColors.resolve(
                            AppColors.accent, AppDarkColors.accent),
                        onTap: () =>
                            setState(() => _filter = _Filter.toReview),
                      ),
                      const SizedBox(width: 10),
                      _StatTile(
                        value: _couriers.length,
                        label: l10n.courier_admin_total,
                        color: AppColors.resolve(
                            AppColors.brand, AppDarkColors.brand),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                      style: AppTypography.bodyLarge(color: ink),
                      decoration: InputDecoration(
                        hintText: l10n.livreur_search_hint,
                        hintStyle: AppTypography.bodyMedium(color: muted),
                        prefixIcon:
                            Icon(Icons.search_rounded, color: muted, size: 20),
                        filled: true,
                        fillColor: card,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(color: border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide(
                              color: AppColors.resolve(
                                  AppColors.brand, AppDarkColors.brand)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final f in _Filter.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FilterChip(
                          label: _filterLabel(f, l10n),
                          selected: _filter == f,
                          onTap: () => setState(() => _filter = f),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null || filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        _error != null
                            ? Icons.cloud_off_rounded
                            : Icons.delivery_dining_outlined,
                        size: 56,
                        color: AppColors.resolve(
                            AppColors.inkSubtle, AppDarkColors.inkSubtle)),
                    const SizedBox(height: 10),
                    Text(_error ?? l10n.livreur_no_results,
                        style: AppTypography.bodyLarge(color: muted)),
                  ]),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                sliver: SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _CourierTile(
                    courier: filtered[i],
                    onTap: () async {
                      final id =
                          int.tryParse('${filtered[i]['userId']}') ?? 0;
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => LivreurFichePage(userID: id)),
                      );
                      if (mounted) _load();
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _filterLabel(_Filter f, AppLocalizations l10n) => switch (f) {
        _Filter.all => l10n.all,
        _Filter.online => l10n.livreur_filter_online,
        _Filter.toReview => l10n.courier_admin_to_review,
        _Filter.validated => l10n.courier_admin_validated,
        _Filter.rejected => l10n.courier_admin_rejected,
        _Filter.missing => l10n.courier_admin_no_file,
      };
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
    this.onTap,
  });
  final int value;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    return Expanded(
      child: Material(
        color: card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: border, width: 0.6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$value',
                    style: AppTypography.headlineMedium(color: color)
                        .copyWith(fontSize: 24)),
                const SizedBox(height: 2),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall(color: muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? brand : card,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? brand : border, width: 0.6),
        ),
        child: Text(label,
            style: AppTypography.labelMedium(
                    color: selected ? Colors.white : muted)
                .copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
      ),
    );
  }
}

class _CourierTile extends StatelessWidget {
  const _CourierTile({required this.courier, required this.onTap});
  final Map<String, dynamic> courier;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final card = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final border = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);
    final accent = AppColors.resolve(AppColors.accent, AppDarkColors.accent);
    final status = courierFileStatusOf(courier['fileStatus']);
    final vehicle = courier['vehicleType']?.toString();
    final plate = courier['vehiclePlate']?.toString() ?? '';
    final phone = courier['telephone']?.toString() ?? '';
    final online = courier['isOnline'] == true;
    final busy = courier['isBusy'] == true;

    return Material(
      color: card,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: status == CourierFileStatus.pending
                  ? accent.withValues(alpha: 0.6)
                  : border,
              width: status == CourierFileStatus.pending ? 1.2 : 0.6,
            ),
          ),
          child: Row(
            children: [
              CourierPhotoAvatar(
                photoUrl: courier['image']?.toString(),
                initials: courierInitials(courier),
                online: online,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(courierName(courier),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleSmall(color: ink)
                            .copyWith(fontWeight: FontWeight.w700)),
                    if (phone.isNotEmpty)
                      Text(phone,
                          style: AppTypography.bodySmall(color: muted)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(courierVehicleIcon(vehicle),
                              size: 15, color: muted),
                          const SizedBox(width: 4),
                          Text(courierVehicleLabel(vehicle, l10n),
                              style: AppTypography.bodySmall(color: muted)),
                        ]),
                        if (plate.isNotEmpty) VehiclePlateBadge(plate: plate),
                        if (busy)
                          Text(l10n.courier_admin_busy,
                              style: AppTypography.labelMedium(color: accent)
                                  .copyWith(fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CourierFileStatusPill(status: status),
                  const SizedBox(height: 8),
                  Icon(Icons.chevron_right_rounded, color: muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
