import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:dios_delices/Screen/Cart.dart';
import 'package:dios_delices/Screen/Favorites.dart';
import 'package:dios_delices/Screen/Home.dart';
import 'package:dios_delices/Screen/Menu.dart';
import 'package:dios_delices/Screen/MyStore.dart';
import 'package:flutter/material.dart';

class CurvedNavigation extends StatefulWidget {
  final int specified_index;

  CurvedNavigation({required this.specified_index});

  @override
  _CurvedNavigationState createState() => _CurvedNavigationState();
}

class _CurvedNavigationState extends State<CurvedNavigation> {
  late PageController _pageController;

  List<String> _options = [
    "HOME",
    "CART",
    "FAVORITES",
    "MENU",
    "MY STORE",
  ];
  final List<Widget> _tabItems = [
    Home(),
    Cart(),
    Favorites(),
    Menu(),
    MyStore()
  ];
  int _activePage = 0;

  int navigation_index = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: _tabItems[_activePage],
      bottomNavigationBar: CurvedNavigationBar(
        buttonBackgroundColor: Colors.white,
        backgroundColor: Colors.red,
        animationDuration: Duration(seconds: 1),
        animationCurve: Curves.bounceOut,
        items: <Widget>[
          Icon(
            Icons.home,
            color: Colors.red,
          ),
          Icon(
            Icons.shopping_cart,
            color: Colors.red,
          ),
          Icon(
            Icons.favorite,
            color: Colors.red,
          ),
          Icon(
            Icons.playlist_add_check,
            color: Colors.red,
          ),
          Icon(
            Icons.storefront,
            color: Colors.red,
          ),
        ],
        onTap: (index) {
          setState(() {
            _activePage = index;

            if (index == 0) {
            } else if (index == 2) {
            } else if (index == 3) {
            } else if (index == 4) {
            } else if (index == 5) {}
          });
        },
      ),
    );
  }
}
