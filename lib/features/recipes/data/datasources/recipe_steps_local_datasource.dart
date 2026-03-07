import 'dart:convert';

import 'package:appli_recette/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Datasource local pour les étapes de préparation.
class RecipeStepsLocalDatasource {
  const RecipeStepsLocalDatasource(this._db);

  final AppDatabase _db;

  /// Stream des étapes d'une recette, ordonnées par [stepNumber].
  Stream<List<RecipeStep>> watchForRecipe(String recipeId) {
    return (_db.select(_db.recipeSteps)
          ..where((t) => t.recipeId.equals(recipeId))
          ..orderBy([(t) => OrderingTerm.asc(t.stepNumber)]))
        .watch();
  }

  /// Remplace toutes les étapes d'une recette (supprime puis recrée).
  Future<void> replaceAll({
    required String recipeId,
    required List<RecipeStepInput> steps,
  }) async {
    await _db.transaction(() async {
      // Supprimer toutes les étapes existantes
      await (_db.delete(_db.recipeSteps)
            ..where((t) => t.recipeId.equals(recipeId)))
          .go();

      // Recréer dans l'ordre
      for (var i = 0; i < steps.length; i++) {
        final step = steps[i];
        await _db.into(_db.recipeSteps).insert(
              RecipeStepsCompanion.insert(
                id: const Uuid().v4(),
                recipeId: recipeId,
                stepNumber: i + 1,
                instruction: Value(step.instruction),
                photoPathsJson: Value(
                  step.photoPaths.isEmpty
                      ? null
                      : jsonEncode(step.photoPaths),
                ),
              ),
            );
      }
    });
  }

  /// Supprime toutes les étapes d'une recette.
  Future<void> deleteAll(String recipeId) async {
    await (_db.delete(_db.recipeSteps)
          ..where((t) => t.recipeId.equals(recipeId)))
        .go();
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
