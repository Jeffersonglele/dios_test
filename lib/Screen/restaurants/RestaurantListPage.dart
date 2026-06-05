import 'package:dios_delices/core/app_role.dart';
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

enum _RestaurantStatus { all, pending, validated, rejected }

class _RestaurantListPageState extends State<RestaurantListPage> {
  List<Map<String, dynamic>> filteredRestaurants = [];
  List<Users> users = [];
  List<Restaurant> restaus = [];
  bool isLoading = true;
  _RestaurantStatus filterStatus = _RestaurantStatus.all;
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

  Future<void> loadData() async {
    List<Users> usersList = await Users.fetchUsersFromDB();
    List<Restaurant> restausList = await Restaurant.fetchRestaurantsFromDB();

    setState(() {
      users = usersList;
      restaus = restausList;
      filteredRestaurants = [];
      isLoading = true;
    });
    await _fetchRestaurantsByCountry();
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

  List<Map<String, dynamic>> get _filteredList {
    var list = filteredRestaurants;
    if (filterStatus == _RestaurantStatus.pending) {
      list = list.where((item) {
        final r = item["restaurant"] as Restaurant;
        return r.valid != 1 && r.valid != 2;
      }).toList();
    } else if (filterStatus == _RestaurantStatus.validated) {
      list = list.where((item) => (item["restaurant"] as Restaurant).valid == 1).toList();
    } else if (filterStatus == _RestaurantStatus.rejected) {
      list = list.where((item) => (item["restaurant"] as Restaurant).valid == 2).toList();
    }
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((item) {
        final rest = item["restaurant"] as Restaurant;
        final user = item["user"] as Users;
        return rest.name.toLowerCase().contains(q) ||
            rest.categories.toLowerCase().contains(q) ||
            '${user.firstname} ${user.lastname}'.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _filteredList;
    final totalInList = filteredRestaurants.length;
    final pendingCount = filteredRestaurants.where((i) {
      final r = i["restaurant"] as Restaurant;
      return r.valid != 1 && r.valid != 2;
    }).length;
    final validatedCount = filteredRestaurants.where((i) => (i["restaurant"] as Restaurant).valid == 1).length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('Restaurants · ${widget.country}'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: loadData,
        child: Column(
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
                        onChanged: (v) => setState(() => searchQuery = v),
                        style: AppTypography.bodyLarge().copyWith(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Rechercher un restaurant...',
                          hintStyle: AppTypography.bodyMedium().copyWith(fontSize: 14),
                          prefixIcon: Icon(Icons.search_rounded, color: AppColors.inkSubtle, size: 20),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.close_rounded, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                  ),
                ),
                const SizedBox(width: 8),
              ]),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildChip('Tous', _RestaurantStatus.all),
                  const SizedBox(width: 8),
                  _buildChip('En attente', _RestaurantStatus.pending, count: pendingCount),
                  const SizedBox(width: 8),
                  _buildChip('Validé', _RestaurantStatus.validated, count: validatedCount),
                  const SizedBox(width: 8),
                  _buildChip('Rejeté', _RestaurantStatus.rejected),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
                Text('${displayed.length} / $totalInList restaurant(s)',
                    style: AppTypography.bodyMedium().copyWith(fontSize: 12)),
                const Spacer(),
                if (pendingCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('$pendingCount en attente',
                        style: AppTypography.labelMedium(color: AppColors.accent).copyWith(fontSize: 11)),
                  ),
                if (validatedCount > 0)
                  Text('$validatedCount validés',
                      style: AppTypography.labelMedium(color: AppColors.success).copyWith(fontSize: 11)),
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
                            return _buildRestaurantCard(restaurant, user);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, _RestaurantStatus status, {int? count}) {
    final selected = filterStatus == status;
    return GestureDetector(
      onTap: () => setState(() => filterStatus = status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandSurface : AppColors.card,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.brand : AppColors.inkMuted,
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? AppColors.brand.withValues(alpha: 0.15) : AppColors.surfaceWarm,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text('$count',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? AppColors.brand : AppColors.inkSubtle)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _roleBadge(int roleID) {
    final role = AppRole.fromId(roleID);
    if (role == AppRole.microRestaurant) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text('Propriétaire',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.inkMuted)),
      );
    }
    return const SizedBox.shrink();
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
                  _roleBadge(user.roleID),
                  const SizedBox(width: 4),
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
