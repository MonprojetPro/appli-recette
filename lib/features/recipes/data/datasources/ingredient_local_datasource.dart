import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/features/recipes/domain/repositories/ingredient_repository.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Source de données locale pour les ingrédients (drift / SQLite).
class IngredientLocalDatasource {
  IngredientLocalDatasource(this._db);

  final AppDatabase _db;

  /// Flux des ingrédients d'une recette.
  Stream<List<Ingredient>> watchForRecipe(String recipeId) {
    return (_db.select(_db.ingredients)
          ..where((t) => t.recipeId.equals(recipeId)))
        .watch();
  }

  /// Liste synchrone des ingrédients d'une recette (pour enqueue delete).
  Future<List<Ingredient>> listForRecipe(String recipeId) {
    return (_db.select(_db.ingredients)
          ..where((t) => t.recipeId.equals(recipeId)))
        .get();
  }

  /// Insère un ingrédient et retourne son ID.
  Future<String> insert(IngredientsCompanion companion) async {
    await _db.into(_db.ingredients).insert(companion);
    return companion.id.value;
  }

  /// Met à jour un ingrédient existant.
  Future<void> update(IngredientsCompanion companion) async {
    await (_db.update(_db.ingredients)
          ..where((t) => t.id.equals(companion.id.value)))
        .write(companion);
  }

  /// Supprime un ingrédient par son ID.
  Future<void> delete(String id) async {
    await (_db.delete(_db.ingredients)..where((t) => t.id.equals(id))).go();
  }

  /// Supprime tous les ingrédients d'une recette.
  Future<void> deleteAllForRecipe(String recipeId) async {
    await (_db.delete(_db.ingredients)
          ..where((t) => t.recipeId.equals(recipeId)))
        .go();
  }

  /// Remplace tous les ingrédients d'une recette dans une transaction atomique.
  Future<void> replaceAll({
    required String recipeId,
    required List<IngredientInput> ingredients,
  }) async {
    await _db.transaction(() async {
      await deleteAllForRecipe(recipeId);
      for (final ing in ingredients) {
        final id = const Uuid().v4();
        await _db.into(_db.ingredients).insert(
          IngredientsCompanion.insert(
            id: id,
            recipeId: recipeId,
            name: ing.name,
            quantity: Value(ing.quantity),
            unit: Value(ing.unit),
            supermarketSection: Value(ing.supermarketSection),
          ),
        );
      }
    });
  }
}
