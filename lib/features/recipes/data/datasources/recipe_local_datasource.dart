import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/features/recipes/domain/repositories/ingredient_repository.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Source de données locale pour les recettes (drift / SQLite).
class RecipeLocalDatasource {
  RecipeLocalDatasource(this._db);

  final AppDatabase _db;

  /// Flux de toutes les recettes du foyer triées par date de création DESC.
  Stream<List<Recipe>> watchAll(String householdId) {
    return (_db.select(_db.recipes)
          ..where((t) => t.householdId.equals(householdId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Flux de recettes du foyer filtrées par recherche sur le nom.
  /// Les caractères LIKE spéciaux (% et _) sont supprimés du query.
  Stream<List<Recipe>> watchBySearch(String query, String householdId) {
    // drift v2 ne supporte pas le paramètre `escape` sur like() —
    // on supprime les caractères LIKE spéciaux pour éviter les faux-positifs.
    final safeQuery =
        query.replaceAll('%', '').replaceAll('_', '').replaceAll(r'\', '');
    return (_db.select(_db.recipes)
          ..where(
            (t) =>
                t.householdId.equals(householdId) &
                t.name.like('%$safeQuery%'),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Récupère une recette par son ID.
  Future<Recipe?> getById(String id) {
    return (_db.select(_db.recipes)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Stream réactif d'une recette par son ID.
  Stream<Recipe?> watchById(String id) {
    return (_db.select(_db.recipes)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  /// Insère une nouvelle recette et retourne son ID.
  Future<String> insert(RecipesCompanion companion) async {
    await _db.into(_db.recipes).insert(companion);
    return companion.id.value;
  }

  /// Met à jour tous les champs d'une recette.
  Future<void> update(RecipesCompanion companion) async {
    await (_db.update(_db.recipes)
          ..where((t) => t.id.equals(companion.id.value)))
        .write(companion);
  }

  /// Supprime une recette par son ID.
  Future<void> delete(String id) async {
    await (_db.delete(_db.recipes)..where((t) => t.id.equals(id))).go();
  }

  /// Met à jour le statut favori d'une recette.
  Future<void> updateFavorite({
    required String id,
    required bool isFavorite,
  }) async {
    await (_db.update(_db.recipes)..where((t) => t.id.equals(id))).write(
      RecipesCompanion(
        isFavorite: Value(isFavorite),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Met à jour une recette ET ses ingrédients dans une transaction atomique.
  Future<void> updateWithIngredients({
    required RecipesCompanion recipeCompanion,
    required String recipeId,
    required List<IngredientInput> ingredients,
  }) async {
    await _db.transaction(() async {
      // Update recette
      await (_db.update(_db.recipes)
            ..where((t) => t.id.equals(recipeCompanion.id.value)))
          .write(recipeCompanion);
      // Remplacer les ingrédients
      await (_db.delete(_db.ingredients)
            ..where((t) => t.recipeId.equals(recipeId)))
          .go();
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

  /// Met à jour uniquement le chemin photo d'une recette.
  Future<void> updatePhotoPath({
    required String id,
    required String? photoPath,
  }) async {
    await (_db.update(_db.recipes)..where((t) => t.id.equals(id))).write(
      RecipesCompanion(
        photoPath: Value(photoPath),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
