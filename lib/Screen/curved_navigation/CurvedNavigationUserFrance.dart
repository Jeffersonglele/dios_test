import 'package:flutter/material.dart';
import '../../widgets/dios_nav_bar.dart';
import '../../theme/app_theme.dart';
import '../HomeUser.dart';
import '../Cart.dart';
import '../Favorites.dart';
import '../Menu.dart';
import '../MyStore.dart';

class CurvedNavigationUserFrance extends StatefulWidget {
  final int specified_index;
  const CurvedNavigationUserFrance({super.key, required this.specified_index});

  @override
  State<CurvedNavigationUserFrance> createState() =>
      _CurvedNavigationUserFranceState();
}

class _CurvedNavigationUserFranceState
    extends State<CurvedNavigationUserFrance> {
  late PageController _pageController;
  int _activePage = 0;

  final _pages = <Widget>[
    HomeUser(),
    Cart(),
    Favorites(),
    Menu(),
    MyStore(),
  ];

  final _navItems = <DiosNavItem>[
    DiosNavItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'Accueil',
    ),
    DiosNavItem(
      icon: Icon(Icons.shopping_cart_outlined),
      activeIcon: Icon(Icons.shopping_cart),
      label: 'Panier',
    ),
    DiosNavItem(
      icon: Icon(Icons.favorite_border),
      activeIcon: Icon(Icons.favorite),
      label: 'Favoris',
    ),
    DiosNavItem(
      icon: Icon(Icons.menu_book_outlined),
      activeIcon: Icon(Icons.menu_book),
      label: 'Menu',
    ),
    DiosNavItem(
      icon: Icon(Icons.store_outlined),
      activeIcon: Icon(Icons.store),
      label: 'Boutique',
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _activePage = index),
        children: _pages,
      ),
      bottomNavigationBar: DiosNavBar(
        currentIndex: _activePage,
        items: _navItems,
        onTap: (index) {
          setState(() => _activePage = index);
          _pageController.jumpToPage(index);
        },
      ),
    );
  }
}
