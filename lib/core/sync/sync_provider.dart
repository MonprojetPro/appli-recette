import 'package:appli_recette/core/database/database_provider.dart';
import 'package:appli_recette/core/sync/connectivity_monitor.dart';
import 'package:appli_recette/core/sync/sync_queue_datasource.dart';
import 'package:appli_recette/core/sync/sync_queue_processor.dart';
import 'package:appli_recette/core/sync/sync_service.dart';
import 'package:appli_recette/core/sync/sync_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final syncQueueDatasourceProvider = Provider<SyncQueueDatasource>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncQueueDatasource(db);
});

final connectivityMonitorProvider = Provider<ConnectivityMonitor>((ref) {
  return ConnectivityMonitor();
});

final syncQueueProcessorProvider = Provider<SyncQueueProcessor>((ref) {
  final datasource = ref.watch(syncQueueDatasourceProvider);
  final client = Supabase.instance.client;
  return SyncQueueProcessor(datasource, client);
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final monitor = ref.watch(connectivityMonitorProvider);
  final processor = ref.watch(syncQueueProcessorProvider);
  final db = ref.watch(databaseProvider);
  final service = SyncService(monitor, processor, db);
  ref.onDispose(service.dispose);
  service.start();
  return service;
});

/// Stream de l'état de synchronisation courant.
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final service = ref.watch(syncServiceProvider);
  return service.statusStream;
});
