import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dios_delices/widgets/micro_interactions.dart';
import 'package:dios_delices/theme/app_theme.dart';

void main() {
  testWidgets('AnimatedLikeButton toggles state', (tester) async {
    bool liked = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: AnimatedLikeButton(
              isLiked: liked,
              onTap: () => liked = !liked,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
  });

  testWidgets('AnimatedLikeButton shows filled when liked', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: AnimatedLikeButton(
              isLiked: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });

  testWidgets('AddToCartBounce renders child', (tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: AddToCartBounce(
              onTap: () => tapped = true,
              child: const Text('Ajouter'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Ajouter'), findsOneWidget);
  });
}
