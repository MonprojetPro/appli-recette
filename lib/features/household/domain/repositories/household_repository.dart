import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/features/household/data/models/rating_value.dart';

/// Interface du Repository Foyer.
/// La couche présentation dépend uniquement de cette interface.
abstract class HouseholdRepository {
  // ── Membres ──────────────────────────────────────────────────────────────

  /// Stream de tous les membres du foyer, ordonnés par date de création ASC.
  Stream<List<Member>> watchAll(String householdId);

  /// Crée un nouveau membre. Retourne l'ID UUID v4 créé.
  Future<String> addMember({required String name, int? age});

  /// Met à jour un membre existant.
  Future<void> updateMember({
    required String id,
    required String name,
    int? age,
  });

  /// Supprime un membre par son ID.
  /// La suppression cascade automatiquement vers meal_ratings et presence_schedules
  /// grâce aux FK avec onDelete: cascade et PRAGMA foreign_keys = ON.
  Future<void> deleteMember(String id);

  // ── Notations ─────────────────────────────────────────────────────────────

  /// Stream des notations pour une recette donnée.
  Stream<List<MealRating>> watchRatingsForRecipe(String recipeId);

  /// Crée ou met à jour la notation d'un membre pour une recette.
  Future<void> upsertRating({
    required String memberId,
    required String recipeId,
    required RatingValue rating,
  });

  /// Supprime la notation d'un membre pour une recette (désélection).
  Future<void> deleteRating({
    required String memberId,
    required String recipeId,
  });

  /// Supprime toutes les notations liées à une recette.
  Future<void> deleteRatingsForRecipe(String recipeId);
}
