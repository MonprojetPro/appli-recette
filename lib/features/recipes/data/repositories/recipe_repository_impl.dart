import 'dart:convert';

import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/sync/sync_queue_datasource.dart';
import 'package:appli_recette/features/recipes/data/datasources/recipe_local_datasource.dart';
import 'package:appli_recette/features/recipes/domain/repositories/ingredient_repository.dart';
import 'package:appli_recette/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Implémentation concrète du RecipeRepository.
/// Délègue au datasource local (drift) et enfile dans la sync_queue.
class RecipeRepositoryImpl implements RecipeRepository {
  RecipeRepositoryImpl(this._datasource, this._syncQueue);

  final RecipeLocalDatasource _datasource;
  final SyncQueueDatasource _syncQueue;

  static const _keyHouseholdId = 'household_id';

  Future<String?> _getHouseholdId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyHouseholdId);
  }

  @override
  Stream<List<Recipe>> watchAll(String householdId) =>
      _datasource.watchAll(householdId);

  @override
  Stream<List<Recipe>> watchBySearch(String query, String householdId) =>
      _datasource.watchBySearch(query, householdId);

  @override
  Future<Recipe?> getById(String id) => _datasource.getById(id);

  @override
  Stream<Recipe?> watchById(String id) => _datasource.watchById(id);

  @override
  Future<String> create({
    required String name,
    required String mealType,
    required int prepTimeMinutes,
    int cookTimeMinutes = 0,
    int restTimeMinutes = 0,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    final householdId = await _getHouseholdId();
    final companion = RecipesCompanion.insert(
      id: id,
      name: name,
      mealType: mealType,
      prepTimeMinutes: Value(prepTimeMinutes),
      cookTimeMinutes: Value(cookTimeMinutes),
      restTimeMinutes: Value(restTimeMinutes),
      createdAt: now,
      updatedAt: now,
      householdId: Value(householdId),
    );
    final result = await _datasource.insert(companion);
    await _syncQueue.enqueue(
      SyncQueueCompanion.insert(
        id: const Uuid().v4(),
        operation: 'insert',
        entityTable: 'recipes',
        recordId: id,
        payload: jsonEncode({
          'id': id,
          'name': name,
          'meal_type': mealType,
          'prep_time_minutes': prepTimeMinutes,
          'cook_time_minutes': cookTimeMinutes,
          'rest_time_minutes': restTimeMinutes,
          'season': 'all',
          'is_vegetarian': false,
          'is_favorite': false,
          'servings': 4,
          'created_at': now.toUtc().toIso8601String(),
          'updated_at': now.toUtc().toIso8601String(),
          if (householdId != null) 'household_id': householdId,
        }),
        createdAt: now,
      ),
    );
    return result;
  }

  @override
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
  }) async {
    final now = DateTime.now();
    final companion = RecipesCompanion(
      id: Value(id),
      name: Value(name),
      mealType: Value(mealType),
      prepTimeMinutes: Value(prepTimeMinutes),
      cookTimeMinutes: Value(cookTimeMinutes),
      restTimeMinutes: Value(restTimeMinutes),
      season: Value(season),
      isVegetarian: Value(isVegetarian),
      servings: Value(servings),
      notes: Value(notes),
      variants: Value(variants),
      sourceUrl: Value(sourceUrl),
      photoPath: Value(photoPath),
      updatedAt: Value(now),
    );
    await _datasource.update(companion);

    final householdId = await _getHouseholdId();
    await _syncQueue.enqueue(
      SyncQueueCompanion.insert(
        id: const Uuid().v4(),
        operation: 'update',
        entityTable: 'recipes',
        recordId: id,
        payload: jsonEncode({
          'id': id,
          'name': name,
          'meal_type': mealType,
          'prep_time_minutes': prepTimeMinutes,
          'cook_time_minutes': cookTimeMinutes,
          'rest_time_minutes': restTimeMinutes,
          'season': season,
          'is_vegetarian': isVegetarian,
          'servings': servings,
          if (notes != null) 'notes': notes,
          if (variants != null) 'variants': variants,
          if (sourceUrl != null) 'source_url': sourceUrl,
          if (photoPath != null) 'photo_path': photoPath,
          'updated_at': now.toUtc().toIso8601String(),
          if (householdId != null) 'household_id': householdId,
        }),
        createdAt: now,
      ),
    );
  }

  @override
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
  }) async {
    final now = DateTime.now();
    final companion = RecipesCompanion(
      id: Value(id),
      name: Value(name),
      mealType: Value(mealType),
      prepTimeMinutes: Value(prepTimeMinutes),
      cookTimeMinutes: Value(cookTimeMinutes),
      restTimeMinutes: Value(restTimeMinutes),
      season: Value(season),
      isVegetarian: Value(isVegetarian),
      servings: Value(servings),
      notes: Value(notes),
      variants: Value(variants),
      sourceUrl: Value(sourceUrl),
      photoPath: Value(photoPath),
      updatedAt: Value(now),
    );
    await _datasource.updateWithIngredients(
      recipeCompanion: companion,
      recipeId: id,
      ingredients: ingredients,
    );

    final householdId = await _getHouseholdId();
    await _syncQueue.enqueue(
      SyncQueueCompanion.insert(
        id: const Uuid().v4(),
        operation: 'update',
        entityTable: 'recipes',
        recordId: id,
        payload: jsonEncode({
          'id': id,
          'name': name,
          'meal_type': mealType,
          'prep_time_minutes': prepTimeMinutes,
          'cook_time_minutes': cookTimeMinutes,
          'rest_time_minutes': restTimeMinutes,
          'season': season,
          'is_vegetarian': isVegetarian,
          'servings': servings,
          if (notes != null) 'notes': notes,
          if (variants != null) 'variants': variants,
          if (sourceUrl != null) 'source_url': sourceUrl,
          if (photoPath != null) 'photo_path': photoPath,
          'updated_at': now.toUtc().toIso8601String(),
          if (householdId != null) 'household_id': householdId,
        }),
        createdAt: now,
      ),
    );
  }

  @override
  Future<void> delete(String id) async {
    await _datasource.delete(id);
    await _syncQueue.enqueue(
      SyncQueueCompanion.insert(
        id: const Uuid().v4(),
        operation: 'delete',
        entityTable: 'recipes',
        recordId: id,
        payload: jsonEncode({'id': id}),
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> setFavorite({
    required String id,
    required bool isFavorite,
  }) async {
    await _datasource.updateFavorite(id: id, isFavorite: isFavorite);
    final now = DateTime.now();
    await _syncQueue.enqueue(
      SyncQueueCompanion.insert(
        id: const Uuid().v4(),
        operation: 'update',
        entityTable: 'recipes',
        recordId: id,
        payload: jsonEncode({
          'id': id,
          'is_favorite': isFavorite,
          'updated_at': now.toUtc().toIso8601String(),
        }),
        createdAt: now,
      ),
    );
  }

  @override
  Future<void> updatePhotoPath({
    required String id,
    required String? photoPath,
  }) async {
    await _datasource.updatePhotoPath(id: id, photoPath: photoPath);
    final now = DateTime.now();
    await _syncQueue.enqueue(
      SyncQueueCompanion.insert(
        id: const Uuid().v4(),
        operation: 'update',
        entityTable: 'recipes',
        recordId: id,
        payload: jsonEncode({
          'id': id,
          'photo_path': photoPath,
          'updated_at': now.toUtc().toIso8601String(),
        }),
        createdAt: now,
      ),
    );
  }
}
