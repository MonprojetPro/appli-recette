// ignore_for_file: avoid_redundant_argument_values -- valeurs
// explicites pour la lisibilité des tests.

import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/sync/sync_queue_datasource.dart';
import 'package:appli_recette/features/recipes/data/datasources/recipe_local_datasource.dart';
import 'package:appli_recette/features/recipes/data/repositories/recipe_repository_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Crée une base de données drift en mémoire pour les tests.
AppDatabase _createTestDatabase() => AppDatabase.forTesting(
      NativeDatabase.memory(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late RecipeRepositoryImpl repo;

  const testHouseholdId = 'test-household-uuid';

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'household_id': testHouseholdId,
    });
    db = _createTestDatabase();
    final datasource = RecipeLocalDatasource(db);
    final syncQueue = SyncQueueDatasource(db);
    repo = RecipeRepositoryImpl(datasource, syncQueue);
  });

  tearDown(() async {
    await db.close();
  });

  group('RecipeRepositoryImpl', () {
    test('create() retourne un ID UUID v4 non-vide', () async {
      final id = await repo.create(
        name: 'Poulet rôti',
        mealType: 'dinner',
        prepTimeMinutes: 15,
        cookTimeMinutes: 60,
      );
      expect(id, isNotEmpty);
      // UUID v4 : 36 chars, 4 tirets, 3e groupe commence par '4'
      expect(id.length, 36);
      expect(id.split('-').length, 5);
      expect(id[14], '4'); // version 4
    });

    test('create() persiste la recette dans drift', () async {
      await repo.create(
        name: 'Tarte aux pommes',
        mealType: 'dessert',
        prepTimeMinutes: 20,
        cookTimeMinutes: 35,
        restTimeMinutes: 0,
      );

      final recipes = await repo.watchAll(testHouseholdId).first;
      expect(recipes.length, 1);
      expect(recipes.first.name, 'Tarte aux pommes');
      expect(recipes.first.mealType, 'dessert');
      expect(recipes.first.prepTimeMinutes, 20);
      expect(recipes.first.cookTimeMinutes, 35);
      expect(recipes.first.restTimeMinutes, 0);
    });

    test('create() utilise les valeurs par défaut pour cook/rest time', () async {
      await repo.create(
        name: 'Salade',
        mealType: 'lunch',
        prepTimeMinutes: 10,
      );

      final recipes = await repo.watchAll(testHouseholdId).first;
      expect(recipes.first.cookTimeMinutes, 0);
      expect(recipes.first.restTimeMinutes, 0);
    });

    test('watchAll() retourne bien toutes les recettes créées', () async {
      await repo.create(
        name: 'Recette 1',
        mealType: 'lunch',
        prepTimeMinutes: 10,
      );
      await repo.create(
        name: 'Recette 2',
        mealType: 'dinner',
        prepTimeMinutes: 20,
      );

      final recipes = await repo.watchAll(testHouseholdId).first;
      expect(recipes.length, 2);
      final names = recipes.map((r) => r.name).toList();
      expect(names, containsAll(['Recette 1', 'Recette 2']));
    });

    test('delete() supprime une recette existante', () async {
      final id = await repo.create(
        name: 'À supprimer',
        mealType: 'snack',
        prepTimeMinutes: 5,
      );

      await repo.delete(id);

      final recipes = await repo.watchAll(testHouseholdId).first;
      expect(recipes, isEmpty);
    });

    test('setFavorite() met à jour le statut favori', () async {
      final id = await repo.create(
        name: 'Ma recette',
        mealType: 'breakfast',
        prepTimeMinutes: 10,
      );

      await repo.setFavorite(id: id, isFavorite: true);
      final recipesAfter = await repo.watchAll(testHouseholdId).first;
      expect(recipesAfter.first.isFavorite, isTrue);

      await repo.setFavorite(id: id, isFavorite: false);
      final recipesAfterToggle = await repo.watchAll(testHouseholdId).first;
      expect(recipesAfterToggle.first.isFavorite, isFalse);
    });

    test('create() multiple — tous les IDs sont distincts', () async {
      final id1 = await repo.create(
        name: 'R1',
        mealType: 'lunch',
        prepTimeMinutes: 10,
      );
      final id2 = await repo.create(
        name: 'R2',
        mealType: 'dinner',
        prepTimeMinutes: 20,
      );
      final id3 = await repo.create(
        name: 'R3',
        mealType: 'breakfast',
        prepTimeMinutes: 5,
      );

      expect({id1, id2, id3}.length, 3); // tous distincts
    });
  });
}
