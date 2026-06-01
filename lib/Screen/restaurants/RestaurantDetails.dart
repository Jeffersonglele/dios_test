import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:path/path.dart' as p;

import '../../Constant/Constant.dart';
import '../../modeles/dish.dart';
import '../../modeles/restaurant.dart';
import '../../providers/cart_provider.dart' as cartP;
import '../../services/favorites_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/micro_interactions.dart';
import '../../utils/stars.dart';
import '../../utils/toast.dart';
import '../micro_restau/DishDetailsMicroRestau.dart';
import '../../widgets/comment_section.dart';

class RestaurantDetails extends ConsumerStatefulWidget {
  final int restaurant_id;
  const RestaurantDetails({super.key, required this.restaurant_id});

  @override
  ConsumerState<RestaurantDetails> createState() => _RestaurantDetailsState();
}

class _RestaurantDetailsState extends ConsumerState<RestaurantDetails> {
  final _formKey = GlobalKey<FormState>();
  int currentUser_restau = 0;
  int currentUser_role = 0;
  int currentUser_id = 0;
  String currentUser_country = "";
  bool restau_de_luser_connecte = false;
  bool isFavorite = false;
  bool isEditMode = false;
  File? selectedImage;
  final ImagePicker _picker = ImagePicker();

  late TextEditingController nameCtrl, descCtrl, nbOrdersCtrl, noteCtrl;
  late TextEditingController catCtrl, hoursCtrl, feeCtrl;

  List<String> _selectedHashtags = [];
  List<Dish> dishes = [];
  Restaurant? current_restaurant;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController();
    descCtrl = TextEditingController();
    nbOrdersCtrl = TextEditingController();
    noteCtrl = TextEditingController();
    catCtrl = TextEditingController();
    hoursCtrl = TextEditingController();
    feeCtrl = TextEditingController();
    loadData();
  }

  @override
  void dispose() {
    nameCtrl.dispose(); descCtrl.dispose(); nbOrdersCtrl.dispose();
    noteCtrl.dispose(); catCtrl.dispose(); hoursCtrl.dispose(); feeCtrl.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    try {
      final session = await SessionService.readSession();
      currentUser_role = session.role.id;
      currentUser_country = session.country;
      currentUser_id = session.userId;

      final restaurantsList = await Restaurant.fetchRestaurantsFromDB();
      final restaurant = Restaurant.getRestaurantByRestaurantId(restaurantsList, widget.restaurant_id);
      final allDishes = await Dish.fetchDishesFromDB();
      final filtered = allDishes.where((d) => d.restauID == widget.restaurant_id).toList();

      if (!mounted) return;
      setState(() {
        currentUser_restau = session.restaurantId ?? 0;
        current_restaurant = restaurant;
        dishes = filtered;
        restau_de_luser_connecte = currentUser_restau == restaurant?.restaurantID;

        if (restaurant != null) {
          nameCtrl.text = restaurant.name ?? '';
          descCtrl.text = restaurant.description ?? '';
          nbOrdersCtrl.text = restaurant.nb_orders.toString();
          noteCtrl.text = restaurant.note.toString();
          catCtrl.text = restaurant.categories ?? '';
          hoursCtrl.text = restaurant.openingHours;
          feeCtrl.text = restaurant.deliveryFee.toStringAsFixed(2);
          _selectedHashtags = restaurant.categories?.split(', ') ?? [];
        }
      });

      if (restaurant != null) {
        final fav = await FavoritesService.isRestaurantFavorite(restaurant.restaurantID);
        if (!mounted) return;
        setState(() => isFavorite = fav);
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    if (current_restaurant == null) return;
    final next = await FavoritesService.toggleRestaurantFavorite(current_restaurant!.restaurantID);
    if (mounted) setState(() => isFavorite = next);
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => selectedImage = File(image.path));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    if (current_restaurant == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final isOwner = currentUser_role == 1 || currentUser_role == 4 || restau_de_luser_connecte;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: CustomScrollView(
          slivers: [
            // ── Image parallaxe ──────────────────────────
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.card.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, size: 20),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                if (!restau_de_luser_connecte)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: AnimatedLikeButton(
                      isLiked: isFavorite,
                      size: 22,
                      onTap: _toggleFavorite,
                    ),
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      (current_restaurant!.image != null && current_restaurant!.image!.trim().isNotEmpty)
                          ? current_restaurant!.image!
                          : '',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset('assets/images/no_image.png', fit: BoxFit.cover),
                    ),
                    // Overlay dégradé bas
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              AppColors.ink.withValues(alpha: 0.6),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(0),
                child: Container(
                  height: 24,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
                  ),
                ),
              ),
            ),
            // ── Contenu ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Nom + statut
                  Row(children: [
                    Expanded(
                      child: Text(current_restaurant!.name ?? '', style: AppTypography.headlineMedium()),
                    ),
                    // Badge ouvert/fermé
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (current_restaurant!.isOpen == 1 ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(current_restaurant!.isOpen == 1 ? 'Ouvert' : 'Fermé',
                          style: TextStyle(
                            color: current_restaurant!.isOpen == 1 ? AppColors.success : AppColors.error,
                            fontSize: 12, fontWeight: FontWeight.w700,
                          )),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  // Note étoiles
                  Row(children: [
                    StarRating(rating: double.tryParse(noteCtrl.text) ?? 0),
                    const SizedBox(width: 6),
                    Text('${noteCtrl.text}/5', style: AppTypography.bodyMedium()),
                    const SizedBox(width: 16),
                    const Icon(Icons.access_time_rounded, color: AppColors.inkSubtle, size: 16),
                    const SizedBox(width: 4),
                    Text(current_restaurant!.openingHours, style: AppTypography.bodyMedium()),
                  ]),
                  const SizedBox(height: 12),
                  // Description
                  Text(current_restaurant!.description ?? '', style: AppTypography.bodyLarge()),
                  const SizedBox(height: 16),
                  // Catégories
                  if (catCtrl.text.isNotEmpty)
                    Wrap(spacing: 8, runSpacing: 8, children: catCtrl.text.split(', ').map((h) =>
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.brandSurface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Text(h, style: AppTypography.labelMedium(color: AppColors.brand).copyWith(fontSize: 12)),
                      ),
                    ).toList()),
                  const SizedBox(height: 24),

                  // ── MENU ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWarm,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(children: [
                      Text('Menu', style: AppTypography.titleMedium()),
                      const SizedBox(width: 8),
                      Text('${dishes.length} plats', style: AppTypography.bodyMedium()),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  ...dishes.map((dish) => _buildDishItem(dish)),
                  const SizedBox(height: 24),

                  // ── Avis ──────────────────────────────
                  if (currentUser_role == 2 && current_restaurant != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWarm,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Text('Avis', style: AppTypography.titleMedium()),
                    ),
                    const SizedBox(height: 12),
                    CommentSection(targetType: 1, targetID: widget.restaurant_id),
                  ],

                  // ── Boutons admin ─────────────────────
                  if (isOwner) ...[
                    const SizedBox(height: 24),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (isEditMode)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                nameCtrl.text = current_restaurant?.name ?? '';
                                descCtrl.text = current_restaurant?.description ?? '';
                                hoursCtrl.text = current_restaurant?.openingHours ?? '';
                                feeCtrl.text = current_restaurant?.deliveryFee.toStringAsFixed(2) ?? '0';
                                isEditMode = false;
                              });
                            },
                            child: const Text('Annuler'),
                          ),
                        ),
                      ElevatedButton(
                        onPressed: () async {
                          if (isEditMode && _formKey.currentState?.validate() == true) {
                            final result = await Restaurant.manageRestaurant(
                              restaurantID: current_restaurant!.restaurantID,
                              userID: currentUser_id,
                              categories: _selectedHashtags.join(', '),
                              description: descCtrl.text,
                              location: current_restaurant!.location ?? '',
                              name: nameCtrl.text,
                              note: double.tryParse(noteCtrl.text) ?? 0,
                              nb_orders: current_restaurant!.nb_orders,
                              valid: current_restaurant!.valid,
                              openingHours: hoursCtrl.text.trim(),
                              deliveryFee: double.tryParse(feeCtrl.text.replaceAll(',', '.')) ?? 0,
                              isOpen: current_restaurant!.isOpen,
                              date_creation: current_restaurant?.date_creation,
                              image: selectedImage != null
                                  ? ParseFile(File(selectedImage!.path),
                                      name: '${nameCtrl.text}_${currentUser_id}${p.extension(selectedImage!.path)}')
                                  : null,
                              img_url: current_restaurant?.image,
                            );
                            if (result == "success") {
                              Toast(context, "Restaurant mis à jour", true);
                              await loadData();
                            } else {
                              Toast(context, "Erreur : $result", false);
                            }
                          }
                          setState(() => isEditMode = !isEditMode);
                        },
                        child: Text(isEditMode ? 'Valider' : 'Modifier'),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDishItem(Dish dish) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => DishDetailsMicroRestau(dish_id: dish.dishID, from_page: 1, dish_restau: widget.restaurant_id))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Image.network(
              dish.image ?? '',
              width: 72, height: 72, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 72, height: 72,
                color: AppColors.surfaceWarm,
                child: const Icon(Icons.restaurant_rounded, color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dish.name ?? '', style: AppTypography.labelMedium()),
              const SizedBox(height: 4),
              Text(dish.description ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium()),
              const SizedBox(height: 4),
              Text('${dish.price?.toStringAsFixed(2)} ${currentUser_country == 'France' ? '€' : 'FCFA'}',
                  style: AppTypography.bodyLarge(color: AppColors.brand)),
            ]),
          ),
        ]),
      ),
    );
  }
}
