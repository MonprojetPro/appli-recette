import 'package:drift/drift.dart';

import 'recipes_table.dart';

/// Table des étapes de préparation d'une recette.
///
/// Chaque étape a un numéro d'ordre, un texte optionnel et
/// zéro ou plusieurs photos (stockées en JSON : `["path1","path2"]`).
class RecipeSteps extends Table {
  TextColumn get id => text()();
  TextColumn get recipeId =>
      text().references(Recipes, #id, onDelete: KeyAction.cascade)();
  IntColumn get stepNumber => integer()();
  TextColumn get instruction => text().nullable()();

  /// Chemins des photos locales, encodés en JSON array.
  /// Ex : '["/.../img1.jpg","/.../img2.jpg"]'
  TextColumn get photoPathsJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
