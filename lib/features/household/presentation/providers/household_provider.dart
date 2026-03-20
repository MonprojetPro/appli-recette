import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/database/database_provider.dart';
import 'package:appli_recette/core/household/household_providers.dart';
import 'package:appli_recette/core/sync/sync_provider.dart';
import 'package:appli_recette/features/household/data/datasources/meal_rating_datasource.dart';
import 'package:appli_recette/features/household/data/datasources/member_local_datasource.dart';
import 'package:appli_recette/features/household/data/models/rating_value.dart';
import 'package:appli_recette/features/household/data/repositories/household_repository_impl.dart';
import 'package:appli_recette/features/household/domain/repositories/household_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Infrastructure providers
// ---------------------------------------------------------------------------

final memberLocalDatasourceProvider = Provider<MemberLocalDatasource>((ref) {
  final db = ref.watch(databaseProvider);
  return MemberLocalDatasource(db);
});

final mealRatingDatasourceProvider = Provider<MealRatingDatasource>((ref) {
  final db = ref.watch(databaseProvider);
  return MealRatingDatasource(db);
});

// ---------------------------------------------------------------------------
// Repository provider
// ---------------------------------------------------------------------------

final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  final memberDs = ref.watch(memberLocalDatasourceProvider);
  final ratingDs = ref.watch(mealRatingDatasourceProvider);
  final syncQueue = ref.watch(syncQueueDatasourceProvider);
  return HouseholdRepositoryImpl(memberDs, ratingDs, syncQueue);
});

// ---------------------------------------------------------------------------
// Stream providers (lecture)
// ---------------------------------------------------------------------------

/// Stream de tous les membres du foyer courant.
final membersStreamProvider = StreamProvider<List<Member>>((ref) {
  final householdId = ref.watch(currentHouseholdIdProvider).value;
  if (householdId == null) return const Stream.empty();
  return ref.watch(householdRepositoryProvider).watchAll(householdId);
});

/// Stream des notations pour une recette donnée.
final recipeRatingsProvider =
    StreamProvider.family<List<MealRating>, String>((ref, recipeId) {
  return ref.watch(householdRepositoryProvider).watchRatingsForRecipe(recipeId);
});

// ---------------------------------------------------------------------------
// Notifier (actions)
// ---------------------------------------------------------------------------

/// Notifier pour les actions sur les membres et leurs notations.
class HouseholdNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Ajoute un nouveau membre au foyer. Retourne l'ID UUID v4 créé.
  Future<String> addMember({required String name, int? age}) async {
    return ref
        .read(householdRepositoryProvider)
        .addMember(name: name, age: age);
  }

  /// Met à jour un membre existant.
  Future<void> updateMember({
    required String id,
    required String name,
    int? age,
  }) async {
    await ref.read(householdRepositoryProvider).updateMember(
          id: id,
          name: name,
          age: age,
        );
  }

  /// Supprime un membre et ses données liées (cascade via FK drift).
  Future<void> deleteMember(String id) async {
    await ref.read(householdRepositoryProvider).deleteMember(id);
  }

  /// Crée ou met à jour la notation d'un membre pour une recette.
  Future<void> upsertRating({
    required String memberId,
    required String recipeId,
    required RatingValue rating,
  }) async {
    await ref.read(householdRepositoryProvider).upsertRating(
          memberId: memberId,
          recipeId: recipeId,
          rating: rating,
        );
  }

  /// Supprime la notation d'un membre pour une recette (désélection).
  Future<void> deleteRating({
    required String memberId,
    required String recipeId,
  }) async {
    await ref.read(householdRepositoryProvider).deleteRating(
          memberId: memberId,
          recipeId: recipeId,
        );
  }
}

final householdNotifierProvider =
    AsyncNotifierProvider<HouseholdNotifier, void>(HouseholdNotifier.new);
