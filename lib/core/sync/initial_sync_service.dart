import 'package:appli_recette/core/database/app_database.dart';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Synchronisation initiale depuis Supabase vers drift local.
///
/// Utilisé lors du join d'un foyer existant — télécharge toutes les entités
/// du foyer filtrées par [householdId] et les upserte dans drift.
/// Les entrées importées sont marquées isSynced = true.
class InitialSyncService {
  InitialSyncService(this._db);

  final AppDatabase _db;

  SupabaseClient get _client => Supabase.instance.client;

  /// Télécharge toutes les données du foyer [householdId] depuis Supabase
  /// et les upserte dans drift.
  /// Supprime d'abord les données locales appartenant à un autre foyer.
  /// Initialise aussi les présences par défaut pour tout membre sans planning.
  Future<void> syncFromSupabase(String householdId) async {
    await _cleanStaleData(householdId);
    await _syncMembers(householdId);
    await _syncRecipes(householdId);
    await _syncIngredients(householdId);
    await _syncRecipeSteps(householdId);
    await _initMissingPresences(householdId);
  }

  // ── Nettoyage données périmées ────────────────────────────────────────────

  /// Supprime les membres et recettes locaux qui n'appartiennent pas au foyer [householdId].
  /// Cela évite l'accumulation de données provenant de foyers précédents.
  Future<void> _cleanStaleData(String householdId) async {
    await _db.transaction(() async {
      // Supprimer les membres d'un autre foyer (cascade vers meal_ratings et presence_schedules)
      await (_db.delete(_db.members)
            ..where(
              (t) =>
                  t.householdId.isNull() |
                  t.householdId.equals(householdId).not(),
            ))
          .go();

      // Supprimer les recettes d'un autre foyer (cascade vers ingredients)
      await (_db.delete(_db.recipes)
            ..where(
              (t) =>
                  t.householdId.isNull() |
                  t.householdId.equals(householdId).not(),
            ))
          .go();
    });
  }

  // ── Members ───────────────────────────────────────────────────────────────

  Future<void> _syncMembers(String householdId) async {
    final rows = await _client
        .from('members')
        .select()
        .eq('household_id', householdId);

    final list = rows as List<dynamic>;
    final companions = <MembersCompanion>[];
    var skipped = 0;
    for (final row in list) {
      try {
        final m = row as Map<String, dynamic>;
        companions.add(MembersCompanion(
          id: Value(m['id'] as String),
          name: Value(m['name'] as String),
          age: Value(m['age'] as int?),
          householdId: Value(householdId),
          createdAt: Value(_parseDate(m['created_at'])),
          updatedAt: Value(_parseDate(m['updated_at'])),
          isSynced: const Value(true),
        ));
      } catch (e) {
        skipped++;
        debugPrint('[InitialSync] members skipped row=${(row as Map?)?['id']} err=$e');
      }
    }
    debugPrint('[InitialSync] members fetched=${list.length} parsed=${companions.length} skipped=$skipped');
    await _insertWithFallback(
      table: _db.members,
      companions: companions,
      label: 'members',
    );
  }

  // ── Recipes ───────────────────────────────────────────────────────────────

  Future<void> _syncRecipes(String householdId) async {
    final rows = await _client
        .from('recipes')
        .select()
        .eq('household_id', householdId);

    final list = rows as List<dynamic>;
    final companions = <RecipesCompanion>[];
    var skipped = 0;
    for (final row in list) {
      try {
        final r = row as Map<String, dynamic>;
        companions.add(RecipesCompanion(
          id: Value(r['id'] as String),
          name: Value((r['name'] as String?) ?? 'Sans nom'),
          mealType: Value((r['meal_type'] as String?) ?? 'dinner'),
          prepTimeMinutes:
              Value((r['prep_time_minutes'] as num?)?.toInt() ?? 0),
          cookTimeMinutes:
              Value((r['cook_time_minutes'] as num?)?.toInt() ?? 0),
          restTimeMinutes:
              Value((r['rest_time_minutes'] as num?)?.toInt() ?? 0),
          season: Value(r['season'] as String? ?? 'all'),
          isVegetarian: Value(r['is_vegetarian'] as bool? ?? false),
          servings: Value((r['servings'] as num?)?.toInt() ?? 4),
          notes: Value(r['notes'] as String?),
          variants: Value(r['variants'] as String?),
          sourceUrl: Value(r['source_url'] as String?),
          photoPath: Value(r['photo_path'] as String?),
          isFavorite: Value(r['is_favorite'] as bool? ?? false),
          createdAt: Value(_parseDate(r['created_at'])),
          updatedAt: Value(_parseDate(r['updated_at'])),
          householdId: Value(householdId),
          isSynced: const Value(true),
        ));
      } catch (e) {
        skipped++;
        debugPrint('[InitialSync] recipes skipped row=${(row as Map?)?['id']} err=$e');
      }
    }
    debugPrint('[InitialSync] recipes fetched=${list.length} parsed=${companions.length} skipped=$skipped');
    await _insertWithFallback(
      table: _db.recipes,
      companions: companions,
      label: 'recipes',
    );
  }

  // ── Ingredients ──────────────────────────────────────────────────────────

  Future<void> _syncIngredients(String householdId) async {
    final rows = await _client
        .from('ingredients')
        .select()
        .eq('household_id', householdId);

    final list = rows as List<dynamic>;
    final companions = <IngredientsCompanion>[];
    var skipped = 0;
    for (final row in list) {
      try {
        final r = row as Map<String, dynamic>;
        companions.add(IngredientsCompanion(
          id: Value(r['id'] as String),
          recipeId: Value(r['recipe_id'] as String),
          name: Value((r['name'] as String?) ?? ''),
          quantity: Value((r['quantity'] as num?)?.toDouble()),
          unit: Value(r['unit'] as String?),
          supermarketSection: Value(r['supermarket_section'] as String?),
          householdId: Value(householdId),
        ));
      } catch (e) {
        skipped++;
        debugPrint('[InitialSync] ingredients skipped row=${(row as Map?)?['id']} err=$e');
      }
    }
    debugPrint('[InitialSync] ingredients fetched=${list.length} parsed=${companions.length} skipped=$skipped');
    await _insertWithFallback(
      table: _db.ingredients,
      companions: companions,
      label: 'ingredients',
    );
  }

  // ── RecipeSteps ─────────────────────────────────────────────────────────

  Future<void> _syncRecipeSteps(String householdId) async {
    // recipe_steps n'a pas de household_id — RLS filtre via recipes.household_id
    final rows = await _client
        .from('recipe_steps')
        .select();

    final list = rows as List<dynamic>;
    final companions = <RecipeStepsCompanion>[];
    var skipped = 0;
    for (final row in list) {
      try {
        final r = row as Map<String, dynamic>;
        companions.add(RecipeStepsCompanion(
          id: Value(r['id'] as String),
          recipeId: Value(r['recipe_id'] as String),
          stepNumber: Value((r['step_number'] as num?)?.toInt() ?? 0),
          instruction: Value(r['instruction'] as String?),
          photoPathsJson: Value(r['photo_paths_json'] as String?),
        ));
      } catch (e) {
        skipped++;
        debugPrint('[InitialSync] recipe_steps skipped row=${(row as Map?)?['id']} err=$e');
      }
    }
    debugPrint('[InitialSync] recipe_steps fetched=${list.length} parsed=${companions.length} skipped=$skipped');
    await _insertWithFallback(
      table: _db.recipeSteps,
      companions: companions,
      label: 'recipe_steps',
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Parse une date Supabase, retourne now() si null/invalide.
  DateTime _parseDate(dynamic value) {
    if (value is String) {
      final d = DateTime.tryParse(value);
      if (d != null) return d.toLocal();
    }
    return DateTime.now();
  }

  /// Tente un insert batch atomique. Si le batch échoue (contrainte unique,
  /// FK manquante…), retombe sur des inserts unitaires pour qu'une seule ligne
  /// défaillante ne bloque pas tout le pull. Logge le détail.
  Future<void> _insertWithFallback({
    required TableInfo<Table, dynamic> table,
    required List<Insertable<dynamic>> companions,
    required String label,
  }) async {
    if (companions.isEmpty) return;
    try {
      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(table, companions);
      });
      debugPrint('[InitialSync] $label batch insert OK count=${companions.length}');
      return;
    } catch (e) {
      debugPrint('[InitialSync] $label batch failed err=$e — fallback per-row');
    }
    var ok = 0;
    var ko = 0;
    for (final c in companions) {
      try {
        await _db
            .into(table)
            .insertOnConflictUpdate(c);
        ok++;
      } catch (e) {
        ko++;
        debugPrint('[InitialSync] $label per-row insert failed err=$e');
      }
    }
    debugPrint('[InitialSync] $label per-row done ok=$ok ko=$ko');
  }

  // ── Présences par défaut ─────────────────────────────────────────────────

  /// Crée 14 entrées de présence (7 jours × 2 repas, tous présents)
  /// pour chaque membre qui n'en a pas encore dans la DB locale.
  Future<void> _initMissingPresences(String householdId) async {
    // IDs des membres déjà syncés localement
    final memberRows = await (_db.select(_db.members)
          ..where((m) => m.householdId.equals(householdId)))
        .get();

    if (memberRows.isEmpty) return;

    // IDs des membres qui ont déjà un planning type (weekKey null)
    final existingQuery =
        _db.selectOnly(_db.presenceSchedules, distinct: true)
          ..addColumns([_db.presenceSchedules.memberId])
          ..where(_db.presenceSchedules.weekKey.isNull());
    final existingRows = await existingQuery.get();
    final existingIds =
        existingRows.map((r) => r.read(_db.presenceSchedules.memberId)!).toSet();

    final missing =
        memberRows.where((m) => !existingIds.contains(m.id)).toList();
    if (missing.isEmpty) return;

    await _db.batch((batch) {
      for (final member in missing) {
        for (var day = 1; day <= 7; day++) {
          for (final slot in ['lunch', 'dinner']) {
            batch.insert(
              _db.presenceSchedules,
              PresenceSchedulesCompanion.insert(
                id: const Uuid().v4(),
                memberId: member.id,
                dayOfWeek: day,
                mealSlot: slot,
                householdId: Value(householdId),
              ),
            );
          }
        }
      }
    });
  }
}
