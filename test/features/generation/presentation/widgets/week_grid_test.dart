import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/features/generation/domain/models/meal_slot_result.dart';
import 'package:appli_recette/features/generation/presentation/widgets/meal_slot_card.dart';
import 'package:appli_recette/features/generation/presentation/widgets/week_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Recipe _recipe(String id, {bool isFavorite = false, bool isVegetarian = false}) {
  return Recipe(
    id: id,
    name: 'Recette $id',
    mealType: 'lunch',
    prepTimeMinutes: 20,
    cookTimeMinutes: 0,
    restTimeMinutes: 0,
    season: 'all',
    isVegetarian: isVegetarian,
    servings: 4,
    isFavorite: isFavorite,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    isSynced: false,
  );
}

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(body: child),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests WeekGrid
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  // Lundi 9 mars 2026
  final monday = DateTime(2026, 3, 9);

  group('WeekGrid', () {
    testWidgets('affiche 7 lignes de jours quand tous les slots sont null',
        (tester) async {
      final slots = List<MealSlotResult?>.filled(14, null);

      await tester.pumpWidget(_buildTestApp(
        WeekGrid(slots: slots, recipesMap: const {}, monday: monday),
      ));
      await tester.pump();

      // 7 labels de jours affichés (contenant "Lundi", "Mardi", etc.)
      expect(find.textContaining('Lundi'), findsOneWidget);
      expect(find.textContaining('Dimanche'), findsOneWidget);
    });

    testWidgets('affiche le nom de la recette quand slot rempli',
        (tester) async {
      final recipe = _recipe('r1');
      final slots = [
        const MealSlotResult(recipeId: 'r1', dayIndex: 0, mealType: 'lunch'),
        ...List<MealSlotResult?>.filled(13, null),
      ];

      await tester.pumpWidget(_buildTestApp(
        WeekGrid(
          slots: slots,
          recipesMap: {'r1': recipe},
          monday: monday,
        ),
      ));
      await tester.pump();

      expect(find.text('Recette r1'), findsOneWidget);
    });

    testWidgets('affiche le header du premier et dernier jour', (tester) async {
      final slots = List<MealSlotResult?>.filled(14, null);

      await tester.pumpWidget(_buildTestApp(
        WeekGrid(slots: slots, recipesMap: const {}, monday: monday),
      ));
      await tester.pump();

      expect(find.textContaining('Lundi'), findsOneWidget);
      expect(find.textContaining('Dimanche'), findsOneWidget);
    });
  });

  group('MealSlotCard', () {
    testWidgets('affiche badge Favori si isFavorite=true', (tester) async {
      final recipe = _recipe('r1', isFavorite: true);

      await tester.pumpWidget(_buildTestApp(
        MealSlotCard(recipe: recipe, isPostGeneration: true),
      ));

      expect(find.text('⭐'), findsOneWidget);
    });

    testWidgets('affiche badge Végé si isVegetarian=true', (tester) async {
      final recipe = _recipe('r1', isVegetarian: true);

      await tester.pumpWidget(_buildTestApp(
        MealSlotCard(recipe: recipe, isPostGeneration: true),
      ));

      expect(find.text('🌿'), findsOneWidget);
    });

    testWidgets('icône + visible en état vide', (tester) async {
      await tester.pumpWidget(_buildTestApp(
        const MealSlotCard(),
      ));

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('affiche icônes action en mode post-génération', (tester) async {
      final recipe = _recipe('r1');

      await tester.pumpWidget(_buildTestApp(
        MealSlotCard(recipe: recipe, isPostGeneration: true),
      ));

      expect(find.byIcon(Icons.lock_open), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('affiche icône verrou plein si isLocked=true', (tester) async {
      final recipe = _recipe('r1');

      await tester.pumpWidget(_buildTestApp(
        MealSlotCard(
          recipe: recipe,
          isPostGeneration: true,
          isLocked: true,
        ),
      ));

      expect(find.byIcon(Icons.lock), findsOneWidget);
    });
  });
}
