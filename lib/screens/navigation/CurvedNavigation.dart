/*import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'AdminDashboard.dart';
import 'Cart.dart';
import 'Favorites.dart';
import 'HomeUser.dart';
import 'Menu.dart';
import 'MyStore.dart';

class CurvedNavigation extends StatefulWidget {
  final int specified_index;

  CurvedNavigation({required this.specified_index});

  @override
  _CurvedNavigationState createState() => _CurvedNavigationState();
}

class _CurvedNavigationState extends State<CurvedNavigation> {
  late PageController _pageController;

  List<Widget> _tabItems = [];
  List<Widget> _allTabItems = [
    Home(),
    Cart(),
    Favorites(),
    Menu(),
    MyStore(),
  ];
  List<Widget> _adminTabs = [
    AdminDashboard(),
    MyStore(),
  ];

  int _activePage = 0;
  int _navigationIndex = 0;
  int _userRole = 0; // Par défaut

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadUserRole();
  }

  // Récupérer le rôle de l'utilisateur à partir des SharedPreferences
  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getInt('currentUser_role') ?? 0;

      if (_userRole == 1) {
        // Si administrateur, ne montrer que les pages Admin
        _tabItems = _adminTabs;
        _navigationIndex = 0;  // Réinitialiser l'index de navigation
      } else {
        // Sinon, montrer toutes les pages
        _tabItems = _allTabItems;
        _navigationIndex = widget.specified_index; // Index initial basé sur l'argument
      }

      // Initialiser le PageController avec l'index spécifié
      _pageController = PageController(initialPage: _navigationIndex);
      _activePage = _navigationIndex;
    });
  }

  @override
  void dispose() {
    _pageController.dispose(); // Dispose du controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.home), // Icône personnalisée (ex: home)
            onPressed: () {
              setState(() {
                _activePage = 0; // Change l'index pour revenir à la page 1 (Home)
                _pageController.jumpToPage(0); // Synchroniser avec le PageController
                _navigationIndex = 0; // Mise à jour de l'index de la navigation
              });
            },
          ),
        ),
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _activePage = index; // Met à jour l'index actif lorsque la page change
              _navigationIndex = index; // Met à jour l'index de navigation
            });
          },
          children: _tabItems, // Les pages à afficher
        ),
        bottomNavigationBar: CurvedNavigationBar(
          height: 60.0, // Ajustez la hauteur de la barre de navigation
          index: _navigationIndex,
          buttonBackgroundColor: Colors.white,
          backgroundColor: Colors.red,
          animationDuration: Duration(milliseconds: 300),
          animationCurve: Curves.easeInOut,
          items: _userRole == 1
              ? [
            Icon(Icons.dashboard, color: Colors.red),
            Icon(Icons.storefront, color: Colors.red)
          ] // Icônes pour Admin (2 éléments)
              : <Widget>[
            Icon(Icons.home, color: Colors.red),
            Icon(Icons.shopping_cart, color: Colors.red),
            Icon(Icons.favorite, color: Colors.red),
            Icon(Icons.playlist_add_check, color: Colors.red),
            Icon(Icons.storefront, color: Colors.red),
          ], // Icônes pour utilisateur régulier (5 éléments)
          onTap: (index) {
            // S'assurer que l'index n'est pas supérieur au nombre d'items disponibles
            if (_userRole == 1 && index > 1) return; // Limiter à 2 pour admin
            setState(() {
              _activePage = index;
              _pageController.jumpToPage(index); // Change la page
              _navigationIndex = index; // Met à jour l'index de la navigation
            });
          },
        ),
      ),
    );
  }
}*/
