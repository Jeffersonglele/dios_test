import 'package:flutter/material.dart';
import '../../widgets/dios_nav_bar.dart';
import '../../theme/app_theme.dart';
import '../delivery/delivery_dashboard.dart';
import '../delivery/livreur_map_page.dart';
import '../store/my_store.dart';

class CurvedNavigationLivreur extends StatefulWidget {
  final int specified_index;
  const CurvedNavigationLivreur({super.key, this.specified_index = 0});

  @override
  State<CurvedNavigationLivreur> createState() =>
      _CurvedNavigationLivreurState();
}

class _CurvedNavigationLivreurState extends State<CurvedNavigationLivreur> {
  late PageController _pageController;
  int _activePage = 0;

  final _pages = const [
    LivreurMapPage(),
    DeliveryDashboard(),
    MyStore(),
  ];

  final _navItems = <DiosNavItem>[
    DiosNavItem(
      icon: Icon(Icons.map_outlined),
      activeIcon: Icon(Icons.map),
      label: 'Carte',
      iosSystemName: 'map.fill',
    ),
    DiosNavItem(
      icon: Icon(Icons.delivery_dining_outlined),
      activeIcon: Icon(Icons.delivery_dining),
      label: 'Livraisons',
      iosSystemName: 'shippingbox.fill',
    ),
    DiosNavItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profil',
      iosSystemName: 'person.fill',
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
      backgroundColor:
          AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _activePage = index),
          children: _pages,
        ),
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
