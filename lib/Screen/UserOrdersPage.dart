import 'dart:convert';

import 'package:dios_delices/core/commande_status.dart';

import 'package:dios_delices/modeles/commande.dart';
import 'package:dios_delices/modeles/dish.dart';
import 'package:dios_delices/modeles/ligne_commande.dart';
import 'package:dios_delices/modeles/restaurant.dart';
import 'package:dios_delices/modeles/users.dart';
import 'package:dios_delices/services/commande_api.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ChatScreen.dart';

class UserOrdersPage extends StatefulWidget {
  final bool showRestaurantOrders;
  const UserOrdersPage({super.key, this.showRestaurantOrders = false});

  @override
  State<UserOrdersPage> createState() => _UserOrdersPageState();
}

class _UserOrdersPageState extends State<UserOrdersPage> {
  String _buildAuthErrorMessage(Object e) {
    final text = e.toString().toLowerCase();
    final isInvalidAuth = RegExp(
      r'(invalid session|invalid.*session|session.*invalid|unauthorized|forbidden|invalid.*token|auth(entication)?|wrong.*password|invalid.*credentials|credentials.*invalid)',
      caseSensitive: false,
    ).hasMatch(text);

    if (isInvalidAuth) {
      return 'Connexion impossible : identifiants de connexion incorrects. Veuillez vous reconnecter.';
    }

    return 'Erreur : ${e.toString()}';
  }

  List<Commande> commandes = [];
  bool isLoading = true;
  bool _restoValid = true;
  Map<int, String> dishNames = {};
  Map<int, String> restoNames = {};
  String? statusFilter;
  final LiveQuery liveQuery = LiveQuery();
  Subscription? sub;

  @override
  void initState() {
    super.initState();
    loadOrders();
    _listen();
  }

  Future<void> _listen() async {
    final query = QueryBuilder<ParseObject>(ParseObject('Commande'));
    sub = await liveQuery.client.subscribe(query);
    sub!.on(LiveQueryEvent.create, (_) async {
      await Commande.refreshLocalCommandes();
      await LigneCommande.getAllLignesCommande();
      await loadOrders();
    });
    sub!.on(LiveQueryEvent.update, (_) async {
      await Commande.refreshLocalCommandes();
      await LigneCommande.getAllLignesCommande();
      await loadOrders();
    });
    sub!.on(LiveQueryEvent.delete, (_) async {
      await Commande.refreshLocalCommandes();
      await LigneCommande.getAllLignesCommande();
      await loadOrders();
    });
  }

  @override
  void dispose() {
    if (sub != null) liveQuery.client.unSubscribe(sub!);
    super.dispose();
  }

  Future<void> loadOrders() async {
    final session = await SessionService.readSession();

    // Vérifier la validité du restaurant pour les restaurateurs
    if (widget.showRestaurantOrders && session.restaurantId != null) {
      final restaurants = await Restaurant.fetchRestaurantsFromDB();
      final resto = Restaurant.getRestaurantByRestaurantId(
          restaurants, session.restaurantId!);
      _restoValid = resto?.valid == 1;
    }

    await Commande.refreshLocalCommandes(); // Refresh orders from Parse first!
    await LigneCommande
        .getAllLignesCommande(); // Refresh order items from Parse too!
    final allC = await Commande.fetchCommandesFromDB();
    final allD = await Dish.fetchDishesFromDB();
    final allR = await Restaurant.fetchRestaurantsFromDB();

    for (var i = 0; i < allC.length; i++) {
    }

    final dn = <int, String>{};
    for (final d in allD) {
      dn[d.dishID] = d.name ?? 'Plat ${d.dishID}';
    }
    final rn = <int, String>{};
    for (final r in allR) {
      rn[r.restaurantID] = r.name;
    }

    var filtered = <Commande>[];
    for (var c in allC) {
      if (widget.showRestaurantOrders) {
        if (c.restaurateurID == session.userId) {
          filtered.add(c);
        }
      } else {
        if (c.userID == session.userId) {
          filtered.add(c);
        }
      }
    }
    if (statusFilter != null)
      filtered = filtered.where((c) => c.status == statusFilter).toList();
    for (var i = 0; i < filtered.length; i++) {
    }
    filtered.sort((a, b) => b.dateCommande.compareTo(a.dateCommande));

    if (!mounted) return;
    setState(() {
      dishNames = dn;
      restoNames = rn;
      commandes = filtered;
      isLoading = false;
    });
  }

  Future<List<LigneCommande>> getLignes(int id) =>
      LigneCommande.fetchLignesCommandeByCommandeID(id);

  Future<void> updateStatus(int id, String newStatus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(newStatus == CommandeStatus.confirmed
            ? 'Confirmer la commande'
            : 'Annuler la commande'),
        content: Text(newStatus == CommandeStatus.confirmed
            ? 'Voulez-vous vraiment confirmer cette commande ?'
            : 'Voulez-vous vraiment annuler cette commande ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == CommandeStatus.confirmed
                  ? AppColors.success
                  : AppColors.error,
            ),
            child: Text(newStatus == CommandeStatus.confirmed
                ? 'Oui, confirmer'
                : 'Oui, annuler'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Afficher un indicateur de chargement
      setState(() => isLoading = true);

      try {
        // Tentative de mise à jour
        await CommandeApi.updateOrderStatus(id.toString(), newStatus);

        // Rafraîchir les données
        await Commande.refreshLocalCommandes();
        await loadOrders();

        // Message de succès
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(newStatus == CommandeStatus.confirmed
                  ? 'Commande confirmée'
                  : 'Commande annulée'),
              backgroundColor: newStatus == CommandeStatus.confirmed
                  ? AppColors.success
                  : AppColors.error,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        // Message d'erreur détaillé
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${e.toString()}'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
          title: Text(widget.showRestaurantOrders
              ? 'Commandes reçues'
              : 'Mes commandes')),
      body: widget.showRestaurantOrders && !_restoValid
          ? _buildPendingFullPage()
          : Column(children: [
              _buildFilters(isSmallScreen),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : commandes.isEmpty
                        ? Center(
                            child: Text(
                                widget.showRestaurantOrders
                                    ? 'Aucune commande reçue.'
                                    : 'Aucune commande trouvée.',
                                style: AppTypography.bodyMedium()))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                            itemCount: commandes.length,
                            itemBuilder: (_, i) =>
                                _buildCard(commandes[i], isSmallScreen),
                          ),
              ),
            ]),
    );
  }

  Widget _buildFilters(bool isSmall) {
    final statuses = [
      'Tous',
      CommandeStatus.pending,
      CommandeStatus.confirmed,
      CommandeStatus.cancelled
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: statuses.map((s) {
          final active = statusFilter == (s == 'Tous' ? null : s);
          final label = s == 'Tous'
              ? 'Tous'
              : s == CommandeStatus.pending
                  ? 'En attente'
                  : s;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => statusFilter = s == 'Tous' ? null : s);
                loadOrders();
              },
              child: AnimatedContainer(
                duration: AppMotion.fast,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.brand : AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                      color: active ? AppColors.brand : AppColors.border,
                      width: 0.5),
                ),
                child: Text(label,
                    style: AppTypography.labelMedium(
                        color: active ? Colors.white : AppColors.inkMuted)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCard(Commande c, bool isSmall) {
    final status = CommandeStatus.normalize(c.status);
    final statusColor = CommandeStatus.color(status);
    final isRestaurantView = widget.showRestaurantOrders;

    final bool isCancelled = status == CommandeStatus.cancelled;
    final bool isConfirmed = status == CommandeStatus.confirmed;
    final bool canCancel = !isCancelled && !isConfirmed;
    final bool canConfirm = !isConfirmed && !isCancelled;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
            widget.showRestaurantOrders
                ? 'Commande #${c.commandeID}'
                : restoNames[c.restauID] ?? 'Commande #${c.commandeID}',
            style: AppTypography.labelMedium()),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${c.dateCommande.toLocal().toString().split(" ")[0]} · ${c.heure}',
                style: AppTypography.bodyMedium().copyWith(fontSize: 12)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99)),
              child: Text(status,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
            if (!widget.showRestaurantOrders &&
                c.deliveryStatus != null &&
                c.deliveryStatus!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _DeliveryTracker(
                    status: c.deliveryStatus!,
                    lat: c.livreurLat,
                    lng: c.livreurLng),
              ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (!isRestaurantView &&
                c.deliveryStatus != null &&
                c.deliveryStatus!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _DeliveryTracker(
                  status: c.deliveryStatus!,
                  lat: c.livreurLat,
                  lng: c.livreurLng,
                ),
              ),
          ],
        ),
        children: [
          FutureBuilder<List<LigneCommande>>(
            future: getLignes(c.commandeID),
            builder: (_, snap) {
              if (!snap.hasData)
                return const SizedBox(
                    height: 60,
                    child: Center(child: CircularProgressIndicator()));
              final lignes = snap.data!;
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...lignes.map((l) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(children: [
                            Expanded(
                                child: Text(
                                    dishNames[l.platID] ?? 'Plat #${l.platID}',
                                    style: AppTypography.bodyMedium())),
                            Text('x${l.quantite}',
                                style: AppTypography.labelMedium()),
                            const SizedBox(width: 12),
                            Text('${l.prixUnitaire.toStringAsFixed(2)} €',
                                style: AppTypography.bodyMedium(
                                    color: AppColors.brand)),
                          ]),
                        )),
                    const Divider(),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              'Livraison: ${c.fraisLivraison.toStringAsFixed(2)} €',
                              style: AppTypography.bodyMedium()
                                  .copyWith(fontSize: 12)),
                          Text('Réduction: ${c.reduction.toStringAsFixed(2)} €',
                              style: AppTypography.bodyMedium()
                                  .copyWith(fontSize: 12)),
                        ]),
                    const SizedBox(height: 12),
                    if (!widget.showRestaurantOrders)
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                          withUserID: c.restaurateurID,
                                          withUsername: 'Restaurateur'))),
                              icon: const Icon(Icons.chat_rounded, size: 16),
                              label: const Text('Message'),
                              style: OutlinedButton.styleFrom(
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8)),
                            ),
                            if (status == CommandeStatus.confirmed)
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _showRate(c.commandeID, c.restauID),
                                icon: const Icon(Icons.star_rounded,
                                    size: 16, color: AppColors.accent),
                                label: const Text('Noter'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentLight,
                                  foregroundColor: AppColors.accent,
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                              ),
                          ]),
                    if (widget.showRestaurantOrders)
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                      withUserID: c.userID,
                                      withUsername:
                                          'Client #${c.commandeID}'))),
                          icon: const Icon(Icons.chat_rounded, size: 16),
                          label: const Text('Message'),
                          style: OutlinedButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8)),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          onPressed: status == CommandeStatus.cancelled
                              ? null
                              : () => updateStatus(
                                  c.commandeID, CommandeStatus.cancelled),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                          ),
                          child: const Text('Annuler',
                              style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          onPressed: status == CommandeStatus.confirmed
                              ? null
                              : () => updateStatus(
                                  c.commandeID, CommandeStatus.confirmed),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                          ),
                          child: const Text('Confirmer',
                              style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          onPressed: () => _showAssignLivreur(c.commandeID),
                          icon: const Icon(Icons.person_add_rounded, size: 16),
                          label: const Text('Livreur'),
                          style: OutlinedButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8)),
                        ),
                      ]),
                  ]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClientButtons(Commande c, String status) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            try {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    withUserID: c.restaurateurID,
                    withUsername: 'Restaurateur',
                  ),
                ),
              );
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Erreur lors de l\'ouverture du chat'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            }
          },
          icon: const Icon(Icons.chat_rounded, size: 16),
          label: const Text('Message'),
          style: OutlinedButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        if (status == CommandeStatus.confirmed)
          ElevatedButton.icon(
            onPressed: () => _showRate(c.commandeID, c.restauID),
            icon: const Icon(Icons.star_rounded,
                size: 16, color: AppColors.accent),
            label: const Text('Noter'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentLight,
              foregroundColor: AppColors.accent,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
      ],
    );
  }

  Widget _buildRestaurantButtons(
      Commande c, String status, bool canCancel, bool canConfirm) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                withUserID: c.userID,
                withUsername: 'Client #${c.commandeID}',
              ),
            ),
          ),
          icon: const Icon(Icons.chat_rounded, size: 16),
          label: const Text('Message'),
          style: OutlinedButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        if (canCancel)
          ElevatedButton(
            onPressed: () =>
                updateStatus(c.commandeID, CommandeStatus.cancelled),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('Annuler', style: TextStyle(fontSize: 12)),
          ),
        if (canConfirm)
          ElevatedButton(
            onPressed: () =>
                updateStatus(c.commandeID, CommandeStatus.confirmed),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('Confirmer', style: TextStyle(fontSize: 12)),
          ),
        OutlinedButton.icon(
          onPressed: () => _showAssignLivreur(c.commandeID),
          icon: const Icon(Icons.person_add_rounded, size: 16),
          label: const Text('Livreur'),
          style: OutlinedButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildLigneItem(LigneCommande l) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dishNames[l.platID] ?? 'Plat #${l.platID}',
                style: AppTypography.bodyMedium(),
              ),
              const SizedBox(height: 2),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('x${l.quantite}', style: AppTypography.labelMedium()),
                  Text(
                    '${l.prixUnitaire.toStringAsFixed(2)} €',
                    style: AppTypography.bodyMedium(color: AppColors.brand),
                  ),
                ],
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                dishNames[l.platID] ?? 'Plat #${l.platID}',
                style: AppTypography.bodyMedium(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              flex: 0,
              child: Text('x${l.quantite}', style: AppTypography.labelMedium()),
            ),
            const SizedBox(width: 12),
            Flexible(
              flex: 0,
              child: Text(
                '${l.prixUnitaire.toStringAsFixed(2)} €',
                style: AppTypography.bodyMedium(color: AppColors.brand),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPendingFullPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(height: 40),
        Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle),
            child: const Icon(Icons.hourglass_bottom_rounded,
                color: AppColors.accent, size: 48)),
        const SizedBox(height: 28),
        Text('Restaurant en cours de validation',
            textAlign: TextAlign.center,
            style: AppTypography.headlineMedium().copyWith(fontSize: 20)),
        const SizedBox(height: 12),
        Text(
            'Votre restaurant est en cours d\'examen par nos administrateurs. Vous pourrez recevoir des commandes dès qu\'il sera validé.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge(color: AppColors.inkMuted)),
        const SizedBox(height: 32),
        Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border, width: 0.5)),
            child: Column(children: [
              Row(children: [
                Icon(Icons.email_rounded, size: 18, color: AppColors.accent),
                const SizedBox(width: 10),
                Expanded(
                    child: Text('Vous serez notifié par email',
                        style: AppTypography.bodyMedium()
                            .copyWith(fontSize: 13)))
              ]),
              const Divider(height: 24),
              Row(children: [
                Icon(Icons.receipt_long_rounded,
                    size: 18, color: AppColors.accent),
                const SizedBox(width: 10),
                Expanded(
                    child: Text('Et recevoir des commandes',
                        style: AppTypography.bodyMedium()
                            .copyWith(fontSize: 13)))
              ]),
            ])),
      ]),
    );
  }

  Future<void> _showAssignLivreur(int id) async {
    final users = await Users.fetchUsersFromDB();
    final livreurs = users.where((u) => u.roleID == 5).toList();
    if (!mounted) return;
    if (livreurs.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Aucun livreur.')));
      return;
    }
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Assigner un livreur'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: livreurs.length,
                    itemBuilder: (_, i) => ListTile(
                          leading:
                              const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(
                              '${livreurs[i].firstname} ${livreurs[i].lastname}'),
                          onTap: () async {
                            Navigator.pop(ctx);
                            try {
                              final cloudFunction =
                                  ParseCloudFunction('assignLivreur');
                              final response =
                                  await cloudFunction.execute(parameters: {
                                'commandeID': id,
                                'livreurID': livreurs[i].userID,
                              });

                              if (response.success) {
                                await Commande.refreshLocalCommandes();
                                await loadOrders();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Livreur assigné avec succès!')),
                                  );
                                }
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            'Erreur: ${response.error?.message}')),
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erreur: $e')),
                                );
                              }
                            }
                          },
                        )),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Annuler'))
              ],
            ));
  }

  Future<void> _showRate(int cmdId, int restauId) async {
    final ctrl = TextEditingController();
    int note = 5;

    final lignes = await LigneCommande.fetchLignesCommandeByCommandeID(cmdId);

    if (!mounted) return;

    // Récupérer le username depuis SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('currentUser_name') ?? '';
    final userImage = prefs.getString('currentUser_image') ?? '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Noter le restaurant'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (lignes.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Plats commandés :',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      ...lignes.map((l) => Text(
                            '• ${dishNames[l.platID] ?? 'Plat #${l.platID}'} x${l.quantite}',
                            style: const TextStyle(fontSize: 12),
                          )),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    icon: Icon(
                      i < note
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: AppColors.accent,
                      size: 40,
                    ),
                    onPressed: () => setD(() => note = i + 1),
                  );
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: 'Votre commentaire (optionnel)',
                  border: OutlineInputBorder(),
                  hintText: 'Partagez votre expérience...',
                ),
                maxLines: 3,
                maxLength: 500,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                ctrl.dispose();
                Navigator.pop(ctx);
              },
              child: const Text('Plus tard'),
            ),
            ElevatedButton(
              onPressed: () async {
                final session = await SessionService.readSession();

                if (session.userId == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Utilisateur non connecté')),
                    );
                  }
                  Navigator.pop(ctx);
                  ctrl.dispose();
                  return;
                }

                Navigator.pop(ctx);

                final f = ParseCloudFunction('addComment');
                final response = await f.execute(parameters: {
                  'userID': session.userId,
                  'targetType': 1,
                  'targetID': restauId,
                  'note': note,
                  'commentaire': ctrl.text.trim().isEmpty ? '' : ctrl.text,
                  'username': username, // Utiliser la variable récupérée
                  'userImage': userImage, // Utiliser la variable récupérée
                });

                ctrl.dispose();

                if (mounted) {
                  if (response.success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Merci pour votre avis !'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Erreur: ${response.error?.message ?? "Inconnue"}'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Envoyer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryTracker extends StatelessWidget {
  final String status;
  final double? lat, lng;
  const _DeliveryTracker({required this.status, this.lat, this.lng});

  @override
  Widget build(BuildContext context) {
    final steps = ['assigned', 'picked_up', 'in_transit', 'delivered'];
    final labels = ['Prépa.', 'Récupéré', 'En route', 'Livré'];
    final icons = [
      Icons.restaurant_rounded,
      Icons.shopping_bag_rounded,
      Icons.directions_bike_rounded,
      Icons.check_rounded
    ];
    final idx = steps.indexOf(status);
    final hasMap = status == 'in_transit' && lat != null && lng != null;

    return Column(children: [
      Row(
        children: List.generate(4, (i) {
          final done = i <= idx;
          return Expanded(
              child: Column(children: [
            Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? AppColors.brand : AppColors.border),
                child: Icon(icons[i],
                    size: 13,
                    color: done ? Colors.white : AppColors.inkSubtle)),
            Text(labels[i],
                style: TextStyle(
                    fontSize: 9,
                    color: done ? AppColors.brand : AppColors.inkSubtle,
                    fontWeight: FontWeight.w600)),
          ]));
        }),
      ),
      if (hasMap)
        GestureDetector(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      DeliveryMapPage(livreurLat: lat!, livreurLng: lng!))),
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            height: 160,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border:
                    Border.all(color: AppColors.brand.withValues(alpha: 0.3))),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              FlutterMap(
                options: MapOptions(
                    initialCenter: LatLng(lat!, lng!),
                    initialZoom: 14,
                    interactionOptions:
                        const InteractionOptions(flags: InteractiveFlag.none)),
                children: [
                  TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.diosdelices.app'),
                  MarkerLayer(markers: [
                    Marker(
                        point: LatLng(lat!, lng!),
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.delivery_dining,
                            color: AppColors.brand, size: 28))
                  ]),
                ],
              ),
              Positioned(
                  bottom: 4,
                  right: 8,
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.ink.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4)),
                      child: const Text('Toucher pour agrandir',
                          style:
                              TextStyle(color: Colors.white, fontSize: 10)))),
            ]),
          ),
        ),
    ]);
  }
}

class DeliveryMapPage extends StatefulWidget {
  final double livreurLat, livreurLng;
  final double? clientLat, clientLng;
  const DeliveryMapPage(
      {super.key,
      required this.livreurLat,
      required this.livreurLng,
      this.clientLat,
      this.clientLng});
  @override
  State<DeliveryMapPage> createState() => _DeliveryMapPageState();
}

class _DeliveryMapPageState extends State<DeliveryMapPage> {
  List<LatLng> _route = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.clientLat != null) _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/${widget.livreurLng},${widget.livreurLat};${widget.clientLng},${widget.clientLat}?overview=full&geometries=geojson';
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final coords = (jsonDecode(resp.body)['routes']?[0]?['geometry']
                ?['coordinates'] as List?) ??
            [];
        if (mounted)
          setState(() {
            _route = coords
                .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
                .toList();
            _loading = false;
          });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bounds = _route.isNotEmpty ? LatLngBounds.fromPoints(_route) : null;
    final center =
        bounds?.center ?? LatLng(widget.livreurLat, widget.livreurLng);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Suivi livraison')),
      body: Stack(children: [
        FlutterMap(
          options: MapOptions(
              initialCenter: center,
              initialZoom: 14,
              initialCameraFit: bounds != null
                  ? CameraFit.bounds(
                      bounds: bounds, padding: const EdgeInsets.all(40))
                  : null),
          children: [
            TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.diosdelices.app'),
            if (_route.isNotEmpty)
              PolylineLayer(polylines: [
                Polyline(points: _route, color: AppColors.brand, strokeWidth: 4)
              ]),
            MarkerLayer(markers: [
              Marker(
                  point: LatLng(widget.livreurLat, widget.livreurLng),
                  width: 50,
                  height: 50,
                  child: Column(children: const [
                    Icon(Icons.delivery_dining,
                        color: AppColors.brand, size: 32),
                    Text('Livreur',
                        style:
                            TextStyle(fontSize: 9, fontWeight: FontWeight.bold))
                  ])),
              if (widget.clientLat != null)
                Marker(
                    point: LatLng(widget.clientLat!, widget.clientLng!),
                    width: 50,
                    height: 50,
                    child: Column(children: const [
                      Icon(Icons.home_rounded,
                          color: AppColors.accent, size: 32),
                      Text('Client',
                          style: TextStyle(
                              fontSize: 9, fontWeight: FontWeight.bold))
                    ])),
            ]),
          ],
        ),
        if (_loading)
          const Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator())),
      ]),
    );
  }
}
