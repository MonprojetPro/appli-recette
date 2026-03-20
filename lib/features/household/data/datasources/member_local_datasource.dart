import 'package:appli_recette/core/database/app_database.dart';
import 'package:drift/drift.dart';

/// Source de données locale pour les membres du foyer (drift / SQLite).
class MemberLocalDatasource {
  MemberLocalDatasource(this._db);

  final AppDatabase _db;

  /// Stream de tous les membres du foyer triés par date de création ASC.
  Stream<List<Member>> watchAll(String householdId) {
    return (_db.select(_db.members)
          ..where((t) => t.householdId.equals(householdId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Insère un nouveau membre et retourne son ID.
  Future<String> insert(MembersCompanion companion) async {
    await _db.into(_db.members).insert(companion);
    return companion.id.value;
  }

  /// Met à jour un membre existant.
  Future<void> update(MembersCompanion companion) async {
    await (_db.update(_db.members)
          ..where((t) => t.id.equals(companion.id.value)))
        .write(companion);
  }

  /// Supprime un membre par son ID.
  /// Les meal_ratings et presence_schedules sont supprimés en cascade
  /// via les FK définies dans les tables concernées (onDelete: KeyAction.cascade).
  Future<void> delete(String id) async {
    await (_db.delete(_db.members)..where((t) => t.id.equals(id))).go();
  }
}
