import 'dart:async';
import 'dart:developer';

import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/sync/connectivity_monitor.dart';
import 'package:appli_recette/core/sync/initial_sync_service.dart';
import 'package:appli_recette/core/sync/sync_queue_processor.dart';
import 'package:appli_recette/core/sync/sync_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Orchestre [ConnectivityMonitor] et [SyncQueueProcessor].
/// Déclenche la synchronisation automatiquement quand le réseau revient.
/// Effectue aussi un pull périodique depuis Supabase pour récupérer les
/// changements faits par d'autres membres du même foyer.
class SyncService {
  SyncService(this._monitor, this._processor, this._db);

  final ConnectivityMonitor _monitor;
  final SyncQueueProcessor _processor;
  final AppDatabase _db;

  final _statusController = StreamController<SyncStatus>.broadcast();
  StreamSubscription<bool>? _connectivitySub;
  Timer? _pullTimer;

  /// Intervalle du pull périodique depuis le cloud (2 minutes).
  static const _pullInterval = Duration(minutes: 2);

  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Démarre la surveillance de connectivité et le pull périodique.
  void start() {
    _connectivitySub?.cancel();
    _connectivitySub = _monitor.isOnline.listen(
      _onConnectivityChanged,
      onError: (Object e) => log('SyncService connectivity error: $e'),
    );
    // Vérification immédiate au démarrage
    _monitor.checkCurrentStatus().then(
      (isOnline) {
        if (isOnline) _processQueue();
      },
      onError: (Object e) => log('SyncService checkCurrentStatus error: $e'),
    );
    // Pull périodique pour récupérer les changements des autres membres
    _pullTimer?.cancel();
    _pullTimer = Timer.periodic(_pullInterval, (_) => _pullFromCloud());
  }

  /// Déclenche immédiatement un pull depuis Supabase.
  /// Utile quand l'app revient au premier plan.
  Future<void> pullNow() => _pullFromCloud();

  Future<void> _onConnectivityChanged(bool isOnline) async {
    if (isOnline) {
      await _processQueue();
      // Aussi pull au retour de connectivité pour récupérer les changements manqués
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

  /// Télécharge les dernières données du foyer depuis Supabase.
  /// Ne fait rien si pas de foyer configuré ou pas de connexion.
  Future<void> _pullFromCloud() async {
    try {
      final isOnline = await _monitor.checkCurrentStatus();
      if (!isOnline) return;

      final prefs = await SharedPreferences.getInstance();
      final householdId = prefs.getString('household_id');
      if (householdId == null) return;

      await InitialSyncService(_db).syncFromSupabase(householdId);
    } catch (e) {
      log('SyncService pullFromCloud error: $e');
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    _pullTimer?.cancel();
    _statusController.close();
  }
}
