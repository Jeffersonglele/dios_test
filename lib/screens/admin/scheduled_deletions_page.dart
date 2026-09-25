import 'package:dios_delices/l10n/app_localizations.dart';
import 'package:dios_delices/models/users.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/utils/toast.dart';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class ScheduledDeletionsPage extends StatefulWidget {
  final String country;
  const ScheduledDeletionsPage({super.key, required this.country});

  @override
  State<ScheduledDeletionsPage> createState() => _ScheduledDeletionsPageState();
}

class _ScheduledDeletionsPageState extends State<ScheduledDeletionsPage> {
  List<_ScheduledUser> _items = [];
  bool _loading = true;

  static const int _deletionPeriodDays = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final fn = ParseCloudFunction('getScheduledDeletions');
      final response = await fn.execute(parameters: {
        'country': widget.country,
      });
      if (response.success && response.result != null) {
        final list = response.result as List<dynamic>;
        if (mounted) {
          setState(() {
            _items = list.map((e) {
              final map = e as Map<String, dynamic>;
              final user = Users.fromMap(map);
              final deletedAt = map['deletedAt'] != null
                  ? (map['deletedAt'] is String
                      ? DateTime.tryParse(map['deletedAt'])
                      : (map['deletedAt']['iso'] != null
                          ? DateTime.tryParse(map['deletedAt']['iso'])
                          : null))
                  : DateTime.now();
              return _ScheduledUser(
                  user: user, deletedAt: deletedAt ?? DateTime.now());
            }).toList();
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      final all = await Users.fetchUsersFromDB();
      final pending = all
          .where((u) =>
              u.country == widget.country && u.status == 'deleted_pending')
          .toList();
      if (mounted) {
        setState(() {
          _items = pending
              .map((u) => _ScheduledUser(user: u, deletedAt: DateTime.now()))
              .toList();
          _loading = false;
        });
      }
    }
  }

  Future<void> _restore(Users user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text(
            AppLocalizations.of(context)!.scheduled_deletions_restore_title,
            style: AppTypography.titleMedium()),
        content: Text(AppLocalizations.of(context)!
            .scheduled_deletions_restore_confirm(
                user.firstname, user.lastname)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context)!.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: Text(
                AppLocalizations.of(context)!.scheduled_deletions_restore,
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await Users.updateStatus(user.userID, 'active');
    if (!mounted) return;
    if (result == 'success') {
      Toast(
          context,
          AppLocalizations.of(context)!
              .scheduled_deletions_restored(user.firstname, user.lastname),
          true);
      _load();
    } else {
      Toast(context, 'Erreur : $result', false);
    }
  }

  Future<void> _permanentDelete(Users user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text(
            AppLocalizations.of(context)!.scheduled_deletions_permanent_title,
            style: AppTypography.titleMedium()),
        content: Text(AppLocalizations.of(context)!
            .scheduled_deletions_permanent_confirm(
                user.firstname, user.lastname)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context)!.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(
                AppLocalizations.of(context)!
                    .scheduled_deletions_permanent_delete,
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await Users.permanentlyDeleteUser(user.userID);
    if (!mounted) return;
    if (result == 'success') {
      Toast(
          context,
          AppLocalizations.of(context)!
              .scheduled_deletions_deleted(user.firstname, user.lastname),
          false);
      _load();
    } else {
      Toast(context, 'Erreur : $result', false);
    }
  }

  String _roleLabel(int id) => [
        '',
        'Admin',
        'Client',
        'Restaurateur',
        'Super Admin',
        'Livreur'
      ][id >= 0 && id <= 5 ? id : 0];

  @override
  Widget build(BuildContext context) {
    final surface = AppColors.resolve(AppColors.surface, AppDarkColors.surface);
    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.scheduled_deletions_title,
            style: AppTypography.titleMedium(
                color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
      ),
      body: RefreshIndicator(
        color: AppColors.brand,
        backgroundColor: AppColors.resolve(AppColors.card, AppDarkColors.card),
        onRefresh: _load,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.brand))
            : _items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline_rounded,
                                  size: 64,
                                  color: AppColors.resolve(AppColors.success,
                                      AppDarkColors.success)),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                  AppLocalizations.of(context)!
                                      .scheduled_deletions_empty,
                                  style: AppTypography.titleMedium(
                                      color: AppColors.resolve(
                                          AppColors.ink, AppDarkColors.ink))),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                  AppLocalizations.of(context)!
                                      .scheduled_deletions_all_active(
                                          widget.country),
                                  style: AppTypography.bodyMedium(
                                      color: AppColors.resolve(
                                          AppColors.ink, AppDarkColors.ink))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      _StatsHeader(
                          count: _items.length, country: widget.country),
                      const SizedBox(height: AppSpacing.md),
                      ..._items.map((item) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _DeletionCard(
                              item: item,
                              roleLabel: _roleLabel(item.user.roleID),
                              onRestore: () => _restore(item.user),
                              onPermanentDelete: () =>
                                  _permanentDelete(item.user),
                            ),
                          )),
                    ],
                  ),
      ),
    );
  }
}

class _ScheduledUser {
  final Users user;
  final DateTime deletedAt;

  _ScheduledUser({required this.user, required this.deletedAt});
}

class _StatsHeader extends StatelessWidget {
  final int count;
  final String country;
  const _StatsHeader({required this.count, required this.country});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandLight, AppColors.brand],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.schedule_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    AppLocalizations.of(context)!
                        .scheduled_deletions_pending('$count'),
                    style: AppTypography.titleSmall(
                            color: AppColors.resolve(
                                AppColors.ink, AppDarkColors.ink))
                        .copyWith(fontSize: 15)),
                Text(country,
                    style: AppTypography.bodySmall(
                            color: AppColors.resolve(
                                AppColors.ink, AppDarkColors.ink))
                        .copyWith(fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
                AppLocalizations.of(context)!.scheduled_deletions_period(
                    '${_DeletionCard.deletionPeriodDays}'),
                style: AppTypography.labelMedium(
                        color:
                            AppColors.resolve(AppColors.ink, AppDarkColors.ink))
                    .copyWith(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

class _DeletionCard extends StatelessWidget {
  final _ScheduledUser item;
  final String roleLabel;
  final VoidCallback onRestore;
  final VoidCallback onPermanentDelete;

  static const int deletionPeriodDays = 30;

  const _DeletionCard({
    required this.item,
    required this.roleLabel,
    required this.onRestore,
    required this.onPermanentDelete,
  });

  int get _daysElapsed {
    final diff = DateTime.now().difference(item.deletedAt);
    return diff.inDays.clamp(0, deletionPeriodDays);
  }

  int get _daysRemaining => deletionPeriodDays - _daysElapsed;

  double get _progress => (_daysElapsed / deletionPeriodDays).clamp(0.0, 1.0);

  Color get _progressColor {
    if (_daysRemaining > 20) return AppColors.success;
    if (_daysRemaining > 10) return AppColors.accent;
    return AppColors.error;
  }

  Color get _progressBgColor {
    return AppColors.resolve(AppColors.border, AppDarkColors.border);
  }

  @override
  Widget build(BuildContext context) {
    final user = item.user;
    final cardBg = AppColors.resolve(AppColors.card, AppDarkColors.card);
    final ink = AppColors.resolve(AppColors.ink, AppDarkColors.ink);
    final inkMuted =
        AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.resolve(AppColors.border, AppDarkColors.border),
          width: 0.5,
        ),
        boxShadow: AppShadows.cardList,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row: avatar + name/email + role badge ──
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.resolve(
                    AppColors.brandSurface, AppDarkColors.brandSurface),
                child: Text(
                  user.firstname.isNotEmpty
                      ? user.firstname[0].toUpperCase()
                      : '?',
                  style: AppTypography.titleMedium(color: AppColors.brand)
                      .copyWith(fontSize: 18),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${user.firstname} ${user.lastname}',
                        style: AppTypography.bodyLarge(color: ink)
                            .copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(user.email,
                        style: AppTypography.bodySmall(color: inkMuted)
                            .copyWith(fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              // Role badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.resolve(
                      AppColors.brandSurface, AppDarkColors.brandSurface),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(roleLabel,
                    style: AppTypography.labelMedium(color: AppColors.brand)
                        .copyWith(fontSize: 10)),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Date + J-XX chip ──
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 14, color: inkMuted),
              const SizedBox(width: 6),
              Text(
                  AppLocalizations.of(context)!
                      .scheduled_deletions_requested_on(
                          _formatDate(item.deletedAt)),
                  style: AppTypography.bodySmall(color: inkMuted)
                      .copyWith(fontSize: 12)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _progressColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: _progressColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_outlined, size: 14, color: _progressColor),
                    const SizedBox(width: 4),
                    Text(
                      _daysRemaining > 0
                          ? 'J-$_daysRemaining'
                          : AppLocalizations.of(context)!
                              .scheduled_deletions_last_day,
                      style: AppTypography.labelMedium(color: _progressColor)
                          .copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Progress bar ──
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: _progressBgColor,
              valueColor: AlwaysStoppedAnimation(_progressColor),
              minHeight: 6,
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Progress text ──
          Row(
            children: [
              Text(
                AppLocalizations.of(context)!
                    .scheduled_deletions_days_elapsed('$_daysElapsed'),
                style: AppTypography.bodySmall(color: inkMuted)
                    .copyWith(fontSize: 11),
              ),
              const Spacer(),
              Text(
                AppLocalizations.of(context)!
                    .scheduled_deletions_days_remaining('$_daysRemaining'),
                style: AppTypography.bodySmall(
                        color: _daysRemaining <= 5 ? AppColors.error : inkMuted)
                    .copyWith(fontSize: 11),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),

          // ── Action buttons ──
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: onRestore,
                    icon: const Icon(Icons.restore_rounded, size: 18),
                    label: Text(
                        AppLocalizations.of(context)!
                            .scheduled_deletions_restore,
                        style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.success,
                      side: BorderSide(
                          color: AppColors.success.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: onPermanentDelete,
                    icon: const Icon(Icons.delete_forever_rounded, size: 18),
                    label: Text(
                        AppLocalizations.of(context)!
                            .scheduled_deletions_permanent_delete,
                        style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}
