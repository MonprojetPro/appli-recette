import 'package:appli_recette/core/database/app_database.dart';
import 'package:drift/drift.dart';

/// Source de données locale pour les notations de repas (drift / SQLite).
class MealRatingDatasource {
  MealRatingDatasource(this._db);

  final AppDatabase _db;

  /// Stream de toutes les notations (tous membres, toutes recettes).
  Stream<List<MealRating>> watchAll() {
    return _db.select(_db.mealRatings).watch();
  }

  /// Stream des notations filtrées par liste de memberId (foyer courant).
  Stream<List<MealRating>> watchForMembers(List<String> memberIds) {
    if (memberIds.isEmpty) return Stream.value([]);
    return (_db.select(_db.mealRatings)
          ..where((t) => t.memberId.isIn(memberIds)))
        .watch();
  }

  /// Stream des notations pour une recette donnée.
  Stream<List<MealRating>> watchForRecipe(String recipeId) {
    return (_db.select(_db.mealRatings)
          ..where((t) => t.recipeId.equals(recipeId)))
        .watch();
  }

  /// Upsert : crée ou met à jour la notation d'un membre pour une recette.
  /// Si une notation (memberId, recipeId) existe déjà, elle est mise à jour.
  /// Sinon, une nouvelle ligne est insérée avec l'[id] fourni.
  /// Opération atomique via transaction pour éviter les race conditions.
  Future<void> upsert({
    required String id,
    required String memberId,
    required String recipeId,
    required String ratingValue,
  }) async {
    await _db.transaction(() async {
      // Tenter la mise à jour d'abord (clé unique : memberId + recipeId)
      final updated = await (_db.update(_db.mealRatings)
            ..where(
              (t) =>
                  t.memberId.equals(memberId) & t.recipeId.equals(recipeId),
            ))
          .write(
        MealRatingsCompanion(
          rating: Value(ratingValue),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ),
      );

      // Insérer si aucune ligne existante
      if (updated == 0) {
        await _db.into(_db.mealRatings).insert(
              MealRatingsCompanion.insert(
                id: id,
                memberId: memberId,
                recipeId: recipeId,
                rating: ratingValue,
                updatedAt: DateTime.now(),
              ),
            );
      }
    });
  }

  /// Supprime la notation d'un membre pour une recette.
  Future<void> deleteForMemberAndRecipe({
    required String memberId,
    required String recipeId,
  }) async {
    await (_db.delete(_db.mealRatings)
          ..where(
            (t) =>
                t.memberId.equals(memberId) & t.recipeId.equals(recipeId),
          ))
        .go();
  }

  /// Supprime toutes les notations d'une recette (utilisé avant de supprimer
  /// la recette si la cascade FK n'est pas activée au moment de l'appel).
  Future<void> deleteForRecipe(String recipeId) async {
    await (_db.delete(_db.mealRatings)
          ..where((t) => t.recipeId.equals(recipeId)))
        .go();
  }
}
