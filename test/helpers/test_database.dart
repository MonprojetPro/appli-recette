import 'package:appli_recette/core/database/app_database.dart';
import 'package:drift/native.dart';

/// Creates an in-memory [AppDatabase] for unit tests.
///
/// Uses [NativeDatabase.memory] so tests run on native without needing
/// SQLite file I/O, and without requiring WasmDatabase (web-only).
AppDatabase createTestDatabase() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}
