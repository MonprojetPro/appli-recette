// ignore_for_file: avoid_redundant_argument_values -- valeurs explicites pour la lisibilité des tests.

import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/sync/sync_queue_datasource.dart';
import 'package:appli_recette/features/recipes/data/datasources/recipe_local_datasource.dart';
import 'package:appli_recette/features/recipes/data/repositories/recipe_repository_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppDatabase _createTestDatabase() =>
    AppDatabase.forTesting(NativeDatabase.memory());

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

  tearDown(() async => db.close());

  // ─────────────────────────────────────────────────────────────────────────
  // Story 2-2 : update() + getById()
  // ─────────────────────────────────────────────────────────────────────────
  group('Story 2-2 – update() et getById()', () {
    test('update() persiste tous les champs enrichis', () async {
      final id = await repo.create(
        name: 'Salade',
        mealType: 'lunch',
        prepTimeMinutes: 10,
      );

      await repo.update(
        id: id,
        name: 'Salade niçoise',
        mealType: 'lunch',
        prepTimeMinutes: 15,
        cookTimeMinutes: 0,
        restTimeMinutes: 0,
        season: 'summer',
        isVegetarian: false,
        servings: 2,
        notes: 'Ajouter des anchois',
        variants: 'Version végé possible',
        sourceUrl: 'https://example.com/salade',
        photoPath: null,
      );

      final updated = await repo.getById(id);
      expect(updated, isNotNull);
      expect(updated!.name, 'Salade niçoise');
      expect(updated.season, 'summer');
      expect(updated.isVegetarian, false);
      expect(updated.servings, 2);
      expect(updated.notes, 'Ajouter des anchois');
    });

    test('getById() retourne null pour un ID inconnu', () async {
      final result = await repo.getById('id-inexistant');
      expect(result, isNull);
    });

    test('getById() retourne la recette correcte', () async {
      final id = await repo.create(
        name: 'Quiche',
        mealType: 'lunch',
        prepTimeMinutes: 20,
      );

      final recipe = await repo.getById(id);
      expect(recipe, isNotNull);
      expect(recipe!.id, id);
      expect(recipe.name, 'Quiche');
    });

    test('update() saison chip — seule la saison change', () async {
      final id = await repo.create(
        name: 'Soupe',
        mealType: 'dinner',
        prepTimeMinutes: 20,
      );

      await repo.update(
        id: id,
        name: 'Soupe',
        mealType: 'dinner',
        prepTimeMinutes: 20,
        cookTimeMinutes: 30,
        restTimeMinutes: 0,
        season: 'winter',
        isVegetarian: true,
        servings: 4,
      );

      final updated = await repo.getById(id);
      expect(updated!.season, 'winter');
      expect(updated.isVegetarian, true);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Story 2-3 : updatePhotoPath()
  // ─────────────────────────────────────────────────────────────────────────
  group('Story 2-3 – updatePhotoPath()', () {
    test('updatePhotoPath() persiste le chemin photo', () async {
      final id = await repo.create(
        name: 'Crêpes',
        mealType: 'breakfast',
        prepTimeMinutes: 10,
      );

      await repo.updatePhotoPath(id: id, photoPath: '/photos/crepes.jpg');

      final recipe = await repo.getById(id);
      expect(recipe!.photoPath, '/photos/crepes.jpg');
    });

    test('updatePhotoPath() peut effacer la photo (null)', () async {
      final id = await repo.create(
        name: 'Omelette',
        mealType: 'breakfast',
        prepTimeMinutes: 5,
      );

      await repo.updatePhotoPath(id: id, photoPath: '/photos/omelette.jpg');
      await repo.updatePhotoPath(id: id, photoPath: null);

      final recipe = await repo.getById(id);
      expect(recipe!.photoPath, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Story 2-4 : notes, variantes, URL source
  // ─────────────────────────────────────────────────────────────────────────
  group('Story 2-4 – notes, variantes, URL', () {
    test('update() persiste les notes libres', () async {
      final id = await repo.create(
        name: 'Ratatouille',
        mealType: 'dinner',
        prepTimeMinutes: 30,
      );

      await repo.update(
        id: id,
        name: 'Ratatouille',
        mealType: 'dinner',
        prepTimeMinutes: 30,
        cookTimeMinutes: 45,
        restTimeMinutes: 0,
        season: 'summer',
        isVegetarian: true,
        servings: 6,
        notes: 'Laisser compoter longtemps',
        variants: 'Ajouter des courgettes',
        sourceUrl: 'https://marmiton.org/ratatouille',
      );

      final recipe = await repo.getById(id);
      expect(recipe!.notes, 'Laisser compoter longtemps');
      expect(recipe.variants, 'Ajouter des courgettes');
      expect(recipe.sourceUrl, 'https://marmiton.org/ratatouille');
    });

    test('update() accepte notes/variantes/url null', () async {
      final id = await repo.create(
        name: 'Pâtes',
        mealType: 'dinner',
        prepTimeMinutes: 10,
      );

      await repo.update(
        id: id,
        name: 'Pâtes',
        mealType: 'dinner',
        prepTimeMinutes: 10,
        cookTimeMinutes: 15,
        restTimeMinutes: 0,
        season: 'all',
        isVegetarian: false,
        servings: 4,
      );

      final recipe = await repo.getById(id);
      expect(recipe!.notes, isNull);
      expect(recipe.variants, isNull);
      expect(recipe.sourceUrl, isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Story 2-5 : delete()
  // ─────────────────────────────────────────────────────────────────────────
  group('Story 2-5 – delete()', () {
    test('delete() supprime uniquement la recette ciblée', () async {
      final id1 = await repo.create(
        name: 'Recette A',
        mealType: 'lunch',
        prepTimeMinutes: 10,
      );
      final id2 = await repo.create(
        name: 'Recette B',
        mealType: 'dinner',
        prepTimeMinutes: 20,
      );

      await repo.delete(id1);

      final remaining = await repo.watchAll(testHouseholdId).first;
      expect(remaining.length, 1);
      expect(remaining.first.id, id2);
    });

    test("delete() sur un ID inexistant ne lève pas d'erreur", () async {
      await expectLater(
        repo.delete('id-inexistant'),
        completes,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Story 2-6 : setFavorite() + watchBySearch()
  // ─────────────────────────────────────────────────────────────────────────
  group('Story 2-6 – favoris et recherche', () {
    test('setFavorite() toggle favori correctement', () async {
      final id = await repo.create(
        name: 'Bourguignon',
        mealType: 'dinner',
        prepTimeMinutes: 30,
      );

      // Initialement false
      final initial = await repo.getById(id);
      expect(initial!.isFavorite, isFalse);

      // Toggle ON
      await repo.setFavorite(id: id, isFavorite: true);
      final afterOn = await repo.getById(id);
      expect(afterOn!.isFavorite, isTrue);

      // Toggle OFF
      await repo.setFavorite(id: id, isFavorite: false);
      final afterOff = await repo.getById(id);
      expect(afterOff!.isFavorite, isFalse);
    });

    test('watchBySearch() filtre les recettes par nom', () async {
      await repo.create(
        name: 'Poulet rôti',
        mealType: 'dinner',
        prepTimeMinutes: 15,
      );
      await repo.create(
        name: 'Pâtes carbonara',
        mealType: 'dinner',
        prepTimeMinutes: 10,
      );
      await repo.create(
        name: 'Poulet curry',
        mealType: 'dinner',
        prepTimeMinutes: 20,
      );

      final pouletResults =
          await repo.watchBySearch('Poulet', testHouseholdId).first;
      expect(pouletResults.length, 2);
      expect(pouletResults.every((r) => r.name.contains('Poulet')), isTrue);

      final patesResults =
          await repo.watchBySearch('Pâtes', testHouseholdId).first;
      expect(patesResults.length, 1);
      expect(patesResults.first.name, 'Pâtes carbonara');
    });

    test('watchBySearch() retourne vide si aucun résultat', () async {
      await repo.create(
        name: 'Boeuf bourguignon',
        mealType: 'dinner',
        prepTimeMinutes: 30,
      );

      final results = await repo.watchBySearch('pizza', testHouseholdId).first;
      expect(results, isEmpty);
    });
  });
}
