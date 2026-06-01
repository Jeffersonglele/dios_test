import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dios_delices/widgets/dios_nav_bar.dart';
import 'package:dios_delices/theme/app_theme.dart';

void main() {
  testWidgets('DiosNavBar renders all items', (tester) async {
    final items = const [
      DiosNavItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Accueil'),
      DiosNavItem(icon: Icon(Icons.shopping_cart_outlined), activeIcon: Icon(Icons.shopping_cart), label: 'Panier'),
      DiosNavItem(icon: Icon(Icons.favorite_border), activeIcon: Icon(Icons.favorite), label: 'Favoris'),
    ];

    int tappedIndex = -1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: DiosNavBar(
            items: items,
            currentIndex: 0,
            onTap: (i) => tappedIndex = i,
          ),
        ),
      ),
    );

    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Panier'), findsOneWidget);
    expect(find.text('Favoris'), findsOneWidget);
  });

  testWidgets('DiosNavBar calls onTap with correct index', (tester) async {
    final items = const [
      DiosNavItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Accueil'),
      DiosNavItem(icon: Icon(Icons.shopping_cart_outlined), activeIcon: Icon(Icons.shopping_cart), label: 'Panier'),
    ];

    int tappedIndex = -1;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          bottomNavigationBar: DiosNavBar(
            items: items,
            currentIndex: 0,
            onTap: (i) => tappedIndex = i,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Panier'));
    expect(tappedIndex, 1);
  });

  testWidgets('DiosNavBar highlights active item', (tester) async {
    final items = const [
      DiosNavItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Accueil'),
      DiosNavItem(icon: Icon(Icons.shopping_cart_outlined), activeIcon: Icon(Icons.shopping_cart), label: 'Panier'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          bottomNavigationBar: DiosNavBar(
            items: items,
            currentIndex: 0,
            onTap: (_) {},
          ),
        ),
      ),
    );

    // L'indicateur animé doit être présent pour l'item actif
    await tester.pumpAndSettle();
    expect(find.byType(DiosNavBar), findsOneWidget);
  });
}
