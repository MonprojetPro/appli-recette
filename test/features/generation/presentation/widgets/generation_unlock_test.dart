import 'package:appli_recette/core/constants/generation_constants.dart';
import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/database/database_provider.dart';
import 'package:appli_recette/features/generation/presentation/screens/home_screen.dart';
import 'package:appli_recette/features/recipes/presentation/providers/recipes_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AppDatabase _buildDb() => AppDatabase.forTesting(NativeDatabase.memory());

/// Monte [HomeScreen] avec un override sur [recipeCountProvider].
/// [generateMenuProvider.build()] renvoie null sans accès DB → état vide stable.
Widget _buildHome({required AppDatabase db, int recipeCount = 0}) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      recipeCountProvider.overrideWith((ref) => recipeCount),
    ],
    child: const MaterialApp(home: HomeScreen()),
  );
}

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // Tests unitaires — logique providers
  // ─────────────────────────────────────────────────────────────────────────

  group('canGenerateProvider', () {
    test('est false quand 0 recettes', () {
      final container = ProviderContainer(
        overrides: [recipeCountProvider.overrideWith((ref) => 0)],
      );
      addTearDown(container.dispose);
      expect(container.read(canGenerateProvider), isFalse);
    });

    test('est false quand 13 recettes', () {
      final container = ProviderContainer(
        overrides: [recipeCountProvider.overrideWith((ref) => 13)],
      );
      addTearDown(container.dispose);
      expect(container.read(canGenerateProvider), isFalse);
    });

    test('est true quand exactement $kMinRecipesForGeneration recettes', () {
      final container = ProviderContainer(
        overrides: [
          recipeCountProvider.overrideWith(
            (ref) => kMinRecipesForGeneration,
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(canGenerateProvider), isTrue);
    });

    test('est true quand plus de $kMinRecipesForGeneration recettes', () {
      final container = ProviderContainer(
        overrides: [recipeCountProvider.overrideWith((ref) => 20)],
      );
      addTearDown(container.dispose);
      expect(container.read(canGenerateProvider), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Tests widget — banner de débloquage (via HomeScreen réel)
  // ─────────────────────────────────────────────────────────────────────────

  group('Banner de débloquage de la génération', () {
    testWidgets(
        'message initial et compteur 0/$kMinRecipesForGeneration '
        'quand 0 recettes', (tester) async {
      final db = _buildDb();
      await tester.pumpWidget(_buildHome(db: db, recipeCount: 0));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Commence par ajouter $kMinRecipesForGeneration '
          'recettes pour générer un menu',
        ),
        findsOneWidget,
      );
      expect(find.text('0/$kMinRecipesForGeneration'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
      await db.close();
    });

    testWidgets(
        'message "Plus qu\'1 recette" et compteur '
        '${kMinRecipesForGeneration - 1}/$kMinRecipesForGeneration '
        'quand ${kMinRecipesForGeneration - 1} recettes', (tester) async {
      final db = _buildDb();
      await tester.pumpWidget(
        _buildHome(db: db, recipeCount: kMinRecipesForGeneration - 1),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("Plus qu'1 recette avant de pouvoir générer !"),
        findsOneWidget,
      );
      expect(
        find.text(
          '${kMinRecipesForGeneration - 1}/$kMinRecipesForGeneration',
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
      await db.close();
    });

    testWidgets(
        'banner masqué quand $kMinRecipesForGeneration recettes',
        (tester) async {
      final db = _buildDb();
      await tester.pumpWidget(
        _buildHome(db: db, recipeCount: kMinRecipesForGeneration),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Commence par ajouter $kMinRecipesForGeneration '
          'recettes pour générer un menu',
        ),
        findsNothing,
      );
      expect(
        find.text("Plus qu'1 recette avant de pouvoir générer !"),
        findsNothing,
      );
      expect(
        find.text(
          '$kMinRecipesForGeneration/$kMinRecipesForGeneration',
        ),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
      await db.close();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Tests widget — état du bouton Générer (AC#1 Story 6.2)
  // ─────────────────────────────────────────────────────────────────────────

  group('Bouton Générer — état actif/désactivé', () {
    testWidgets('bouton Générer désactivé quand 0 recettes', (tester) async {
      final db = _buildDb();
      await tester.pumpWidget(_buildHome(db: db, recipeCount: 0));
      await tester.pumpAndSettle();

      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Générer'),
      );
      expect(button.onPressed, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
      await db.close();
    });

    testWidgets('bouton Générer désactivé quand 13 recettes', (tester) async {
      final db = _buildDb();
      await tester.pumpWidget(_buildHome(db: db, recipeCount: 13));
      await tester.pumpAndSettle();

      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Générer'),
      );
      expect(button.onPressed, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
      await db.close();
    });

    testWidgets(
        'bouton Générer actif quand $kMinRecipesForGeneration recettes',
        (tester) async {
      final db = _buildDb();
      await tester.pumpWidget(
        _buildHome(db: db, recipeCount: kMinRecipesForGeneration),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Générer'),
      );
      expect(button.onPressed, isNotNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
      await db.close();
    });
  });
}
