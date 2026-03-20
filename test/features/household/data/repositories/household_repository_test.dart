import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/sync/sync_queue_datasource.dart';
import 'package:appli_recette/features/household/data/datasources/meal_rating_datasource.dart';
import 'package:appli_recette/features/household/data/datasources/member_local_datasource.dart';
import 'package:appli_recette/features/household/data/models/rating_value.dart';
import 'package:appli_recette/features/household/data/repositories/household_repository_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Crée une base de données drift en mémoire pour les tests.
AppDatabase _createTestDatabase() => AppDatabase.forTesting(
      NativeDatabase.memory(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late HouseholdRepositoryImpl repo;

  const testHouseholdId = 'test-household-uuid';

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'household_id': testHouseholdId,
    });
    db = _createTestDatabase();
    final memberDs = MemberLocalDatasource(db);
    final ratingDs = MealRatingDatasource(db);
    final syncQueue = SyncQueueDatasource(db);
    repo = HouseholdRepositoryImpl(memberDs, ratingDs, syncQueue);
  });

  tearDown(() async {
    await db.close();
  });

  // ── Tests membres ─────────────────────────────────────────────────────────

  group('HouseholdRepositoryImpl', () {
    test('addMember() retourne un ID UUID v4 non-vide', () async {
      final id = await repo.addMember(name: 'Léonard', age: 11);
      expect(id, isNotEmpty);
      expect(id.length, 36);
      expect(id.split('-').length, 5);
      expect(id[14], '4'); // version 4
    });

    test('addMember() persiste le membre dans drift', () async {
      await repo.addMember(name: 'Alizée', age: 9);

      final members = await repo.watchAll(testHouseholdId).first;
      expect(members.length, 1);
      expect(members.first.name, 'Alizée');
      expect(members.first.age, 9);
    });

    test('addMember() sans âge persiste avec age null', () async {
      await repo.addMember(name: 'Membre sans âge');

      final members = await repo.watchAll(testHouseholdId).first;
      expect(members.first.name, 'Membre sans âge');
      expect(members.first.age, isNull);
    });

    test('watchAll() retourne liste vide quand aucun membre', () async {
      final members = await repo.watchAll(testHouseholdId).first;
      expect(members, isEmpty);
    });

    test('watchAll() retourne tous les membres créés', () async {
      await repo.addMember(name: 'MiKL');
      await repo.addMember(name: 'Partenaire');
      await repo.addMember(name: 'Léonard', age: 11);

      final members = await repo.watchAll(testHouseholdId).first;
      expect(members.length, 3);
      final names = members.map((m) => m.name).toList();
      expect(names, containsAll(['MiKL', 'Partenaire', 'Léonard']));
    });

    test('updateMember() met à jour nom et âge', () async {
      final id = await repo.addMember(name: 'Leon', age: 10);

      await repo.updateMember(id: id, name: 'Léonard', age: 11);

      final members = await repo.watchAll(testHouseholdId).first;
      expect(members.first.name, 'Léonard');
      expect(members.first.age, 11);
    });

    test('updateMember() peut passer age à null', () async {
      final id = await repo.addMember(name: 'Test', age: 25);

      await repo.updateMember(id: id, name: 'Test');

      final members = await repo.watchAll(testHouseholdId).first;
      expect(members.first.age, isNull);
    });

    test('deleteMember() supprime le membre', () async {
      final id = await repo.addMember(name: 'À supprimer');

      await repo.deleteMember(id);

      final members = await repo.watchAll(testHouseholdId).first;
      expect(members, isEmpty);
    });

    test('deleteMember() supprime en cascade les presence_schedules', () async {
      // Activer les FK (nécessaire pour les tests in-memory)
      await db.customStatement('PRAGMA foreign_keys = ON');

      final memberId = await repo.addMember(name: 'Test cascade');

      // Insérer une presence_schedule liée au membre
      await db.into(db.presenceSchedules).insert(
            PresenceSchedulesCompanion.insert(
              id: 'ps-001',
              memberId: memberId,
              dayOfWeek: 1,
              mealSlot: 'lunch',
            ),
          );

      // Vérifier que la presence_schedule existe
      final schedulesBefore =
          await db.select(db.presenceSchedules).get();
      expect(schedulesBefore.length, 1);

      // Supprimer le membre
      await repo.deleteMember(memberId);

      // Vérifier la cascade
      final schedulesAfter = await db.select(db.presenceSchedules).get();
      expect(schedulesAfter, isEmpty);
    });

    test('addMember() multiple — tous les IDs sont distincts', () async {
      final id1 = await repo.addMember(name: 'Membre 1');
      final id2 = await repo.addMember(name: 'Membre 2');
      final id3 = await repo.addMember(name: 'Membre 3');

      expect({id1, id2, id3}.length, 3);
    });
  });

  // ── Tests notations ───────────────────────────────────────────────────────

  group('HouseholdRepositoryImpl — notations', () {
    /// Insère un membre et une recette de test, retourne (memberId, recipeId).
    Future<(String memberId, String recipeId)> insertMemberAndRecipe() async {
      final memberId = await repo.addMember(name: 'Testeur');
      const recipeId = 'recipe-test-001';
      final now = DateTime.now();
      await db.into(db.recipes).insert(
            RecipesCompanion.insert(
              id: recipeId,
              name: 'Recette Test',
              mealType: 'dinner',
              createdAt: now,
              updatedAt: now,
            ),
          );
      return (memberId, recipeId);
    }

    test('watchRatingsForRecipe() retourne liste vide sans notation', () async {
      final (_, recipeId) = await insertMemberAndRecipe();

      final ratings = await repo.watchRatingsForRecipe(recipeId).first;
      expect(ratings, isEmpty);
    });

    test('upsertRating() crée une nouvelle notation', () async {
      final (memberId, recipeId) = await insertMemberAndRecipe();

      await repo.upsertRating(
        memberId: memberId,
        recipeId: recipeId,
        rating: RatingValue.liked,
      );

      final ratings = await repo.watchRatingsForRecipe(recipeId).first;
      expect(ratings.length, 1);
      expect(ratings.first.memberId, memberId);
      expect(ratings.first.recipeId, recipeId);
      expect(ratings.first.rating, 'liked');
    });

    test('upsertRating() met à jour une notation existante', () async {
      final (memberId, recipeId) = await insertMemberAndRecipe();

      // Première notation
      await repo.upsertRating(
        memberId: memberId,
        recipeId: recipeId,
        rating: RatingValue.liked,
      );

      // Mise à jour vers disliked
      await repo.upsertRating(
        memberId: memberId,
        recipeId: recipeId,
        rating: RatingValue.disliked,
      );

      final ratings = await repo.watchRatingsForRecipe(recipeId).first;
      expect(ratings.length, 1, reason: 'Pas de doublon — upsert');
      expect(ratings.first.rating, 'disliked');
    });

    test('upsertRating() gère plusieurs membres sur la même recette', () async {
      final memberId1 = await repo.addMember(name: 'Membre A');
      final memberId2 = await repo.addMember(name: 'Membre B');
      const recipeId = 'recipe-multi-001';
      final now2 = DateTime.now();
      await db.into(db.recipes).insert(
            RecipesCompanion.insert(
              id: recipeId,
              name: 'Recette Multi',
              mealType: 'lunch',
              createdAt: now2,
              updatedAt: now2,
            ),
          );

      await repo.upsertRating(
        memberId: memberId1,
        recipeId: recipeId,
        rating: RatingValue.liked,
      );
      await repo.upsertRating(
        memberId: memberId2,
        recipeId: recipeId,
        rating: RatingValue.neutral,
      );

      final ratings = await repo.watchRatingsForRecipe(recipeId).first;
      expect(ratings.length, 2);
      final ratingMap = {for (final r in ratings) r.memberId: r.rating};
      expect(ratingMap[memberId1], 'liked');
      expect(ratingMap[memberId2], 'neutral');
    });

    test('RatingValue — fromDb round-trip', () {
      for (final value in RatingValue.values) {
        expect(RatingValue.fromDb(value.dbValue), value);
      }
    });

    test('RatingValue.fromDb() retourne neutral pour une valeur inconnue', () {
      expect(RatingValue.fromDb('corrupted'), RatingValue.neutral);
    });

    test('deleteRating() supprime une notation spécifique', () async {
      final (memberId, recipeId) = await insertMemberAndRecipe();

      await repo.upsertRating(
        memberId: memberId,
        recipeId: recipeId,
        rating: RatingValue.liked,
      );

      // Vérifier que la notation existe
      final ratingsBefore = await repo.watchRatingsForRecipe(recipeId).first;
      expect(ratingsBefore.length, 1);

      // Supprimer la notation
      await repo.deleteRating(memberId: memberId, recipeId: recipeId);

      // Vérifier la suppression
      final ratingsAfter = await repo.watchRatingsForRecipe(recipeId).first;
      expect(ratingsAfter, isEmpty);
    });

    test('deleteRatingsForRecipe() supprime toutes les notations', () async {
      final memberId1 = await repo.addMember(name: 'Membre X');
      final memberId2 = await repo.addMember(name: 'Membre Y');
      const recipeId = 'recipe-del-001';
      final now = DateTime.now();
      await db.into(db.recipes).insert(
            RecipesCompanion.insert(
              id: recipeId,
              name: 'Recette Delete',
              mealType: 'lunch',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await repo.upsertRating(
        memberId: memberId1,
        recipeId: recipeId,
        rating: RatingValue.liked,
      );
      await repo.upsertRating(
        memberId: memberId2,
        recipeId: recipeId,
        rating: RatingValue.disliked,
      );

      // Vérifier qu'on a 2 notations
      final ratingsBefore = await repo.watchRatingsForRecipe(recipeId).first;
      expect(ratingsBefore.length, 2);

      // Supprimer toutes les notations de la recette
      await repo.deleteRatingsForRecipe(recipeId);

      // Vérifier la suppression
      final ratingsAfter = await repo.watchRatingsForRecipe(recipeId).first;
      expect(ratingsAfter, isEmpty);
    });
  });
}
