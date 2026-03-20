import 'dart:convert';

import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/sync/sync_queue_datasource.dart';
import 'package:appli_recette/features/household/data/datasources/meal_rating_datasource.dart';
import 'package:appli_recette/features/household/data/datasources/member_local_datasource.dart';
import 'package:appli_recette/features/household/data/models/rating_value.dart';
import 'package:appli_recette/features/household/domain/repositories/household_repository.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Implémentation concrète du HouseholdRepository.
/// Délègue aux datasources locaux (drift) et enfile dans la sync_queue.
class HouseholdRepositoryImpl implements HouseholdRepository {
  HouseholdRepositoryImpl(
    this._memberDatasource,
    this._ratingDatasource,
    this._syncQueue,
  );

  final MemberLocalDatasource _memberDatasource;
  final MealRatingDatasource _ratingDatasource;
  final SyncQueueDatasource _syncQueue;

  static const _keyHouseholdId = 'household_id';

  Future<String?> _getHouseholdId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyHouseholdId);
  }

  // ── Membres ──────────────────────────────────────────────────────────────

  @override
  Stream<List<Member>> watchAll(String householdId) =>
      _memberDatasource.watchAll(householdId);

  @override
  Future<String> addMember({required String name, int? age}) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    final householdId = await _getHouseholdId();
    final companion = MembersCompanion.insert(
      id: id,
      name: name,
      age: age != null ? Value(age) : const Value.absent(),
      householdId:
          householdId != null ? Value(householdId) : const Value.absent(),
      createdAt: now,
      updatedAt: now,
    );
    final result = await _memberDatasource.insert(companion);
    await _syncQueue.enqueue(
      SyncQueueCompanion.insert(
        id: const Uuid().v4(),
        operation: 'insert',
        entityTable: 'members',
        recordId: id,
        payload: jsonEncode({
          'id': id,
          'name': name,
          if (age != null) 'age': age,
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
  Future<void> updateMember({
    required String id,
    required String name,
    int? age,
  }) async {
    final now = DateTime.now();
    final companion = MembersCompanion(
      id: Value(id),
      name: Value(name),
      age: Value(age),
      updatedAt: Value(now),
    );
    await _memberDatasource.update(companion);

    final householdId = await _getHouseholdId();
    await _syncQueue.enqueue(
      SyncQueueCompanion.insert(
        id: const Uuid().v4(),
        operation: 'update',
        entityTable: 'members',
        recordId: id,
        payload: jsonEncode({
          'id': id,
          'name': name,
          'age': age,
          'updated_at': now.toUtc().toIso8601String(),
          if (householdId != null) 'household_id': householdId,
        }),
        createdAt: now,
      ),
    );
  }

  @override
  Future<void> deleteMember(String id) async {
    await _memberDatasource.delete(id);
    await _syncQueue.enqueue(
      SyncQueueCompanion.insert(
        id: const Uuid().v4(),
        operation: 'delete',
        entityTable: 'members',
        recordId: id,
        payload: jsonEncode({'id': id}),
        createdAt: DateTime.now(),
      ),
    );
  }

  // ── Notations ─────────────────────────────────────────────────────────────

  @override
  Stream<List<MealRating>> watchRatingsForRecipe(String recipeId) =>
      _ratingDatasource.watchForRecipe(recipeId);

  @override
  Future<void> upsertRating({
    required String memberId,
    required String recipeId,
    required RatingValue rating,
  }) async {
    final id = const Uuid().v4();
    await _ratingDatasource.upsert(
      id: id,
      memberId: memberId,
      recipeId: recipeId,
      ratingValue: rating.dbValue,
    );

    final now = DateTime.now();
    final householdId = await _getHouseholdId();
    await _syncQueue.enqueue(
      SyncQueueCompanion.insert(
        id: const Uuid().v4(),
        operation: 'insert',
        entityTable: 'meal_ratings',
        recordId: id,
        payload: jsonEncode({
          'id': id,
          'member_id': memberId,
          'recipe_id': recipeId,
          'rating': rating.dbValue,
          'updated_at': now.toUtc().toIso8601String(),
          if (householdId != null) 'household_id': householdId,
        }),
        createdAt: now,
      ),
    );
  }

  @override
  Future<void> deleteRating({
    required String memberId,
    required String recipeId,
  }) async {
    await _ratingDatasource.deleteForMemberAndRecipe(
      memberId: memberId,
      recipeId: recipeId,
    );
    // Pour la notation, on enqueue un delete par la clé naturelle (member_id, recipe_id)
    // Le processor utilisera 'delete' avec ces colonnes
    await _syncQueue.enqueue(
      SyncQueueCompanion.insert(
        id: const Uuid().v4(),
        operation: 'delete',
        entityTable: 'meal_ratings',
        recordId: '$memberId:$recipeId', // clé naturelle pour le processor
        payload: jsonEncode({
          'member_id': memberId,
          'recipe_id': recipeId,
        }),
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> deleteRatingsForRecipe(String recipeId) =>
      _ratingDatasource.deleteForRecipe(recipeId);
}
