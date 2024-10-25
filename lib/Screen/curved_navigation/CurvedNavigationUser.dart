import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../Home.dart';
import '../Cart.dart';
import '../Favorites.dart';
import '../Menu.dart';
import '../MyStore.dart';

class CurvedNavigationRestau extends StatefulWidget {
  final int specified_index;

  CurvedNavigationRestau({required this.specified_index});

  @override
  _CurvedNavigationRestauState createState() => _CurvedNavigationRestauState();
}

class _CurvedNavigationRestauState extends State<CurvedNavigationRestau> {
  late PageController _pageController;

  List<Widget> _allTabItems = [
    Home(),
    Cart(),
    Favorites(),
    Menu(),
    MyStore(),
  ];

  int _activePage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.specified_index);
    _activePage = widget.specified_index;
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
              });
            },
          ),
        ),
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _activePage = index; // Met à jour l'index actif lorsque la page change
            });
          },
          children: _allTabItems, // Les pages à afficher pour les restaurateurs
        ),
        bottomNavigationBar: CurvedNavigationBar(
          height: 60.0, // Ajustez la hauteur de la barre de navigation
          index: _activePage,
          buttonBackgroundColor: Colors.white,
          backgroundColor: Colors.red,
          animationDuration: Duration(milliseconds: 300),
          animationCurve: Curves.easeInOut,
          items: <Widget>[
            Icon(Icons.home, color: Colors.red),
            Icon(Icons.shopping_cart, color: Colors.red),
            Icon(Icons.favorite, color: Colors.red),
            Icon(Icons.playlist_add_check, color: Colors.red),
            Icon(Icons.storefront, color: Colors.red),
          ],
          onTap: (index) {
            setState(() {
              _activePage = index;
              _pageController.jumpToPage(index); // Change la page quand l'utilisateur tape sur un bouton
            });
          },
        ),
      ),
    );
  }
}
