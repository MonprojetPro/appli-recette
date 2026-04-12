import 'dart:convert';

import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/sync/sync_queue_datasource.dart';
import 'package:appli_recette/features/recipes/data/datasources/ingredient_local_datasource.dart';
import 'package:appli_recette/features/recipes/domain/repositories/ingredient_repository.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Implémentation concrète du IngredientRepository.
/// Ecrit d'abord en local (drift) puis enqueue l'opération dans la sync_queue
/// pour qu'elle soit pushée vers Supabase lors du prochain cycle de sync.
class IngredientRepositoryImpl implements IngredientRepository {
  IngredientRepositoryImpl(this._datasource, this._syncQueue);

  final IngredientLocalDatasource _datasource;
  final SyncQueueDatasource _syncQueue;

  static const _keyHouseholdId = 'household_id';

  Future<String?> _getHouseholdId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyHouseholdId);
  }

  Map<String, dynamic> _ingredientPayload({
    required String id,
    required String recipeId,
    required String name,
    double? quantity,
    String? unit,
    String? supermarketSection,
    String? householdId,
  }) {
    return {
      'id': id,
      'recipe_id': recipeId,
      'name': name,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (supermarketSection != null)
        'supermarket_section': supermarketSection,
      if (householdId != null) 'household_id': householdId,
    };
  }

  @override
  Stream<List<Ingredient>> watchForRecipe(String recipeId) =>
      _datasource.watchForRecipe(recipeId);

  @override
  Future<String> add({
    required String recipeId,
    required String name,
    double? quantity,
    String? unit,
    String? supermarketSection,
  }) async {
    final id = const Uuid().v4();
    final companion = IngredientsCompanion.insert(
      id: id,
      recipeId: recipeId,
      name: name,
      quantity: Value(quantity),
      unit: Value(unit),
      supermarketSection: Value(supermarketSection),
    );
    await _datasource.insert(companion);

    final householdId = await _getHouseholdId();
    await _syncQueue.enqueue(
      SyncQueueCompanion.insert(
        id: const Uuid().v4(),
        operation: 'insert',
        entityTable: 'ingredients',
        recordId: id,
        payload: jsonEncode(_ingredientPayload(
          id: id,
          recipeId: recipeId,
          name: name,
          quantity: quantity,
          unit: unit,
          supermarketSection: supermarketSection,
          householdId: householdId,
        )),
        createdAt: DateTime.now(),
      ),
    );
    return id;
  }

  @override
  Future<void> update({
    required String id,
    required String name,
    double? quantity,
    String? unit,
    String? supermarketSection,
  }) async {
    final companion = IngredientsCompanion(
      id: Value(id),
      name: Value(name),
      quantity: Value(quantity),
      unit: Value(unit),
      supermarketSection: Value(supermarketSection),
    );
    await _datasource.update(companion);

    // Update partiel Supabase : .update() + .eq('id') ne touche que les
    // colonnes présentes dans le payload. Pas besoin du recipe_id ici.
    await _syncQueue.enqueue(
      SyncQueueCompanion.insert(
        id: const Uuid().v4(),
        operation: 'update',
        entityTable: 'ingredients',
        recordId: id,
        payload: jsonEncode({
          'id': id,
          'name': name,
          if (quantity != null) 'quantity': quantity,
          if (unit != null) 'unit': unit,
          if (supermarketSection != null)
            'supermarket_section': supermarketSection,
        }),
        createdAt: DateTime.now(),
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
        entityTable: 'ingredients',
        recordId: id,
        payload: jsonEncode({'id': id}),
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> deleteAllForRecipe(String recipeId) async {
    final existing = await _datasource.listForRecipe(recipeId);
    await _datasource.deleteAllForRecipe(recipeId);
    for (final ing in existing) {
      await _syncQueue.enqueue(
        SyncQueueCompanion.insert(
          id: const Uuid().v4(),
          operation: 'delete',
          entityTable: 'ingredients',
          recordId: ing.id,
          payload: jsonEncode({'id': ing.id}),
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  Future<void> replaceAll({
    required String recipeId,
    required List<IngredientInput> ingredients,
  }) async {
    // 1. Lister les anciens pour pouvoir les delete côté cloud.
    final oldIngredients = await _datasource.listForRecipe(recipeId);

    // 2. Remplacer en local (transaction atomique drift).
    await _datasource.replaceAll(recipeId: recipeId, ingredients: ingredients);

    // 3. Enqueue les deletes pour les anciens ids.
    for (final old in oldIngredients) {
      await _syncQueue.enqueue(
        SyncQueueCompanion.insert(
          id: const Uuid().v4(),
          operation: 'delete',
          entityTable: 'ingredients',
          recordId: old.id,
          payload: jsonEncode({'id': old.id}),
          createdAt: DateTime.now(),
        ),
      );
    }

    // 4. Enqueue les inserts pour les nouveaux.
    final householdId = await _getHouseholdId();
    // Les nouveaux ids ne sont pas exposés par le datasource.replaceAll
    // (il génère les UUID en interne). On relit la liste post-replaceAll
    // pour récupérer les ids réels assignés.
    final newIngredients = await _datasource.listForRecipe(recipeId);
    for (final ing in newIngredients) {
      await _syncQueue.enqueue(
        SyncQueueCompanion.insert(
          id: const Uuid().v4(),
          operation: 'insert',
          entityTable: 'ingredients',
          recordId: ing.id,
          payload: jsonEncode(_ingredientPayload(
            id: ing.id,
            recipeId: recipeId,
            name: ing.name,
            quantity: ing.quantity,
            unit: ing.unit,
            supermarketSection: ing.supermarketSection,
            householdId: householdId,
          )),
          createdAt: DateTime.now(),
        ),
      );
    }
  }
}
