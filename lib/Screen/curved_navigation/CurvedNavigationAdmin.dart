import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../AdminDashboard.dart';
import '../MyStore.dart';

class CurvedNavigationAdmin extends StatefulWidget {
  final int specified_index;

  CurvedNavigationAdmin({required this.specified_index});

  @override
  _CurvedNavigationAdminState createState() => _CurvedNavigationAdminState();
}

class _CurvedNavigationAdminState extends State<CurvedNavigationAdmin> {
  late PageController _pageController;

  List<Widget> _adminTabs = [
    AdminDashboard(),
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
          children: _adminTabs, // Les pages à afficher pour les admins
        ),
        bottomNavigationBar: CurvedNavigationBar(
          height: 60.0, // Ajustez la hauteur de la barre de navigation
          index: _activePage,
          buttonBackgroundColor: Colors.white,
          backgroundColor: Colors.red,
          animationDuration: Duration(milliseconds: 300),
          animationCurve: Curves.easeInOut,
          items: [
            Icon(Icons.dashboard, color: Colors.red), // Admin Dashboard
            Icon(Icons.storefront, color: Colors.red), // My Store
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
