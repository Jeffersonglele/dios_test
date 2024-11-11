import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:dios_delices/Screen/HomeUser.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../Cart.dart';
import '../Favorites.dart';
import '../MyStore.dart';

class CurvedNavigationUserAfr extends StatefulWidget {
  final int specified_index;

  CurvedNavigationUserAfr({required this.specified_index});

  @override
  _CurvedNavigationUserAfrState createState() => _CurvedNavigationUserAfrState();
}

class _CurvedNavigationUserAfrState extends State<CurvedNavigationUserAfr> {
  late PageController _pageController;

  List<Widget> _allTabItems = [
    HomeUser(),
    Cart(),
    Favorites(),
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
