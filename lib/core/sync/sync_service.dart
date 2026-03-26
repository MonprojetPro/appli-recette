import 'dart:async';
import 'dart:developer';

import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/sync/connectivity_monitor.dart';
import 'package:appli_recette/core/sync/initial_sync_service.dart';
import 'package:appli_recette/core/sync/sync_queue_processor.dart';
import 'package:appli_recette/core/sync/sync_status.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Orchestre [ConnectivityMonitor] et [SyncQueueProcessor].
/// Déclenche la synchronisation automatiquement quand le réseau revient.
/// Utilise Supabase Realtime pour sync instantanée entre membres du foyer.
/// Timer de fallback toutes les 5 minutes au cas où le Realtime décroche.
class SyncService {
  SyncService(this._monitor, this._processor, this._db);

  final ConnectivityMonitor _monitor;
  final SyncQueueProcessor _processor;
  final AppDatabase _db;

  final _statusController = StreamController<SyncStatus>.broadcast();
  StreamSubscription<bool>? _connectivitySub;
  Timer? _pullTimer;
  RealtimeChannel? _realtimeChannel;
  bool _isPulling = false;

  /// Fallback : pull périodique si le Realtime décroche (5 min).
  static const _fallbackInterval = Duration(minutes: 5);

  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Démarre la surveillance de connectivité, le Realtime et le pull de fallback.
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
    // Realtime : sync instantanée entre membres du foyer
    _subscribeRealtime();
    // Timer de fallback (au cas où le Realtime décroche)
    _pullTimer?.cancel();
    _pullTimer = Timer.periodic(_fallbackInterval, (_) => _pullFromCloud());
  }

  /// Déclenche immédiatement un pull depuis Supabase.
  Future<void> pullNow() => _pullFromCloud();

  // ── Supabase Realtime ──────────────────────────────────────────────────

  /// S'abonne aux changements en temps réel sur les tables du foyer.
  /// Quand un autre membre modifie une recette, un membre, un ingrédient
  /// → on reçoit l'événement et on tire les données immédiatement.
  Future<void> _subscribeRealtime() async {
    final prefs = await SharedPreferences.getInstance();
    final householdId = prefs.getString('household_id');
    if (householdId == null) return;

    // Fermer l'ancien channel si on se réabonne
    _realtimeChannel?.unsubscribe();

    final client = Supabase.instance.client;

    _realtimeChannel = client.channel('household_sync_$householdId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'recipes',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'household_id',
          value: householdId,
        ),
        callback: (_) => _onRealtimeChange('recipes'),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'members',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'household_id',
          value: householdId,
        ),
        callback: (_) => _onRealtimeChange('members'),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'ingredients',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'household_id',
          value: householdId,
        ),
        callback: (_) => _onRealtimeChange('ingredients'),
      )
      ..subscribe();
  }

  /// Appelé quand Supabase Realtime notifie un changement.
  void _onRealtimeChange(String table) {
    log('SyncService: Realtime change on $table — pulling now');
    _pullFromCloud();
  }

  // ── Connectivité ────────────────────────────────────────────────────────

  Future<void> _onConnectivityChanged(bool isOnline) async {
    if (isOnline) {
      await _processQueue();
      await _pullFromCloud();
      // Re-souscrire au Realtime au retour de connectivité
      _subscribeRealtime();
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
  /// Protégé contre les appels multiples simultanés (debounce naturel).
  Future<void> _pullFromCloud() async {
    if (_isPulling) return; // éviter les pulls simultanés
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
    _realtimeChannel?.unsubscribe();
    _statusController.close();
  }
}
