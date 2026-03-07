import 'package:appli_recette/core/constants/generation_constants.dart';
import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/database/database_provider.dart';
import 'package:appli_recette/core/storage/image_service.dart';
import 'package:appli_recette/core/storage/supabase_storage_service.dart';
import 'package:appli_recette/core/sync/sync_provider.dart';
import 'package:appli_recette/features/recipes/data/datasources/ingredient_local_datasource.dart';
import 'package:appli_recette/features/recipes/data/datasources/recipe_local_datasource.dart';
import 'package:appli_recette/features/recipes/data/datasources/recipe_steps_local_datasource.dart';
import 'package:appli_recette/features/recipes/data/repositories/ingredient_repository_impl.dart';
import 'package:appli_recette/features/recipes/data/repositories/recipe_repository_impl.dart';
import 'package:appli_recette/features/recipes/domain/repositories/ingredient_repository.dart';
import 'package:appli_recette/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Infrastructure providers
// ---------------------------------------------------------------------------

final imageServiceProvider = Provider<ImageService>((ref) => ImageService());

final supabaseStorageServiceProvider =
    Provider<SupabaseStorageService>((ref) {
  return SupabaseStorageService(Supabase.instance.client);
});

final recipeLocalDatasourceProvider = Provider<RecipeLocalDatasource>((ref) {
  final db = ref.watch(databaseProvider);
  return RecipeLocalDatasource(db);
});

final ingredientLocalDatasourceProvider =
    Provider<IngredientLocalDatasource>((ref) {
  final db = ref.watch(databaseProvider);
  return IngredientLocalDatasource(db);
});

final recipeStepsDatasourceProvider =
    Provider<RecipeStepsLocalDatasource>((ref) {
  final db = ref.watch(databaseProvider);
  return RecipeStepsLocalDatasource(db);
});

// ---------------------------------------------------------------------------
// Repository providers
// ---------------------------------------------------------------------------

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  final datasource = ref.watch(recipeLocalDatasourceProvider);
  final syncQueue = ref.watch(syncQueueDatasourceProvider);
  return RecipeRepositoryImpl(datasource, syncQueue);
});

final ingredientRepositoryProvider = Provider<IngredientRepository>((ref) {
  final datasource = ref.watch(ingredientLocalDatasourceProvider);
  return IngredientRepositoryImpl(datasource);
});

// ---------------------------------------------------------------------------
// Stream providers (lecture)
// ---------------------------------------------------------------------------

/// Stream de toutes les recettes (sans filtre).
final recipesStreamProvider = StreamProvider<List<Recipe>>((ref) {
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.watchAll();
});

// ignore_for_file: specify_nonobvious_property_types -- types inférés depuis les generics Riverpod
/// Stream de recettes filtrées par recherche.
final recipesSearchProvider =
    StreamProvider.family<List<Recipe>, String>((ref, query) {
  final repo = ref.watch(recipeRepositoryProvider);
  if (query.isEmpty) return repo.watchAll();
  return repo.watchBySearch(query);
});

/// Stream des ingrédients d'une recette.
final ingredientsForRecipeProvider =
    StreamProvider.family<List<Ingredient>, String>((ref, recipeId) {
  final repo = ref.watch(ingredientRepositoryProvider);
  return repo.watchForRecipe(recipeId);
});

/// Stream réactif d'une recette par son ID.
final recipeByIdProvider =
    StreamProvider.family<Recipe?, String>((ref, id) {
  final repo = ref.watch(recipeRepositoryProvider);
  return repo.watchById(id);
});

/// Stream des étapes de préparation d'une recette.
final stepsForRecipeProvider =
    StreamProvider.family<List<RecipeStep>, String>((ref, recipeId) {
  final datasource = ref.watch(recipeStepsDatasourceProvider);
  return datasource.watchForRecipe(recipeId);
});

/// Nombre de recettes dans la collection (dérivé de [recipesStreamProvider]).
///
/// Se met à jour automatiquement dès qu'une recette est ajoutée ou supprimée.
final recipeCountProvider = Provider<int>((ref) {
  return ref.watch(recipesStreamProvider).value?.length ?? 0;
});

/// True si l'utilisateur peut générer un menu (minimum [kMinRecipesForGeneration] recettes).
final canGenerateProvider = Provider<bool>((ref) {
  return ref.watch(recipeCountProvider) >= kMinRecipesForGeneration;
});

// ---------------------------------------------------------------------------
// Notifier (actions)
// ---------------------------------------------------------------------------

/// Notifier pour les actions sur les recettes.
class RecipesNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Crée une nouvelle recette et retourne son ID.
  Future<String> createRecipe({
    required String name,
    required String mealType,
    required int prepTimeMinutes,
    int cookTimeMinutes = 0,
    int restTimeMinutes = 0,
  }) async {
    final repo = ref.read(recipeRepositoryProvider);
    return repo.create(
      name: name,
      mealType: mealType,
      prepTimeMinutes: prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes,
      restTimeMinutes: restTimeMinutes,
    );
  }

  /// Met à jour une recette complète (tous les champs).
  Future<void> updateRecipe({
    required String id,
    required String name,
    required String mealType,
    required int prepTimeMinutes,
    required int cookTimeMinutes,
    required int restTimeMinutes,
    required String season,
    required bool isVegetarian,
    required int servings,
    String? notes,
    String? variants,
    String? sourceUrl,
    String? photoPath,
  }) async {
    final repo = ref.read(recipeRepositoryProvider);
    await repo.update(
      id: id,
      name: name,
      mealType: mealType,
      prepTimeMinutes: prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes,
      restTimeMinutes: restTimeMinutes,
      season: season,
      isVegetarian: isVegetarian,
      servings: servings,
      notes: notes,
      variants: variants,
      sourceUrl: sourceUrl,
      photoPath: photoPath,
    );
  }

  /// Supprime une recette.
  Future<void> deleteRecipe(String id) async {
    final repo = ref.read(recipeRepositoryProvider);
    await repo.delete(id);
  }

  /// Toggle favori.
  Future<void> toggleFavorite(String id, {required bool currentValue}) async {
    final repo = ref.read(recipeRepositoryProvider);
    await repo.setFavorite(id: id, isFavorite: !currentValue);
  }

  /// Remplace tous les ingrédients d'une recette.
  Future<void> replaceIngredients({
    required String recipeId,
    required List<IngredientInput> ingredients,
  }) async {
    final repo = ref.read(ingredientRepositoryProvider);
    await repo.replaceAll(recipeId: recipeId, ingredients: ingredients);
  }

  /// Met à jour une recette ET ses ingrédients en une transaction atomique.
  Future<void> updateRecipeWithIngredients({
    required String id,
    required String name,
    required String mealType,
    required int prepTimeMinutes,
    required int cookTimeMinutes,
    required int restTimeMinutes,
    required String season,
    required bool isVegetarian,
    required int servings,
    String? notes,
    String? variants,
    String? sourceUrl,
    String? photoPath,
    required List<IngredientInput> ingredients,
  }) async {
    final repo = ref.read(recipeRepositoryProvider);
    await repo.updateWithIngredients(
      id: id,
      name: name,
      mealType: mealType,
      prepTimeMinutes: prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes,
      restTimeMinutes: restTimeMinutes,
      season: season,
      isVegetarian: isVegetarian,
      servings: servings,
      notes: notes,
      variants: variants,
      sourceUrl: sourceUrl,
      photoPath: photoPath,
      ingredients: ingredients,
    );
  }

  /// Met à jour la photo d'une recette.
  Future<void> updatePhotoPath({
    required String id,
    required String? photoPath,
  }) async {
    final repo = ref.read(recipeRepositoryProvider);
    await repo.updatePhotoPath(id: id, photoPath: photoPath);
  }

  /// Remplace toutes les étapes de préparation d'une recette.
  Future<void> replaceSteps({
    required String recipeId,
    required List<RecipeStepInput> steps,
  }) async {
    final datasource = ref.read(recipeStepsDatasourceProvider);
    await datasource.replaceAll(recipeId: recipeId, steps: steps);
  }
}

final recipesNotifierProvider =
    AsyncNotifierProvider<RecipesNotifier, void>(RecipesNotifier.new);
