import 'package:dios_delices/modeles/commande.dart';
import 'package:dios_delices/modeles/users.dart';
import 'package:dios_delices/providers/data_version_notifier.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class LivreurListPage extends StatefulWidget {
  final String? country;
  const LivreurListPage({super.key, this.country});

  @override
  State<LivreurListPage> createState() => _LivreurListPageState();
}

class _LivreurListPageState extends State<LivreurListPage> {
  List<Users> _livreurs = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterStatus = 'tous';

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    dataVersionNotifier.addListener(_onDataChanged);
    _load();
  }

  @override
  void dispose() {
    dataVersionNotifier.removeListener(_onDataChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final users = await Users.fetchUsersFromDB();
    if (!mounted) return;
    setState(() {
      var livreurs = users.where((u) => u.roleID == 5).toList();
      if (widget.country != null && widget.country!.isNotEmpty) {
        livreurs = livreurs.where((u) => u.country == widget.country).toList();
      }
      _livreurs = livreurs;
      _isLoading = false;
    });
  }

  List<Users> get _filtered {
    var list = _livreurs;
    if (_filterStatus == 'en_ligne') {
      list = list.where((u) => u.isOnline == true).toList();
    } else if (_filterStatus == 'hors_ligne') {
      list = list.where((u) => u.isOnline != true).toList();
    } else if (_filterStatus == 'permis_valide') {
      list = list.where((u) => u.permisVerified == true).toList();
    } else if (_filterStatus == 'permis_en_attente') {
      list = list.where((u) => u.permisVerified != true).toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list.where((u) =>
        '${u.firstname} ${u.lastname}'.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        u.email.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }
    return list;
  }

  IconData _vehicleIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'moto': return Icons.motorcycle_rounded;
      case 'velo': return Icons.pedal_bike_rounded;
      case 'voiture': return Icons.directions_car_rounded;
      default: return Icons.delivery_dining_rounded;
    }
  }

  String _vehicleLabel(String? type) {
    switch (type?.toLowerCase()) {
      case 'moto': return 'Moto';
      case 'velo': return 'Vélo';
      case 'voiture': return 'Voiture';
      default: return 'Non spécifié';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Gestion des livreurs'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: AppTypography.bodyLarge().copyWith(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un livreur...',
                      hintStyle: AppTypography.bodyMedium().copyWith(fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: AppColors.inkSubtle, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: PopupMenuButton<String>(
                  onSelected: (v) => setState(() => _filterStatus = v),
                  offset: const Offset(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.filter_list_rounded,
                        color: AppColors.inkMuted, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      _filterStatus == 'tous' ? 'Tous' :
                      _filterStatus == 'en_ligne' ? 'En ligne' :
                      _filterStatus == 'hors_ligne' ? 'Hors ligne' :
                      _filterStatus == 'permis_valide' ? 'Permis ✓' : 'Permis ?',
                      style: AppTypography.labelMedium().copyWith(fontSize: 12),
                    ),
                  ]),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'tous', child: Text('Tous')),
                    PopupMenuItem(value: 'en_ligne', child: Text('En ligne')),
                    PopupMenuItem(value: 'hors_ligne', child: Text('Hors ligne')),
                    PopupMenuItem(value: 'permis_valide', child: Text('Permis validé')),
                    PopupMenuItem(value: 'permis_en_attente', child: Text('Permis en attente')),
                  ],
                ),
              ),
            ]),
          ),
          // Stats header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              Text('${filtered.length} livreur(s)',
                  style: AppTypography.bodyMedium().copyWith(fontSize: 12)),
              const Spacer(),
              Text('${_livreurs.where((u) => u.isOnline == true).length} en ligne',
                  style: AppTypography.labelMedium(color: AppColors.success).copyWith(fontSize: 11)),
            ]),
          ),
          const SizedBox(height: 4),
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delivery_dining_outlined,
                                size: 64, color: AppColors.inkSubtle),
                            const SizedBox(height: 12),
                            Text('Aucun livreur trouvé',
                                style: AppTypography.bodyLarge(color: AppColors.inkMuted)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _buildLivreurCard(filtered[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivreurCard(Users livreur) {
    final isOnline = livreur.isOnline == true;
    final permisOk = livreur.permisVerified == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: AppShadows.cardList,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              // Avatar
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: AppColors.brandSurface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: Icon(_vehicleIcon(livreur.permisType),
                      color: AppColors.brand, size: 26),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${livreur.firstname} ${livreur.lastname}',
                        style: AppTypography.titleMedium().copyWith(fontSize: 15),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(livreur.email,
                        style: AppTypography.bodyMedium().copyWith(fontSize: 12)),
                    const SizedBox(height: 4),
                    Row(children: [
                      // Statut en ligne
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOnline ? AppColors.success : AppColors.inkSubtle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(isOnline ? 'En ligne' : 'Hors ligne',
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: isOnline ? AppColors.success : AppColors.inkSubtle,
                          )),
                      const SizedBox(width: 12),
                      // Véhicule
                      Icon(_vehicleIcon(livreur.permisType),
                          size: 13, color: AppColors.inkSubtle),
                      const SizedBox(width: 3),
                      Text(_vehicleLabel(livreur.permisType),
                          style: AppTypography.bodyMedium().copyWith(fontSize: 10)),
                    ]),
                  ],
                ),
              ),
              // Permis badge
              Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: permisOk
                        ? AppColors.successLight
                        : AppColors.accentLight,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    permisOk ? 'Permis ✓' : 'En attente',
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: permisOk ? AppColors.success : AppColors.accent,
                    ),
                  ),
                ),
                if (!permisOk) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _showPermisConfirmDialog(livreur),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text('Valider',
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          )),
                    ),
                  ),
                ],
              ]),
            ]),
          ],
        ),
      ),
    );
  }

  void _showPermisConfirmDialog(Users livreur) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.verified_rounded,
                color: AppColors.success, size: 18),
          ),
          const SizedBox(width: 10),
          Text('Valider le permis', style: AppTypography.titleMedium()),
        ]),
        content: Text(
          'Confirmer la validation du permis de ${livreur.firstname} ${livreur.lastname} ?',
          style: AppTypography.bodyLarge(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler',
                style: AppTypography.labelMedium(color: AppColors.inkMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _validatePermis(livreur);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  Future<void> _validatePermis(Users livreur) async {
    final cloudFunction = ParseCloudFunction('updateUser');
    try {
      final response = await cloudFunction.execute(parameters: {
        'userID': livreur.userID,
        'permisVerified': true,
      });
      if (response.success) {
        if (mounted) {
          setState(() => livreur.permisVerified = true);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Permis de ${livreur.firstname} validé'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md)),
          ));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Erreur lors de la validation'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
        ));
      }
    }
  }
}
