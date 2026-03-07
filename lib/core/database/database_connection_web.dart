import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Opens a WasmDatabase (IndexedDB/OPFS) for web platforms.
///
/// Requires sqlite3.wasm and drift_worker.js in the web/ folder.
/// See: https://drift.simonbinder.eu/web/#prerequisites
QueryExecutor openDatabaseConnection() {
  return driftDatabase(
    name: 'appli_recette',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
