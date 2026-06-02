import 'package:dios_delices/providers/data_version_notifier.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../../modeles/restaurant.dart';
import '../../modeles/users.dart';
import '../../widgets/dios_image.dart';
import '../../utils/toast.dart';
import 'RestaurantDetails.dart';

class RestaurantListPage extends StatefulWidget {
  final String country;

  const RestaurantListPage({super.key, required this.country});

  @override
  _RestaurantListPageState createState() => _RestaurantListPageState();
}

class _RestaurantListPageState extends State<RestaurantListPage> {
  List<Map<String, dynamic>> filteredRestaurants = [];
  List<Users> users = [];
  List<Restaurant> restaus = [];
  bool isLoading = true;
  bool showOnlyWaitingForValidation = false;
  String sortBy = 'Nom';
  String searchQuery = '';

  final TextEditingController _searchCtrl = TextEditingController();

  Future<bool> _sendEmailToUser(Restaurant restaurant, bool valid, [String? remark]) async {
    Users? user = Users.getUsersByUserId(users, restaurant.userID);
    final recipientEmail = user?.email ?? 'adigbononrodicaa@gmail.com';
    final subject = valid
        ? '🎉 Bienvenue sur Dios Délices - Votre restaurant est validé !'
        : '❌ Mise à jour : Validation de votre restaurant sur Dios Délices';

    final messageText = valid
        ? 'Bonjour ${user?.firstname},\n\n'
            'Nous sommes ravis de vous informer que votre restaurant "${restaurant.name}" a été validé. '
            'Vous pouvez maintenant accéder à votre compte pour gérer votre restaurant et recevoir des commandes.\n\n'
            'Cordialement,\nL’équipe Dios Délices'
        : 'Bonjour ${user?.firstname},\n\n'
            'Nous regrettons de vous informer que votre restaurant "${restaurant.name}" n’a pas été validé suite à notre processus de vérification.\n\n'
            'Raison du rejet : ${remark ?? "Non spécifiée"}\n\n'
            'Pour plus d’informations, n’hésitez pas à nous contacter.\n\n'
            'Cordialement,\nL’équipe Dios Délices';

    final cloudFunction = ParseCloudFunction('sendEmail');
    try {
      await cloudFunction.execute(parameters: {
        'to': recipientEmail,
        'subject': subject,
        'text': messageText,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    dataVersionNotifier.addListener(_onDataChanged);
    loadData();
  }

  @override
  void dispose() {
    dataVersionNotifier.removeListener(_onDataChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) loadData();
  }

  void loadData() async {
    List<Users> usersList = await Users.fetchUsersFromDB();
    List<Restaurant> restausList = await Restaurant.fetchRestaurantsFromDB();

    setState(() {
      users = usersList;
      restaus = restausList;
      _fetchRestaurantsByCountry();
    });
  }

  Future<void> _fetchRestaurantsByCountry() async {
    for (var restaurant in restaus) {
      Users? user = await Users.getUsersByUserId(users, restaurant.userID);
      if (user != null && user.country == widget.country) {
        setState(() {
          filteredRestaurants.add({"restaurant": restaurant, "user": user});
        });
      }
    }
    setState(() {
      isLoading = false;
    });
  }

  void _sortRestaurants(String criterion) {
    setState(() {
      sortBy = criterion;
      if (criterion == 'Nom') {
        filteredRestaurants.sort((a, b) => b["restaurant"].name.compareTo(a["restaurant"].name));
      } else       if (criterion == 'Note') {
        filteredRestaurants.sort((a, b) => b["restaurant"].note.compareTo(a["restaurant"].note));
      } else if (criterion == 'Commandes') {
        filteredRestaurants.sort((a, b) =>
            b["restaurant"].nb_orders.compareTo(a["restaurant"].nb_orders));
      }
    });
  }

  List<Map<String, dynamic>> get _filteredList {
    if (searchQuery.isEmpty) return filteredRestaurants;
    return filteredRestaurants.where((item) {
      final rest = item["restaurant"] as Restaurant;
      return rest.name.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _filteredList;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('Restaurants · ${widget.country}'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
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
                    onChanged: (v) => setState(() {}),
                    style: AppTypography.bodyLarge().copyWith(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un restaurant...',
                      hintStyle: AppTypography.bodyMedium().copyWith(fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: AppColors.inkSubtle, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: PopupMenuButton<String>(
                  onSelected: _sortRestaurants,
                  offset: const Offset(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  itemBuilder: (_) => {'Nom', 'Note', 'Commandes'}
                      .map((c) => PopupMenuItem(value: c, child: Text(c)))
                      .toList(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.sort_rounded, color: AppColors.inkMuted, size: 20),
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: showOnlyWaitingForValidation
                      ? AppColors.accentLight
                      : AppColors.card,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: showOnlyWaitingForValidation
                        ? AppColors.accent
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: showOnlyWaitingForValidation,
                      activeColor: AppColors.accent,
                      onChanged: (v) => setState(() => showOnlyWaitingForValidation = v),
                    ),
                    Text('En attente', style: AppTypography.labelMedium().copyWith(fontSize: 12)),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              const Spacer(),
              Text('${displayed.length} restaurant(s)',
                  style: AppTypography.bodyMedium().copyWith(fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : displayed.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.storefront_outlined,
                                size: 64, color: AppColors.inkSubtle),
                            const SizedBox(height: 12),
                            Text('Aucun restaurant trouvé',
                                style: AppTypography.bodyLarge(color: AppColors.inkMuted)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: displayed.length,
                        itemBuilder: (context, index) {
                          final item = displayed[index];
                          final restaurant = item["restaurant"] as Restaurant;
                          final user = item["user"] as Users;

                          if (showOnlyWaitingForValidation && restaurant.valid == 1) {
                            return const SizedBox.shrink();
                          }

                          return _buildRestaurantCard(restaurant, user);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantCard(Restaurant restaurant, Users user) {
    final isValid = restaurant.valid == 1;
    final isRejected = restaurant.valid == 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: AppShadows.cardList,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RestaurantDetails(restaurant_id: restaurant.restaurantID),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: DiosImage(
                      url: restaurant.image,
                      fit: BoxFit.cover,
                      width: 64,
                      height: 64,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurant.name,
                          style: AppTypography.titleMedium().copyWith(fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          restaurant.categories,
                          style: AppTypography.bodyMedium().copyWith(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(children: [
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isValid
                                  ? AppColors.success
                                  : isRejected
                                      ? AppColors.error
                                      : AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isValid ? 'Validé' : isRejected ? 'Rejeté' : 'En attente',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isValid
                                  ? AppColors.success
                                  : isRejected
                                      ? AppColors.error
                                      : AppColors.accent,
                            ),
                          ),
                          if (isValid) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.star_rounded, color: AppColors.accent, size: 14),
                            const SizedBox(width: 2),
                            Text('${restaurant.note}',
                                style: AppTypography.bodyMedium().copyWith(fontSize: 11)),
                            const SizedBox(width: 8),
                            Icon(Icons.receipt_long_rounded,
                                color: AppColors.inkSubtle, size: 12),
                            const SizedBox(width: 2),
                            Text('${restaurant.nb_orders}',
                                style: AppTypography.bodyMedium().copyWith(fontSize: 11)),
                          ],
                        ]),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.inkSubtle, size: 20),
                ]),
                if (!isValid)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Propriétaire: ${user.firstname} · ${user.email}',
                            style: AppTypography.bodyMedium().copyWith(fontSize: 11)),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.successLight,
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Icon(Icons.check_rounded, color: AppColors.success, size: 20),
                              ),
                              onPressed: () => _validateRestaurant(restaurant),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.errorLight,
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Icon(Icons.close_rounded, color: AppColors.error, size: 20),
                              ),
                              onPressed: () => _showRejectDialog(restaurant),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRejectDialog(Restaurant restaurant) {
    final remarkCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
          ),
          const SizedBox(width: 10),
          Text('Rejeter le restaurant', style: AppTypography.titleMedium()),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Motif du rejet pour "${restaurant.name}" :',
              style: AppTypography.bodyMedium()),
          const SizedBox(height: 12),
          TextField(
            controller: remarkCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Saisissez votre remarque...',
              filled: true,
              fillColor: AppColors.surfaceWarm,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler',
                style: AppTypography.labelMedium(color: AppColors.inkMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              _rejectRestaurant(restaurant, remarkCtrl.text);
            },
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
  }

  Future<void> _validateRestaurant(Restaurant restaurant) async {
    final updateResult = await Restaurant.updateRestaurantStatus(restaurant.restaurantID, 1);
    if (updateResult == "success") {
      final emailSent = await _sendEmailToUser(restaurant, true);
      if (mounted) {
        setState(() => restaurant.valid = 1);
        Toast(context,
            "Le restaurant ${restaurant.name} a été validé${emailSent ? ' et un email a été envoyé.' : '.'}",
            emailSent);
      }
    } else {
      if (mounted) Toast(context, "Erreur : $updateResult", false);
    }
  }

  Future<void> _rejectRestaurant(Restaurant restaurant, String remark) async {
    final updateResult = await Restaurant.updateRestaurantStatus(restaurant.restaurantID, 2);
    if (updateResult == "success") {
      final emailSent = await _sendEmailToUser(restaurant, false, remark);
      if (mounted) {
        setState(() => restaurant.valid = 2);
        Toast(context,
            "Le restaurant ${restaurant.name} a été rejeté${emailSent ? ' et un email a été envoyé.' : '.'}",
            false);
      }
    } else {
      if (mounted) Toast(context, "Erreur : $updateResult", false);
    }
  }
}
