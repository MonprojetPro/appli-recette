import 'dart:math';

import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/features/generation/domain/models/generation_filters.dart';
import 'package:appli_recette/features/generation/domain/models/generation_input.dart';
import 'package:appli_recette/features/generation/domain/models/meal_slot_result.dart';
import 'package:appli_recette/features/recipes/domain/models/season.dart';

/// Service de génération de menu hebdomadaire — classe Dart pure.
///
/// Aucun import Flutter/Material. 100% testable unitairement.
///
/// Algorithme en 6 couches séquentielles pour chaque créneau :
/// 1. Filtrage par type de repas + présences du créneau
/// 1bis. Filtres utilisateur (temps, végé, saison)
/// 2. Exclusion des recettes "pas aimé" par un membre présent
/// 3+4. Priorisation : favoris > aimés > neutres
/// 5. Anti-répétition (menus validés précédents)
/// 6. Complétion aléatoire (seed reproductible)
class GenerationService {
  GenerationService({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// Point d'entrée principal.
  ///
  /// Retourne une liste de 14 éléments [MealSlotResult?] :
  /// index 0 = lundi-midi, 1 = lundi-soir, ..., 12 = dimanche-midi, 13 = dimanche-soir.
  /// Un élément null signifie qu'aucune recette compatible n'a pu être trouvée.
  List<MealSlotResult?> generateMenu(
    GenerationInput input, {
    Set<int>? lockedSlotIndices,
    Set<String>? lockedRecipeIds,
  }) {
    // Précalcul : map recipeId → set de memberIds qui la détestent
    final dislikedByMember = _buildDislikedMap(input.ratings);
    // Précalcul : map recipeId → set de memberIds qui l'aiment
    final lovedByMember = _buildLovedMap(input.ratings);
    // Précalcul : set des recipeIds des menus précédents (anti-répétition)
    final previousRecipeIds = input.previousMenuSlots
        .map((s) => s.recipeId)
        .whereType<String>()
        .toSet();

    // Recettes déjà sélectionnées (inclut les verrouillées pour éviter les doublons)
    final usedRecipeIds = <String>{...?lockedRecipeIds};

    // Mélanger les recettes une fois pour diversifier le résultat
    final shuffledRecipes = List<Recipe>.from(input.recipes)..shuffle(_random);

    // Résultat : 14 créneaux (null = non rempli)
    final results = List<MealSlotResult?>.filled(14, null);

    for (var slotIndex = 0; slotIndex < 14; slotIndex++) {
      // Ignorer les créneaux verrouillés (regénération partielle)
      if (lockedSlotIndices != null && lockedSlotIndices.contains(slotIndex)) {
        continue;
      }

      final dayIndex = slotIndex ~/ 2; // 0=lundi, 6=dimanche
      final dayOfWeek = dayIndex + 1; // 1=lundi, 7=dimanche (convention DB)
      final mealType = slotIndex.isEven ? 'lunch' : 'dinner';

      // Membres présents à ce créneau
      final presentMemberIds = _getPresentMemberIds(
        input.presences,
        dayOfWeek,
        mealType,
      );

      // Pas de membres présents → créneau vide
      if (presentMemberIds.isEmpty) {
        results[slotIndex] = null;
        continue;
      }

      // ── Couche 1 : filtrage par type de repas ──
      var pool = _filterByMealType(shuffledRecipes, mealType);

      // ── Couche 1bis : filtres utilisateur ──
      if (input.filters != null) {
        pool = _applyUserFilters(pool, input.filters!);
      }

      // ── Couche 2 : exclusion "pas aimé" ──
      pool = _excludeDisliked(pool, presentMemberIds, dislikedByMember);

      // ── Couche 5 : anti-répétition ──
      // On tente d'abord sans les recettes des menus précédents
      final poolAfterAntiRepeat = _excludePreviousMenus(pool, previousRecipeIds);
      // Fallback sur pool complet si anti-répétition vide tout
      final effectivePool =
          poolAfterAntiRepeat.isNotEmpty ? poolAfterAntiRepeat : pool;

      // ── Couche 3+4 : tri par priorité (favoris > aimés > neutres) ──
      final sortedPool = _sortByPriority(
        effectivePool,
        presentMemberIds,
        lovedByMember,
      );

      // Déduplication : exclure les recettes déjà utilisées cette génération
      final deduplicatedPool =
          sortedPool.where((r) => !usedRecipeIds.contains(r.id)).toList();

      if (deduplicatedPool.isEmpty) {
        results[slotIndex] = null;
        continue;
      }

      // ── Couche 6 : sélection de la meilleure recette ──
      final selectedRecipe = deduplicatedPool.first;
      usedRecipeIds.add(selectedRecipe.id);
      results[slotIndex] = MealSlotResult(
        recipeId: selectedRecipe.id,
        dayIndex: dayIndex,
        mealType: mealType,
      );
    }

    return results;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Couche 1 : filtrage par type de repas
  // ─────────────────────────────────────────────────────────────────────────

  List<Recipe> _filterByMealType(List<Recipe> recipes, String mealType) =>
      recipes
          .where((r) => r.mealType == mealType || r.mealType == 'both')
          .toList();

  // ─────────────────────────────────────────────────────────────────────────
  // Couche 1bis : filtres utilisateur
  // ─────────────────────────────────────────────────────────────────────────

  List<Recipe> _applyUserFilters(
    List<Recipe> pool,
    GenerationFilters filters,
  ) {
    var result = pool;

    if (filters.maxPrepTimeMinutes != null) {
      result = result
          .where((r) => r.prepTimeMinutes <= filters.maxPrepTimeMinutes!)
          .toList();
    }

    if (filters.vegetarianOnly) {
      result = result.where((r) => r.isVegetarian).toList();
    }

    if (filters.season != null && filters.season != Season.allSeasons) {
      result = result
          .where(
            (r) =>
                r.season == filters.season!.dbValue || r.season == 'all',
          )
          .toList();
    }

    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Couche 2 : exclusion "pas aimé"
  // ─────────────────────────────────────────────────────────────────────────

  /// Exclut les recettes notées "disliked" par AU MOINS UN membre présent.
  List<Recipe> _excludeDisliked(
    List<Recipe> pool,
    Set<String> presentMemberIds,
    Map<String, Set<String>> dislikedByMember,
  ) =>
      pool.where((recipe) {
        final dislikers = dislikedByMember[recipe.id] ?? {};
        return dislikers.intersection(presentMemberIds).isEmpty;
      }).toList();

  // ─────────────────────────────────────────────────────────────────────────
  // Couche 3+4 : tri par priorité
  // ─────────────────────────────────────────────────────────────────────────

  List<Recipe> _sortByPriority(
    List<Recipe> pool,
    Set<String> presentMemberIds,
    Map<String, Set<String>> lovedByMember,
  ) {
    final copy = List<Recipe>.from(pool);
    copy.sort((a, b) {
      final scoreA = _priorityScore(a, presentMemberIds, lovedByMember);
      final scoreB = _priorityScore(b, presentMemberIds, lovedByMember);
      return scoreB.compareTo(scoreA); // décroissant
    });
    return copy;
  }

  int _priorityScore(
    Recipe recipe,
    Set<String> presentMemberIds,
    Map<String, Set<String>> lovedByMember,
  ) {
    var score = 0;
    if (recipe.isFavorite) score += 10; // Couche 3 : favori
    final lovers = lovedByMember[recipe.id] ?? {};
    if (lovers.intersection(presentMemberIds).isNotEmpty) score += 5; // Couche 4 : aimé
    return score;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Couche 5 : anti-répétition
  // ─────────────────────────────────────────────────────────────────────────

  List<Recipe> _excludePreviousMenus(
    List<Recipe> pool,
    Set<String> previousRecipeIds,
  ) =>
      pool.where((r) => !previousRecipeIds.contains(r.id)).toList();

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  Set<String> _getPresentMemberIds(
    List<PresenceSchedule> presences,
    int dayOfWeek,
    String mealSlot,
  ) =>
      presences
          .where(
            (p) =>
                p.dayOfWeek == dayOfWeek &&
                p.mealSlot == mealSlot &&
                p.isPresent,
          )
          .map((p) => p.memberId)
          .toSet();

  Map<String, Set<String>> _buildDislikedMap(List<MealRating> ratings) {
    final map = <String, Set<String>>{};
    for (final r in ratings) {
      if (r.rating == 'disliked') {
        map.putIfAbsent(r.recipeId, () => {}).add(r.memberId);
      }
    }
    return map;
  }

  Map<String, Set<String>> _buildLovedMap(List<MealRating> ratings) {
    final map = <String, Set<String>>{};
    for (final r in ratings) {
      if (r.rating == 'liked') {
        map.putIfAbsent(r.recipeId, () => {}).add(r.memberId);
      }
    }
    return map;
  }
}
