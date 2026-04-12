// ignore_for_file: avoid_redundant_argument_values -- valeurs explicites pour la lisibilité des tests.

import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/sync/sync_queue_datasource.dart';
import 'package:appli_recette/features/recipes/data/datasources/ingredient_local_datasource.dart';
import 'package:appli_recette/features/recipes/data/repositories/ingredient_repository_impl.dart';
import 'package:appli_recette/features/recipes/data/repositories/recipe_repository_impl.dart';
import 'package:appli_recette/features/recipes/data/datasources/recipe_local_datasource.dart';
import 'package:appli_recette/features/recipes/domain/repositories/ingredient_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppDatabase _createTestDatabase() =>
    AppDatabase.forTesting(NativeDatabase.memory());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late RecipeRepositoryImpl recipeRepo;
  late IngredientRepositoryImpl ingRepo;
  late String recipeId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = _createTestDatabase();
    final syncQueue = SyncQueueDatasource(db);
    recipeRepo = RecipeRepositoryImpl(RecipeLocalDatasource(db), syncQueue);
    ingRepo = IngredientRepositoryImpl(IngredientLocalDatasource(db), syncQueue);

    // Crée une recette de base pour lier les ingrédients
    recipeId = await recipeRepo.create(
      name: 'Recette test',
      mealType: 'dinner',
      prepTimeMinutes: 20,
    );
  });

  tearDown(() async => db.close());

  group('IngredientRepositoryImpl', () {
    test('add() retourne un UUID v4 non-vide', () async {
      final id = await ingRepo.add(
        recipeId: recipeId,
        name: 'Tomate',
        quantity: 3,
        unit: 'pièce',
      );
      expect(id, isNotEmpty);
      expect(id.length, 36);
    });

    test('add() persiste un ingrédient', () async {
      await ingRepo.add(
        recipeId: recipeId,
        name: 'Carotte',
        quantity: 2.5,
        unit: 'kg',
        supermarketSection: 'Légumes',
      );

      final ings = await ingRepo.watchForRecipe(recipeId).first;
      expect(ings.length, 1);
      expect(ings.first.name, 'Carotte');
      expect(ings.first.quantity, 2.5);
      expect(ings.first.unit, 'kg');
      expect(ings.first.supermarketSection, 'Légumes');
    });

    test('update() modifie un ingrédient existant', () async {
      final id = await ingRepo.add(
        recipeId: recipeId,
        name: 'Oignon',
        quantity: 1,
        unit: 'pièce',
      );

      await ingRepo.update(
        id: id,
        name: 'Oignon rouge',
        quantity: 2,
        unit: 'pièce',
        supermarketSection: 'Légumes',
      );

      final ings = await ingRepo.watchForRecipe(recipeId).first;
      expect(ings.first.name, 'Oignon rouge');
      expect(ings.first.quantity, 2);
    });

    test('delete() supprime un seul ingrédient', () async {
      final id1 = await ingRepo.add(
        recipeId: recipeId,
        name: 'A',
        quantity: 1,
      );
      await ingRepo.add(recipeId: recipeId, name: 'B', quantity: 2);

      await ingRepo.delete(id1);

      final ings = await ingRepo.watchForRecipe(recipeId).first;
      expect(ings.length, 1);
      expect(ings.first.name, 'B');
    });

    test('deleteAllForRecipe() supprime tous les ingrédients', () async {
      await ingRepo.add(recipeId: recipeId, name: 'A', quantity: 1);
      await ingRepo.add(recipeId: recipeId, name: 'B', quantity: 2);

      await ingRepo.deleteAllForRecipe(recipeId);

      final ings = await ingRepo.watchForRecipe(recipeId).first;
      expect(ings, isEmpty);
    });

    test('replaceAll() remplace atomiquement tous les ingrédients', () async {
      // Ingrédients initiaux
      await ingRepo.add(recipeId: recipeId, name: 'Ancien', quantity: 1);

      // Remplacement
      await ingRepo.replaceAll(
        recipeId: recipeId,
        ingredients: [
          const IngredientInput(
            name: 'Nouveau 1',
            quantity: 100,
            unit: 'g',
            supermarketSection: 'Épicerie',
          ),
          const IngredientInput(
            name: 'Nouveau 2',
            quantity: 2,
            unit: 'pièce',
          ),
        ],
      );

      final ings = await ingRepo.watchForRecipe(recipeId).first;
      expect(ings.length, 2);
      expect(ings.map((i) => i.name).toList(), containsAll(['Nouveau 1', 'Nouveau 2']));
      // L'ancien n'est plus là
      expect(ings.any((i) => i.name == 'Ancien'), isFalse);
    });

    test('replaceAll() avec liste vide supprime tous les ingrédients', () async {
      await ingRepo.add(recipeId: recipeId, name: 'À supprimer', quantity: 1);

      await ingRepo.replaceAll(recipeId: recipeId, ingredients: []);

      final ings = await ingRepo.watchForRecipe(recipeId).first;
      expect(ings, isEmpty);
    });

    test('watchForRecipe() ne retourne que les ingrédients de cette recette', () async {
      // Deuxième recette
      final recipe2Id = await recipeRepo.create(
        name: 'Recette 2',
        mealType: 'lunch',
        prepTimeMinutes: 10,
      );

      await ingRepo.add(recipeId: recipeId, name: 'Pour recette 1');
      await ingRepo.add(recipeId: recipe2Id, name: 'Pour recette 2');

      final ings1 = await ingRepo.watchForRecipe(recipeId).first;
      final ings2 = await ingRepo.watchForRecipe(recipe2Id).first;

      expect(ings1.length, 1);
      expect(ings1.first.name, 'Pour recette 1');
      expect(ings2.length, 1);
      expect(ings2.first.name, 'Pour recette 2');
    });
  });
}
