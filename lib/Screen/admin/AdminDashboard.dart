import 'package:dios_delices/Screen/restaurants/RestaurantListPage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Controller/UiController.dart';
import '../../utils/DateTime.dart';
import '../CountryPage.dart';

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  SimpleUIController simpleUIController = Get.put(SimpleUIController());

  int _userRole = 0; // Initialiser le rôle de l'utilisateur à 0
  String _userCountry = "France";

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  // Fonction pour charger le rôle de l'utilisateur
  Future<void> _loadUserRole() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getInt('currentUser_role') ?? 0;
      _userCountry = prefs.getString('currentUser_country') ?? "France";
    });
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    var theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async => false,
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: false,
          body: SingleChildScrollView(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  return _buildLargeScreen(size, simpleUIController, theme);
                } else {
                  return _buildSmallScreen(size, simpleUIController, theme);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  // Pour les grands écrans
  Widget _buildLargeScreen(
      Size size, SimpleUIController simpleUIController, ThemeData theme) {
    return Row(
      children: [
        SizedBox(width: size.width * 0.06),
        Expanded(
          flex: 5,
          child: _buildMainBody(size, simpleUIController, theme),
        ),
      ],
    );
  }

  // Pour les petits écrans
  Widget _buildSmallScreen(
      Size size, SimpleUIController simpleUIController, ThemeData theme) {
    return Center(
      child: _buildMainBody(size, simpleUIController, theme),
    );
  }

  // Contenu principal du tableau de bord
  Widget _buildMainBody(
      Size size, SimpleUIController simpleUIController, ThemeData theme) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
        size.width > 600 ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          SizedBox(height: size.height * 0.02),
          // Date et heure actuelles
          DateTimeDisplay(),
          SizedBox(height: size.height * 0.03),

          // Section Utilisateurs
          _buildSection(
            size: size,
            sectionTitle: "Utilisateurs",
            onTap: () {
              // Redirige vers la page des pays pour les utilisateurs
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => CountryPage(sectionType: "utilisateurs"),
                ),
              );
            },
            onAddTap: () {
              // Logique pour ajouter un utilisateur
            },
          ),
          SizedBox(height: size.height * 0.03),

          // Section Restaurants
          _buildSection(
            size: size,
            sectionTitle: "Restaurants",
            onTap: () {
              // Redirige vers la page des pays pour les restaurants
              // un super admin peut voir les restaus de tous les pays
              if(_userRole == 4){
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => CountryPage(sectionType: "restaurants"),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RestaurantListPage(country: _userCountry),
                  ),
                );
              }
            },
            onAddTap: () {
              // Logique pour ajouter un restaurant
            },
          ),
          SizedBox(height: size.height * 0.03),

          // Section Administrateurs (si roleID == 4)
          if (_userRole == 4) ...[
            _buildSection(
              size: size,
              sectionTitle: "Administrateurs",
              onTap: () {
                // Redirige vers la page des administrateurs
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) =>
                        CountryPage(sectionType: "administrateurs"),
                  ),
                );
              },
              onAddTap: () {
                // Logique pour ajouter un administrateur
              },
            ),
          ],
        ]);
  }

  // Méthode pour créer une section dans le dashboard
  Widget _buildSection({
    required Size size,
    required String sectionTitle,
    required VoidCallback onTap,
    required VoidCallback onAddTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            spreadRadius: 3,
            blurRadius: 7,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Text(
              sectionTitle,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          GestureDetector(
            onTap: onAddTap,
            child: CircleAvatar(
              radius: 15,
              backgroundColor: Colors.green,
              child: Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
