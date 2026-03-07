import 'package:appli_recette/core/database/database_connection.dart';
import 'package:appli_recette/core/database/tables/ingredients_table.dart';
import 'package:appli_recette/core/database/tables/meal_ratings_table.dart';
import 'package:appli_recette/core/database/tables/members_table.dart';
import 'package:appli_recette/core/database/tables/menu_slots_table.dart';
import 'package:appli_recette/core/database/tables/presence_schedules_table.dart';
import 'package:appli_recette/core/database/tables/recipe_steps_table.dart';
import 'package:appli_recette/core/database/tables/recipes_table.dart';
import 'package:appli_recette/core/database/tables/sync_queue_table.dart';
import 'package:appli_recette/core/database/tables/weekly_menus_table.dart';
import 'package:drift/drift.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Recipes,
    Ingredients,
    RecipeSteps,
    Members,
    MealRatings,
    PresenceSchedules,
    WeeklyMenus,
    MenuSlots,
    SyncQueue,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.createTable(recipeSteps);
        }
        if (from < 3) {
          // Story 8.4 : ajouter householdId aux tables sans cette colonne
          await m.addColumn(ingredients, ingredients.householdId);
          await m.addColumn(mealRatings, mealRatings.householdId);
          await m.addColumn(presenceSchedules, presenceSchedules.householdId);
          await m.addColumn(menuSlots, menuSlots.householdId);
        }
      },
      beforeOpen: (details) async {
        // Active les foreign keys pour que les CASCADE deletes fonctionnent
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}
