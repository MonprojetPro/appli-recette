import 'package:appli_recette/core/widgets/recipe_photo_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecipePhotoWidget', () {
    testWidgets('shows fallback when photoUrl is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecipePhotoWidget(
              photoUrl: null,
              width: 80,
              height: 80,
            ),
          ),
        ),
      );

      // Doit afficher l'icône fallback
      expect(find.byIcon(Icons.restaurant), findsOneWidget);
      // Pas de CachedNetworkImage
      expect(find.byType(CachedNetworkImage), findsNothing);
    });

    testWidgets('shows fallback when photoUrl is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecipePhotoWidget(
              photoUrl: '',
              width: 80,
              height: 80,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.restaurant), findsOneWidget);
    });

    testWidgets('shows fallback when photoUrl is a local path (not URL)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecipePhotoWidget(
              photoUrl: '/data/user/0/com.example/files/photo.jpg',
              width: 80,
              height: 80,
            ),
          ),
        ),
      );

      // Les chemins locaux ne sont pas des URLs valides → fallback
      expect(find.byIcon(Icons.restaurant), findsOneWidget);
    });

    testWidgets('shows CachedNetworkImage when photoUrl is a valid URL',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecipePhotoWidget(
              photoUrl: 'https://example.supabase.co/storage/v1/object/public/recipe-photos/household/recipe.jpg',
              width: 80,
              height: 80,
            ),
          ),
        ),
      );

      expect(find.byType(CachedNetworkImage), findsOneWidget);
    });

    testWidgets('uses custom fallback icon when specified', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecipePhotoWidget(
              photoUrl: null,
              width: 80,
              height: 80,
              fallbackIcon: Icons.broken_image_outlined,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    });

    testWidgets('shows Image.network for blob URL (web step photos)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecipePhotoWidget(
              photoUrl: 'blob:http://localhost:8080/abc-123',
              width: 80,
              height: 80,
            ),
          ),
        ),
      );

      // Blob URLs utilisent Image.network, pas CachedNetworkImage
      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('wraps in ClipRRect when borderRadius is specified',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecipePhotoWidget(
              photoUrl: 'https://example.com/photo.jpg',
              width: 80,
              height: 80,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );

      expect(find.byType(ClipRRect), findsOneWidget);
    });
  });
}
