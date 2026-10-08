import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/dios_nav_bar.dart';
import '../../theme/app_theme.dart';
import '../home/home_user.dart';
import '../cart/cart.dart';
import '../favorites/favorites.dart';
import '../store/my_store.dart';
import '../../providers/cart_provider.dart';

class CurvedNavigationUser extends ConsumerStatefulWidget {
  final int specified_index;
  final String country;
  const CurvedNavigationUser(
      {super.key, required this.specified_index, this.country = 'RDC'});

  @override
  ConsumerState<CurvedNavigationUser> createState() =>
      _CurvedNavigationUserState();
}

class _CurvedNavigationUserState extends ConsumerState<CurvedNavigationUser> {
  late PageController _pageController;
  int _activePage = 0;

  final _pages = const [
    HomeUser(),
    Cart(),
    Favorites(),
    MyStore(),
  ];

  final _navItems = <DiosNavItem>[
    DiosNavItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'Accueil',
      iosSystemName: 'house.fill',
    ),
    DiosNavItem(
      icon: Icon(Icons.shopping_cart_outlined),
      activeIcon: Icon(Icons.shopping_cart),
      label: 'Panier',
      iosSystemName: 'cart.fill',
    ),
    DiosNavItem(
      icon: Icon(Icons.favorite_border),
      activeIcon: Icon(Icons.favorite),
      label: 'Favoris',
      iosSystemName: 'heart.fill',
    ),
    DiosNavItem(
      icon: Icon(Icons.store_outlined),
      activeIcon: Icon(Icons.store),
      label: 'Profil',
      iosSystemName: 'storefront.fill',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _activePage = widget.specified_index;
    _pageController = PageController(initialPage: _activePage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartStateProvider);
    final basketCount = cartItems
        .map((item) =>
            (item['restaurant'] as Map<String, dynamic>?)?['restau_id']
                ?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_activePage != 0) {
          setState(() => _activePage = 0);
          _pageController.jumpToPage(0);
          return;
        }
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop();
        }
      },
      child: Scaffold(
        backgroundColor:
            AppColors.resolve(AppColors.surface, AppDarkColors.surface),
        body: SafeArea(
            child: PageView(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _activePage = index),
          children: _pages,
        )),
        bottomNavigationBar: DiosNavBar(
          currentIndex: _activePage,
          items: _navItems,
          badges: {if (basketCount > 0) 1: basketCount},
          onTap: (index) {
            setState(() => _activePage = index);
            _pageController.jumpToPage(index);
          },
        ),
      ),
    );
  }
}
