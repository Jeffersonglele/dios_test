import 'dart:convert';

import 'package:dios_delices/core/commande_status.dart';

import 'package:dios_delices/modeles/commande.dart';
import 'package:dios_delices/modeles/dish.dart';
import 'package:dios_delices/modeles/ligne_commande.dart';
import 'package:dios_delices/modeles/restaurant.dart';
import 'package:dios_delices/modeles/users.dart';
import 'package:dios_delices/services/commande_api.dart';
import 'package:dios_delices/services/livreur_api.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/strings.dart';
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
      return Strings.get('Connexion impossible : identifiants de connexion incorrects. Veuillez vous reconnecter.', 'Login failed: incorrect credentials. Please log in again.');
    }

    return '${Strings.error} : ${e.toString()}';
  }

  List<Commande> commandes = [];
  bool isLoading = true;
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
    try {
      final query = QueryBuilder<ParseObject>(ParseObject('Commande'));
      sub = await liveQuery.client.subscribe(query);
      sub!.on(LiveQueryEvent.create, (_) async {
        await Commande.refreshLocalCommandes();
        await loadOrders();
      });
      sub!.on(LiveQueryEvent.update, (_) async {
        await Commande.refreshLocalCommandes();
        await loadOrders();
      });
      sub!.on(LiveQueryEvent.delete, (_) async {
        await Commande.refreshLocalCommandes();
        await loadOrders();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_buildAuthErrorMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    if (sub != null) liveQuery.client.unSubscribe(sub!);
    super.dispose();
  }

  Future<void> loadOrders() async {
    final session = await SessionService.readSession();
    final allC = await Commande.fetchCommandesFromDB();
    final allD = await Dish.fetchDishesFromDB();
    final allR = await Restaurant.fetchRestaurantsFromDB();

    final dn = <int, String>{};
    for (final d in allD) {
      dn[d.dishID] = d.name ?? '${Strings.get('Plat', 'Dish')} ${d.dishID}';
    }
    final rn = <int, String>{};
    for (final r in allR) {
      rn[r.restaurantID] = r.name;
    }

    var filtered = widget.showRestaurantOrders
        ? allC.where((c) => c.restaurateurID == session.userId).toList()
        : allC.where((c) => c.userID == session.userId).toList();
    if (statusFilter != null)
      filtered = filtered.where((c) => c.status == statusFilter).toList();
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
            ? Strings.get('Confirmer la commande', 'Confirm order')
            : Strings.get('Annuler la commande', 'Cancel order')),
        content: Text(newStatus == CommandeStatus.confirmed
            ? Strings.get('Voulez-vous vraiment confirmer cette commande ?', 'Do you really want to confirm this order?')
            : Strings.get('Voulez-vous vraiment annuler cette commande ?', 'Do you really want to cancel this order?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(Strings.get('Non', 'No')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == CommandeStatus.confirmed
                  ? AppColors.success
                  : AppColors.error,
            ),
            child: Text(newStatus == CommandeStatus.confirmed
                ? Strings.get('Oui, confirmer', 'Yes, confirm')
                : Strings.get('Oui, annuler', 'Yes, cancel')),
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
                  ? Strings.get('Commande confirmée', 'Order confirmed')
                  : Strings.get('Commande annulée', 'Order cancelled')),
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
              content: Text('${Strings.error}: ${e.toString()}'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        print('Erreur updateStatus: $e');
      } finally {
        if (mounted) {
          setState(() => isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(
            widget.showRestaurantOrders ? Strings.orders : Strings.myOrders),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
      ),
      body: Column(children: [
        _buildFilters(isSmallScreen),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : commandes.isEmpty
                  ? Center(
                      child: Text(
                          widget.showRestaurantOrders
                              ? Strings.get('Aucune commande reçue.', 'No orders received.')
                              : Strings.get('Aucune commande trouvée.', 'No orders found.'),
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
    const allKey = 'all';
    final statuses = [
      allKey,
      CommandeStatus.pending,
      CommandeStatus.confirmed,
      CommandeStatus.cancelled
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: statuses.map((s) {
          final active = statusFilter == (s == allKey ? null : s);
          String label;
          if (s == allKey) {
            label = Strings.get('Toutes', 'All');
          } else if (s == CommandeStatus.pending) {
            label = Strings.pending;
          } else if (s == CommandeStatus.confirmed) {
            label = Strings.confirmed;
          } else {
            label = Strings.cancelled;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => statusFilter = s == allKey ? null : s);
                loadOrders();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                    horizontal: isSmall ? 10 : 14, vertical: isSmall ? 6 : 8),
                decoration: BoxDecoration(
                  color: active ? AppColors.brand : AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: active ? AppColors.brand : AppColors.border,
                    width: 0.5,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: isSmall ? 12 : 14,
                    fontWeight: FontWeight.w500,
                    color: active ? Colors.white : AppColors.inkMuted,
                  ),
                ),
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
          isRestaurantView
              ? '${Strings.get('Commande', 'Order')} #${c.commandeID}'
              : restoNames[c.restauID] ?? '${Strings.get('Commande', 'Order')} #${c.commandeID}',
          style: AppTypography.labelMedium(),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${c.dateCommande.toLocal().toString().split(" ")[0]} · ${c.heure}',
              style: AppTypography.bodyMedium().copyWith(fontSize: 12),
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
              if (!snap.hasData) {
                return const SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final lignes = snap.data!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...lignes.map((l) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _buildLigneItem(l),
                      )),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${Strings.delivery}: ${c.fraisLivraison.toStringAsFixed(2)} €',
                        style:
                            AppTypography.bodyMedium().copyWith(fontSize: 12),
                      ),
                      Text(
                        '${Strings.get('Réduction', 'Discount')}: ${c.reduction.toStringAsFixed(2)} €',
                        style:
                            AppTypography.bodyMedium().copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!isRestaurantView) _buildClientButtons(c, status),
                  if (isRestaurantView)
                    _buildRestaurantButtons(c, status, canCancel, canConfirm),
                ],
              );
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
                    withUsername: Strings.get('Restaurateur', 'Restaurant owner'),
                  ),
                ),
              );
            } catch (e) {
              print('Erreur navigation ChatScreen: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(Strings.get("Erreur lors de l'ouverture du chat", 'Error opening chat')),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            }
          },
          icon: const Icon(Icons.chat_rounded, size: 16),
          label: Text(Strings.get('Message', 'Message')),
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
            label: Text(Strings.get('Noter', 'Rate')),
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
                withUsername: '${Strings.get('Client', 'Client')} #${c.commandeID}',
              ),
            ),
          ),
          icon: const Icon(Icons.chat_rounded, size: 16),
          label: Text(Strings.get('Message', 'Message')),
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
            child: Text(Strings.cancel, style: const TextStyle(fontSize: 12)),
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
            child: Text(Strings.confirm, style: const TextStyle(fontSize: 12)),
          ),
        OutlinedButton.icon(
          onPressed: () => _showAssignLivreur(c.commandeID),
          icon: const Icon(Icons.person_add_rounded, size: 16),
          label: Text(Strings.get('Livreur', 'Driver')),
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
                dishNames[l.platID] ?? '${Strings.get('Plat', 'Dish')} #${l.platID}',
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
                dishNames[l.platID] ?? '${Strings.get('Plat', 'Dish')} #${l.platID}',
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

  Future<void> _showAssignLivreur(int id) async {
    final users = await Users.fetchUsersFromDB();
    final livreurs = users.where((u) => u.roleID == 5).toList();
    if (!mounted) return;
    if (livreurs.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(Strings.get('Aucun livreur.', 'No driver available.'))));
      return;
    }
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(Strings.get('Assigner un livreur', 'Assign a driver')),
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
                            await LivreurApi.assignLivreur(id, livreurs[i].userID);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      content: Text(Strings.get('Livreur assigné.', 'Driver assigned.'))));
                              loadOrders();
                            }
                          },
                        )),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(Strings.cancel))
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
          title: Text(Strings.get('Noter le restaurant', 'Rate the restaurant')),
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
                      Text(
                        Strings.get('Plats commandés :', 'Ordered dishes:'),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      ...lignes.map((l) => Text(
                            '• ${dishNames[l.platID] ?? '${Strings.get('Plat', 'Dish')} #${l.platID}'} x${l.quantite}',
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
                decoration: InputDecoration(
                  labelText: Strings.get('Votre commentaire (optionnel)', 'Your comment (optional)'),
                  border: const OutlineInputBorder(),
                  hintText: Strings.get('Partagez votre expérience...', 'Share your experience...'),
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
              child: Text(Strings.get('Plus tard', 'Later')),
            ),
            ElevatedButton(
              onPressed: () async {
                final session = await SessionService.readSession();

                if (session.userId == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(Strings.get('Utilisateur non connecté', 'User not logged in'))),
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
                      SnackBar(
                        content: Text(Strings.get('Merci pour votre avis !', 'Thank you for your review!')),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '${Strings.error}: ${response.error?.message ?? "Inconnue"}'),
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
              child: Text(Strings.get('Envoyer', 'Send')),
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
    final labels = [
      Strings.get('Prépa.', 'Prep'),
      Strings.get('Récupéré', 'Picked up'),
      Strings.get('En route', 'In transit'),
      Strings.get('Livré', 'Delivered')
    ];
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
                       child: Text(Strings.get('Toucher pour agrandir', 'Tap to enlarge'),
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
      appBar: AppBar(title: Text(Strings.get('Suivi livraison', 'Delivery tracking'))),
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
                  child: Column(children: [
                    const Icon(Icons.delivery_dining,
                        color: AppColors.brand, size: 32),
                    Text(Strings.get('Livreur', 'Driver'),
                        style:
                            const TextStyle(fontSize: 9, fontWeight: FontWeight.bold))
                  ])),
              if (widget.clientLat != null)
                Marker(
                    point: LatLng(widget.clientLat!, widget.clientLng!),
                    width: 50,
                    height: 50,
                    child: Column(children: [
                      const Icon(Icons.home_rounded,
                          color: AppColors.accent, size: 32),
                      Text(Strings.get('Client', 'Client'),
                          style: const TextStyle(
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
