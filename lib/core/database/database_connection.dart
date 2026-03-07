import 'package:appli_recette/core/database/database_connection_native.dart'
    if (dart.library.js_interop) 'package:appli_recette/core/database/database_connection_web.dart';
import 'package:drift/drift.dart';

/// Returns the appropriate [QueryExecutor] for the current platform.
///
/// Native (Android/iOS/Desktop): NativeDatabase via LazyDatabase.
/// Web (Chrome/Safari): WasmDatabase via drift_flutter.
QueryExecutor openConnection() => openDatabaseConnection();
