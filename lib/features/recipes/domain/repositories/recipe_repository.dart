import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/features/recipes/domain/repositories/ingredient_repository.dart';

/// Interface du Repository Recettes.
/// La couche présentation dépend uniquement de cette interface.
abstract class RecipeRepository {
  /// Stream de toutes les recettes du foyer, ordonnées par date de création DESC.
  Stream<List<Recipe>> watchAll(String householdId);

  /// Stream filtré par recherche sur le nom, limité au foyer.
  Stream<List<Recipe>> watchBySearch(String query, String householdId);

  /// Récupère une recette par son ID.
  Future<Recipe?> getById(String id);

  /// Stream réactif d'une recette par son ID.
  Stream<Recipe?> watchById(String id);

  /// Sauvegarde une nouvelle recette. Retourne l'ID UUID v4 créé.
  Future<String> create({
    required String name,
    required String mealType,
    required int prepTimeMinutes,
    int cookTimeMinutes = 0,
    int restTimeMinutes = 0,
  });

  /// Met à jour tous les champs d'une recette.
  Future<void> update({
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
  });

  /// Met à jour une recette ET ses ingrédients en une transaction atomique.
  Future<void> updateWithIngredients({
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
  });

  /// Supprime une recette par son ID.
  Future<void> delete(String id);

  /// Met à jour le statut favori d'une recette.
  Future<void> setFavorite({required String id, required bool isFavorite});

  /// Met à jour uniquement le chemin photo d'une recette.
  Future<void> updatePhotoPath({required String id, required String? photoPath});
}
