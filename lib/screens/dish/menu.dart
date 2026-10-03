import 'package:dios_delices/screens/dish/dish_form_page.dart';
import 'package:dios_delices/models/dish.dart';
import 'package:dios_delices/services/currency_service.dart';
import 'package:dios_delices/services/session_service.dart';
import 'package:dios_delices/theme/app_theme.dart';
import 'package:dios_delices/l10n/app_localizations.dart';
import '../../utils/currency_util.dart';
import '../../widgets/dios_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../dish/dish_details.dart';

class Menu extends StatefulWidget {
  const Menu({super.key});
  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  String? country = "";
  int currentUserRestau = 0;
  int currentUserRole = 0;
  List<Dish> dishes = [];
  List<Dish> filteredDishes = [];
  List<Dish> displayedDishes = [];

  /// Le skeleton n'apparaît qu'au premier chargement.
  /// Les rechargements suivants (retour de la fiche plat, pull-to-refresh)
  /// se font en silence, sans clignotement.
  bool _isLoading = true;
  bool _hasLoaded = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    if (!mounted) return;
    if (!_hasLoaded) setState(() => _isLoading = true);
    try {
      final session = await SessionService.readSession();
      country = session.country;
      currentUserRestau = session.restaurantId ?? 0;
      currentUserRole = session.role.id;
      await Dish.getAllDishesDetails();
      final dishesList = await Dish.fetchDishesFromDB();
      if (mounted) {
        setState(() {
          dishes = dishesList;
          filteredDishes =
              dishes.where((d) => d.restauID == currentUserRestau).toList();
          _filterDishes(_searchController.text);
          _isLoading = false;
          _hasLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterDishes(String query) {
    if (query.isEmpty) {
      displayedDishes = List.from(filteredDishes);
    } else {
      displayedDishes = filteredDishes
          .where((dish) =>
              (dish.name ?? '').toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  }

  void _openDishForm() {
    Navigator.push(context, CupertinoPageRoute(builder: (_) => DishFormPage()))
        .then((_) => loadData());
  }

  SliverGridDelegate _gridDelegate(bool isWide) =>
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 3 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      );

  static const _gridPadding = EdgeInsets.fromLTRB(16, 4, 16, 100);

  // ─────────────────────────── BUILD ───────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isWide = MediaQuery.of(context).size.width > 600;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor:
            AppColors.resolve(AppColors.surface, AppDarkColors.surface),
        body: SafeArea(
          child: Column(children: [
            _buildHeader(l10n),
            _buildSearchBar(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOut,
                child: _isLoading
                    ? _buildSkeleton(isWide)
                    : _buildContent(l10n, isWide),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────── HEADER ───────────────────────────

  Widget _buildHeader(AppLocalizations l10n) {
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.menu,
                style: AppTypography.headlineLarge(
                    color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
            const SizedBox(height: 2),
            // Pendant le chargement on réserve la hauteur pour éviter un saut de layout.
            _isLoading
                ? const SizedBox(height: 20)
                : Text('${displayedDishes.length} ${l10n.dishes}',
                    style: AppTypography.bodyMedium(
                        color: AppColors.resolve(
                            AppColors.inkMuted, AppDarkColors.inkMuted))),
          ]),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: brand,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: [
              BoxShadow(
                  color: brand.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: _openDishForm,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildSearchBar() {
    final muted = AppColors.resolve(AppColors.inkMuted, AppDarkColors.inkMuted);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.resolve(AppColors.card, AppDarkColors.card),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: AppColors.resolve(AppColors.border, AppDarkColors.border),
              width: 0.5),
        ),
        child: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _filterDishes(value)),
          style: AppTypography.bodyMedium(
              color: AppColors.resolve(AppColors.ink, AppDarkColors.ink)),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: MaterialLocalizations.of(context).searchFieldLabel,
            hintStyle: AppTypography.bodyMedium(
                color: AppColors.resolve(
                    AppColors.inkSubtle, AppDarkColors.inkSubtle)),
            prefixIcon: Icon(Icons.search_rounded, color: muted),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close_rounded, color: muted, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _filterDishes(''));
                    },
                  ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── CONTENU ───────────────────────────

  Widget _buildContent(AppLocalizations l10n, bool isWide) {
    if (displayedDishes.isEmpty) {
      return KeyedSubtree(
          key: const ValueKey('empty'), child: _buildEmptyState(l10n));
    }

    return RefreshIndicator(
      key: const ValueKey('grid'),
      color: AppColors.resolve(AppColors.brand, AppDarkColors.brand),
      onRefresh: loadData,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: _gridPadding,
        gridDelegate: _gridDelegate(isWide),
        itemCount: displayedDishes.length,
        itemBuilder: (context, i) => _buildDishCard(displayedDishes[i]),
      ),
    );
  }

  Widget _buildDishCard(Dish dish) {
    final curr = CurrencyUtil.symbol(CurrencyUtil.code(country ?? ''));
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);
    final radius = BorderRadius.circular(AppRadius.xl);

    return Material(
      color: AppColors.resolve(AppColors.card, AppDarkColors.card),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
            color: AppColors.resolve(AppColors.border, AppDarkColors.border),
            width: 0.5),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          CupertinoPageRoute(
              builder: (_) => DishDetails(from_page: 2, dish_id: dish.dishID)),
        ).then((_) => loadData()),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Stack(children: [
              Positioned.fill(
                child: DiosImage(url: dish.image, fit: BoxFit.cover),
              ),
              // Le prix est posé sur l'image : l'info clé se lit au premier coup d'œil.
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: brand,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 6,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: AnimatedBuilder(
                    animation: CurrencyService.instance,
                    builder: (_, __) => Text(
                      CurrencyUtil.formatConvertedPrice(
                          (dish.price ?? 0).toDouble()),
                      style: AppTypography.bodyMedium(color: Colors.white)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Text(
              dish.name ?? '',
              style: AppTypography.labelMedium(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    final isSearching = _searchController.text.isNotEmpty;
    final brand = AppColors.resolve(AppColors.brand, AppDarkColors.brand);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: brand.withValues(alpha: 0.1),
            ),
            child: Icon(
              isSearching
                  ? Icons.search_off_rounded
                  : Icons.restaurant_menu_rounded,
              size: 44,
              color: brand,
            ),
          ),
          const SizedBox(height: 20),
          Text(l10n.menu_no_dishes,
              textAlign: TextAlign.center,
              style: AppTypography.bodyLarge(
                  color: AppColors.resolve(AppColors.ink, AppDarkColors.ink))),
          // Pas de CTA si la liste est vide à cause d'une recherche.
          if (!isSearching) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _openDishForm,
              style: TextButton.styleFrom(
                foregroundColor: brand,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.menu_add_first_dish),
            ),
          ],
        ]),
      ),
    );
  }

  // ─────────────────────────── SKELETON ───────────────────────────

  /// Même grille, même padding, même ratio que la vraie page :
  /// quand les données arrivent, rien ne bouge.
  Widget _buildSkeleton(bool isWide) {
    return KeyedSubtree(
      key: const ValueKey('skeleton'),
      child: _Shimmer(
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: _gridPadding,
          gridDelegate: _gridDelegate(isWide),
          itemCount: isWide ? 9 : 6,
          itemBuilder: (_, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(child: _Bone(radius: AppRadius.xl)),
              const SizedBox(height: 10),
              const _Bone(height: 14, widthFactor: 0.75),
              const SizedBox(height: 6),
              const _Bone(height: 12, widthFactor: 0.4),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── SHIMMER ───────────────────────────

/// Bloc neutre (blanc) : c'est le [_Shimmer] parent qui le colore.
class _Bone extends StatelessWidget {
  const _Bone({this.height, this.widthFactor = 1, this.radius = 8});

  final double? height;
  final double widthFactor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Reflet lumineux qui balaye tous les enfants en même temps.
/// Aucune dépendance externe.
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});
  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = AppColors.resolve(AppColors.border, AppDarkColors.border);
    final highlight = Color.lerp(base, Colors.white, isDark ? 0.10 : 0.65)!;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) => LinearGradient(
          colors: [base, highlight, base],
          stops: const [0.35, 0.5, 0.65],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          transform: _SlideGradient(_controller.value),
        ).createShader(rect),
        child: child,
      ),
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.progress);
  final double progress;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    // progress 0 → 1 : le reflet va de la gauche hors-écran à la droite hors-écran.
    return Matrix4.translationValues(bounds.width * (progress * 2 - 1), 0, 0);
  }
}