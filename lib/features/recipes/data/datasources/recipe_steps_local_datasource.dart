import 'dart:convert';

import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/sync/sync_queue_datasource.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Datasource local pour les étapes de préparation.
/// Ecrit d'abord en drift puis enqueue dans la sync_queue pour que les
/// opérations remontent vers Supabase au prochain cycle de sync.
class RecipeStepsLocalDatasource {
  const RecipeStepsLocalDatasource(this._db, this._syncQueue);

  final AppDatabase _db;
  final SyncQueueDatasource _syncQueue;

  /// Stream des étapes d'une recette, ordonnées par [stepNumber].
  Stream<List<RecipeStep>> watchForRecipe(String recipeId) {
    return (_db.select(_db.recipeSteps)
          ..where((t) => t.recipeId.equals(recipeId))
          ..orderBy([(t) => OrderingTerm.asc(t.stepNumber)]))
        .watch();
  }

  /// Liste synchrone (utile pour enqueue les deletes).
  Future<List<RecipeStep>> listForRecipe(String recipeId) {
    return (_db.select(_db.recipeSteps)
          ..where((t) => t.recipeId.equals(recipeId))
          ..orderBy([(t) => OrderingTerm.asc(t.stepNumber)]))
        .get();
  }

  /// Remplace toutes les étapes d'une recette (supprime puis recrée)
  /// ET enqueue les opérations cloud correspondantes.
  Future<void> replaceAll({
    required String recipeId,
    required List<RecipeStepInput> steps,
  }) async {
    final oldSteps = await listForRecipe(recipeId);

    final newSteps = <RecipeStepsCompanion>[];
    await _db.transaction(() async {
      await (_db.delete(_db.recipeSteps)
            ..where((t) => t.recipeId.equals(recipeId)))
          .go();

      for (var i = 0; i < steps.length; i++) {
        final step = steps[i];
        final companion = RecipeStepsCompanion.insert(
          id: const Uuid().v4(),
          recipeId: recipeId,
          stepNumber: i + 1,
          instruction: Value(step.instruction),
          photoPathsJson: Value(
            step.photoPaths.isEmpty ? null : jsonEncode(step.photoPaths),
          ),
        );
        newSteps.add(companion);
        await _db.into(_db.recipeSteps).insert(companion);
      }
    });

    // Enqueue deletes des anciens
    for (final old in oldSteps) {
      await _syncQueue.enqueue(
        SyncQueueCompanion.insert(
          id: const Uuid().v4(),
          operation: 'delete',
          entityTable: 'recipe_steps',
          recordId: old.id,
          payload: jsonEncode({'id': old.id}),
          createdAt: DateTime.now(),
        ),
      );
    }

    // Enqueue inserts des nouveaux
    for (final c in newSteps) {
      await _syncQueue.enqueue(
        SyncQueueCompanion.insert(
          id: const Uuid().v4(),
          operation: 'insert',
          entityTable: 'recipe_steps',
          recordId: c.id.value,
          payload: jsonEncode({
            'id': c.id.value,
            'recipe_id': c.recipeId.value,
            'step_number': c.stepNumber.value,
            if (c.instruction.present && c.instruction.value != null)
              'instruction': c.instruction.value,
            if (c.photoPathsJson.present && c.photoPathsJson.value != null)
              'photo_paths_json': c.photoPathsJson.value,
          }),
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  /// Supprime toutes les étapes d'une recette (local + enqueue deletes cloud).
  Future<void> deleteAll(String recipeId) async {
    final oldSteps = await listForRecipe(recipeId);
    await (_db.delete(_db.recipeSteps)
          ..where((t) => t.recipeId.equals(recipeId)))
        .go();

    for (final old in oldSteps) {
      await _syncQueue.enqueue(
        SyncQueueCompanion.insert(
          id: const Uuid().v4(),
          operation: 'delete',
          entityTable: 'recipe_steps',
          recordId: old.id,
          payload: jsonEncode({'id': old.id}),
          createdAt: DateTime.now(),
        ),
      );
    }
  }
}

/// Données d'entrée pour une étape de préparation.
class RecipeStepInput {
  const RecipeStepInput({
    this.instruction,
    this.photoPaths = const [],
  });

  final String? instruction;
  final List<String> photoPaths;
}

/// Extension utilitaire pour décoder les photos d'une étape.
extension RecipeStepX on RecipeStep {
  List<String> get photoPaths {
    if (photoPathsJson == null || photoPathsJson!.isEmpty) return [];
    try {
      final decoded = jsonDecode(photoPathsJson!);
      if (decoded is List) return decoded.cast<String>();
    } catch (_) {}
    return [];
  }
}
