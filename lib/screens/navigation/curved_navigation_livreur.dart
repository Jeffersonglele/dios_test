import 'package:flutter/material.dart';
import '../../widgets/dios_nav_bar.dart';
import '../../theme/app_theme.dart';
import '../delivery/delivery_dashboard.dart';
import '../delivery/livreur_map_page.dart';
import '../store/my_store.dart';
import '../onboarding/courier_onboarding_page.dart';
import '../onboarding/wait_identity_validation.dart';
import '../../services/courier_application_service.dart';
import '../../services/session_service.dart';

class CurvedNavigationLivreur extends StatefulWidget {
  final int specified_index;
  const CurvedNavigationLivreur({super.key, this.specified_index = 0});

  @override
  State<CurvedNavigationLivreur> createState() =>
      _CurvedNavigationLivreurState();
}

class _CurvedNavigationLivreurState extends State<CurvedNavigationLivreur> {
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
    _checkCourierFile();
  }

  /// Un livreur dont le dossier n'est pas validé (ou un ancien compte sans
  /// photo) est renvoyé vers son dossier : le serveur refuse ses courses.
  Future<void> _checkCourierFile() async {
    final state = await SessionService.fetchServerAccountState();
    if (!mounted || state == null) return;
    if (CourierApplicationService.isVerified(state.identity)) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => CourierApplicationService.isPending(state.identity)
            ? const WaitIdentityValidation()
            : const CourierOnboardingPage(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          AppColors.resolve(AppColors.surface, AppDarkColors.surface),
      body: SafeArea(
        // IndexedStack (et non PageView) : les onglets restent montés. Le
        // tableau de bord gère le statut en ligne et le partage GPS ; avec un
        // PageView il était détruit dès qu'on changeait d'onglet, ce qui
        // coupait le partage de position sans action du livreur.
        child: IndexedStack(index: _activePage, children: _pages),
      ),
      bottomNavigationBar: DiosNavBar(
        currentIndex: _activePage,
        items: _navItems,
        onTap: (index) => setState(() => _activePage = index),
      ),
    );
  }
}
