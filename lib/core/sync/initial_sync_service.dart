import 'package:appli_recette/core/database/app_database.dart';
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
  /// Initialise aussi les présences par défaut pour tout membre sans planning.
  Future<void> syncFromSupabase(String householdId) async {
    await _syncMembers(householdId);
    await _syncRecipes(householdId);
    await _syncIngredients(householdId);
    await _syncRecipeSteps(householdId);
    await _initMissingPresences(householdId);
  }

  // ── Members ───────────────────────────────────────────────────────────────

  Future<void> _syncMembers(String householdId) async {
    final rows = await _client
        .from('members')
        .select()
        .eq('household_id', householdId);

    final companions = (rows as List<dynamic>).map((row) {
      final m = row as Map<String, dynamic>;
      return MembersCompanion(
        id: Value(m['id'] as String),
        name: Value(m['name'] as String),
        age: Value(m['age'] as int?),
        householdId: Value(householdId),
        createdAt:
            Value(DateTime.parse(m['created_at'] as String).toLocal()),
        updatedAt:
            Value(DateTime.parse(m['updated_at'] as String).toLocal()),
        isSynced: const Value(true),
      );
    }).toList();

    if (companions.isNotEmpty) {
      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(_db.members, companions);
      });
    }
  }

  // ── Recipes ───────────────────────────────────────────────────────────────

  Future<void> _syncRecipes(String householdId) async {
    final rows = await _client
        .from('recipes')
        .select()
        .eq('household_id', householdId);

    final companions = (rows as List<dynamic>).map((row) {
      final r = row as Map<String, dynamic>;
      return RecipesCompanion(
        id: Value(r['id'] as String),
        name: Value(r['name'] as String),
        mealType: Value(r['meal_type'] as String),
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
        createdAt:
            Value(DateTime.parse(r['created_at'] as String).toLocal()),
        updatedAt:
            Value(DateTime.parse(r['updated_at'] as String).toLocal()),
        householdId: Value(householdId),
        isSynced: const Value(true),
      );
    }).toList();

    if (companions.isNotEmpty) {
      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(_db.recipes, companions);
      });
    }
  }

  // ── Ingredients ──────────────────────────────────────────────────────────

  Future<void> _syncIngredients(String householdId) async {
    final rows = await _client
        .from('ingredients')
        .select()
        .eq('household_id', householdId);

    final companions = (rows as List<dynamic>).map((row) {
      final r = row as Map<String, dynamic>;
      return IngredientsCompanion(
        id: Value(r['id'] as String),
        recipeId: Value(r['recipe_id'] as String),
        name: Value(r['name'] as String),
        quantity: Value((r['quantity'] as num?)?.toDouble()),
        unit: Value(r['unit'] as String?),
        supermarketSection: Value(r['supermarket_section'] as String?),
        householdId: Value(householdId),
      );
    }).toList();

    if (companions.isNotEmpty) {
      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(_db.ingredients, companions);
      });
    }
  }

  // ── RecipeSteps ─────────────────────────────────────────────────────────

  Future<void> _syncRecipeSteps(String householdId) async {
    // recipe_steps n'a pas de household_id — RLS filtre via recipes.household_id
    // Récupère tous les recipe_steps accessibles (filtrés par RLS)
    final rows = await _client
        .from('recipe_steps')
        .select();

    final companions = (rows as List<dynamic>).map((row) {
      final r = row as Map<String, dynamic>;
      return RecipeStepsCompanion(
        id: Value(r['id'] as String),
        recipeId: Value(r['recipe_id'] as String),
        stepNumber: Value((r['step_number'] as num).toInt()),
        instruction: Value(r['instruction'] as String?),
        photoPathsJson: Value(r['photo_paths_json'] as String?),
      );
    }).toList();

    if (companions.isNotEmpty) {
      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(_db.recipeSteps, companions);
      });
    }
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
