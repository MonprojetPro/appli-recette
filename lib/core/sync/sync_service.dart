import 'dart:async';
import 'dart:developer';

import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/sync/connectivity_monitor.dart';
import 'package:appli_recette/core/sync/initial_sync_service.dart';
import 'package:appli_recette/core/sync/sync_queue_processor.dart';
import 'package:appli_recette/core/sync/sync_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Orchestre [ConnectivityMonitor] et [SyncQueueProcessor].
/// Pull immédiat au démarrage + refresh périodique toutes les 30 secondes.
class SyncService {
  SyncService(this._monitor, this._processor, this._db);

  final ConnectivityMonitor _monitor;
  final SyncQueueProcessor _processor;
  final AppDatabase _db;

  final _statusController = StreamController<SyncStatus>.broadcast();
  StreamSubscription<bool>? _connectivitySub;
  Timer? _pullTimer;
  bool _isPulling = false;

  /// Refresh périodique (30 secondes).
  static const _pullInterval = Duration(seconds: 30);

  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Démarre la sync : pull immédiat + timer périodique.
  void start() {
    _connectivitySub?.cancel();
    _connectivitySub = _monitor.isOnline.listen(
      _onConnectivityChanged,
      onError: (Object e) => log('SyncService connectivity error: $e'),
    );
    // Au démarrage : push la queue locale PUIS pull les données du foyer
    _monitor.checkCurrentStatus().then(
      (isOnline) {
        if (isOnline) {
          _processQueue().then((_) => _pullFromCloud());
        }
      },
      onError: (Object e) => log('SyncService checkCurrentStatus error: $e'),
    );
    // Refresh périodique
    _pullTimer?.cancel();
    _pullTimer = Timer.periodic(_pullInterval, (_) => _pullFromCloud());
  }

  /// Déclenche immédiatement un pull depuis Supabase.
  Future<void> pullNow() => _pullFromCloud();

  Future<void> _onConnectivityChanged(bool isOnline) async {
    if (isOnline) {
      await _processQueue();
      await _pullFromCloud();
    } else {
      _statusController.add(SyncStatus.offline);
    }
  }

  Future<void> _processQueue() async {
    _statusController.add(SyncStatus.syncing);
    try {
      await _processor.processQueue();
      _statusController.add(SyncStatus.synced);
    } catch (e) {
      log('SyncService processQueue error: $e');
      _statusController.add(SyncStatus.error);
    }
  }

  /// Télécharge les données du foyer depuis Supabase.
  /// Protégé contre les appels simultanés.
  Future<void> _pullFromCloud() async {
    if (_isPulling) return;
    _isPulling = true;
    try {
      final isOnline = await _monitor.checkCurrentStatus();
      if (!isOnline) return;

      final prefs = await SharedPreferences.getInstance();
      final householdId = prefs.getString('household_id');
      if (householdId == null) return;

      await InitialSyncService(_db).syncFromSupabase(householdId);
    } catch (e) {
      log('SyncService pullFromCloud error: $e');
    } finally {
      _isPulling = false;
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    _pullTimer?.cancel();
    _statusController.close();
  }
}
