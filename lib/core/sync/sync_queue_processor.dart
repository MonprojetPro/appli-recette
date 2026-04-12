import 'dart:convert';
import 'dart:developer';

import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/sync/sync_queue_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Rejoue les opérations en attente dans la sync_queue vers Supabase.
///
/// [SupabaseClient] est injecté pour permettre les tests unitaires avec mock.
class SyncQueueProcessor {
  SyncQueueProcessor(this._syncQueue, this._client);

  final SyncQueueDatasource _syncQueue;
  final SupabaseClient _client;

  static const _keyHouseholdId = 'household_id';
  static const _maxRetries = 3;

  /// Champs autorisés par table — whitelist pour éviter l'injection de colonnes.
  static const _tableFields = <String, Set<String>>{
    'recipes': {
      'id', 'name', 'meal_type', 'prep_time_minutes', 'cook_time_minutes',
      'rest_time_minutes', 'season', 'is_vegetarian', 'servings', 'notes',
      'variants', 'source_url', 'photo_path', 'is_favorite', 'household_id',
      'created_at', 'updated_at',
    },
    'members': {
      'id', 'name', 'age', 'household_id', 'created_at', 'updated_at',
    },
    'ingredients': {
      'id', 'recipe_id', 'name', 'quantity', 'unit', 'supermarket_section',
      'household_id',
    },
    'recipe_steps': {
      'id', 'recipe_id', 'step_number', 'instruction', 'photo_paths_json',
    },
    'meal_ratings': {
      'id', 'member_id', 'recipe_id', 'rating', 'household_id',
      'created_at', 'updated_at',
    },
    'presence_schedules': {
      'id', 'member_id', 'day_of_week', 'meal_slot', 'is_present',
      'week_override', 'household_id', 'created_at', 'updated_at',
    },
    'weekly_menus': {
      'id', 'household_id', 'week_key', 'generated_at', 'validated_at',
      'is_validated', 'created_at', 'updated_at',
    },
    'menu_slots': {
      'id', 'weekly_menu_id', 'recipe_id', 'day_of_week', 'meal_slot',
      'is_locked', 'household_id', 'created_at', 'updated_at',
    },
    'households': {
      'id', 'code', 'name', 'created_by', 'created_at', 'updated_at',
    },
  };

  /// Vérifie si un champ est autorisé pour une table donnée (pour les tests).
  static bool tableAllowsField(String table, String field) {
    return _tableFields[table]?.contains(field) ?? false;
  }

  /// Traite les opérations en attente.
  /// Skip silencieusement si pas de session Supabase (AC-8 Story 7.1).
  Future<void> processQueue() async {
    // Guard : auth absente → skip silencieux (AC-8)
    if (_client.auth.currentSession == null) return;

    final prefs = await SharedPreferences.getInstance();
    final householdId = prefs.getString(_keyHouseholdId);

    final entries = await _syncQueue.getOldestPending(limit: 50);
    for (final entry in entries) {
      await _processEntry(entry, householdId);
    }
  }

  Future<void> _processEntry(SyncQueueData entry, String? householdId) async {
    try {
      final payload = jsonDecode(entry.payload) as Map<String, dynamic>;

      // Inclure household_id dans tous les payloads si disponible (Story 7.3),
      // SAUF pour les tables qui n'ont pas cette colonne (recipe_steps).
      final allowedFields = _tableFields[entry.entityTable];
      final tableHasHouseholdId =
          allowedFields == null || allowedFields.contains('household_id');
      if (tableHasHouseholdId &&
          householdId != null &&
          !payload.containsKey('household_id')) {
        payload['household_id'] = householdId;
      }

      // Validation : ne garder que les clés attendues par la table cible
      if (allowedFields != null) {
        payload.removeWhere((key, _) => !allowedFields.contains(key));
      }

      switch (entry.operation) {
        case 'insert':
          // upsert : idempotent en cas de double-envoi
          await _client
              .from(entry.entityTable)
              .upsert(payload, onConflict: 'id');
        case 'update':
          // update partiel ou total : ne touche que les colonnes du payload
          await _client
              .from(entry.entityTable)
              .update(payload)
              .eq('id', entry.recordId);
        case 'delete':
          await _client
              .from(entry.entityTable)
              .delete()
              .eq('id', entry.recordId);
        default:
          log('SyncQueueProcessor: opération inconnue "${entry.operation}"');
      }

      await _syncQueue.markSuccess(entry.id);
    } catch (e) {
      log(
        'SyncQueueProcessor erreur sur '
        '${entry.entityTable}/${entry.recordId}: $e',
      );

      await _syncQueue.incrementRetry(entry.id, e.toString());

      // Dead letter après _maxRetries
      if (entry.retryCount + 1 >= _maxRetries) {
        log(
          'SyncQueueProcessor: dead letter pour ${entry.id} '
          'après $_maxRetries essais',
        );
        await _syncQueue.deleteProcessed();
      }
    }
  }
}
