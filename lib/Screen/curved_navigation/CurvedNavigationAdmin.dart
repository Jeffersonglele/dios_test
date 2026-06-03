import 'package:flutter/material.dart';
import '../../widgets/dios_nav_bar.dart';
import '../../theme/app_theme.dart';
import '../admin/AdminDashboard.dart';
import '../Settings.dart';

class CurvedNavigationAdmin extends StatefulWidget {
  final int specified_index;
  const CurvedNavigationAdmin({super.key, required this.specified_index});

  @override
  State<CurvedNavigationAdmin> createState() => _CurvedNavigationAdminState();
}

class _CurvedNavigationAdminState extends State<CurvedNavigationAdmin> {
  late PageController _pageController;
  int _activePage = 0;

  final _pages = <Widget>[
    const AdminDashboard(),
    const Settings(),
  ];

  final _navItems = <DiosNavItem>[
    DiosNavItem(
      icon: const Icon(Icons.dashboard_outlined),
      activeIcon: const Icon(Icons.dashboard_rounded),
      label: 'Dashboard',
    ),
    DiosNavItem(
      icon: const Icon(Icons.settings_outlined),
      activeIcon: const Icon(Icons.settings_rounded),
      label: 'Paramètres',
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
