import 'dart:math';

import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/sync/initial_sync_service.dart';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

// ── Exceptions ────────────────────────────────────────────────────────────────

/// Code foyer introuvable dans Supabase.
class HouseholdNotFoundException implements Exception {
  const HouseholdNotFoundException();
  @override
  String toString() => 'Code invalide. Vérifie le code partagé par ton foyer.';
}

/// Format de code invalide (doit être exactement 6 chiffres).
class InvalidCodeFormatException implements Exception {
  const InvalidCodeFormatException();
  @override
  String toString() => 'Le code doit contenir exactement 6 chiffres.';
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Service responsable de la création et jointure d'un foyer.
///
/// Requiert un utilisateur authentifié via [AuthService] (email/password).
/// Le [household_id] est persisté localement dans [SharedPreferences].
class HouseholdService {
  HouseholdService(this._db, {SupabaseClient? client})
      : _clientOverride = client;

  final AppDatabase _db;
  final SupabaseClient? _clientOverride;

  /// Accès lazy au client Supabase (uniquement lors des appels réseau).
  SupabaseClient get _client =>
      _clientOverride ?? Supabase.instance.client;

  static const _keyHouseholdId = 'household_id';
  static const _keyAuthUserId = 'auth_user_id';
  static const _keyHouseholdCode = 'household_code';

  /// Crée un nouveau foyer pour l'utilisateur courant.
  ///
  /// 1. Vérifie que l'utilisateur est authentifié.
  /// 2. Génère un code unique à 6 chiffres.
  /// 3. Insère dans `households` + `household_members`.
  /// 4. Stocke le [household_id] dans [SharedPreferences].
  /// 5. Lie les données locales existantes au nouveau foyer.
  ///
  /// Retourne le code à 6 chiffres à afficher à l'utilisateur.
  ///
  /// Lève une [Exception] si l'utilisateur n'est pas authentifié.
  Future<String> createHousehold({String name = 'Mon Foyer'}) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception(
        'Utilisateur non authentifié. Connectez-vous avant de créer un foyer.',
      );
    }

    final code = await _generateUniqueCode();
    final householdId = const Uuid().v4();

    await _client.from('households').insert({
      'id': householdId,
      'name': name,
      'code': code,
      'created_by': user.id,
    });

    await _client.from('household_members').insert({
      'household_id': householdId,
      'user_id': user.id,
      'role': 'owner',
    });

    // Enregistrer le device pour la RLS (get_my_household_id)
    await _client.from('household_auth_devices').insert({
      'household_id': householdId,
      'auth_user_id': user.id,
      'joined_at': DateTime.now().toUtc().toIso8601String(),
    });

    await _persistHouseholdId(householdId);
    await linkLocalDataToHousehold(householdId);

    // Stocker le code localement pour éviter un appel Supabase à chaque démarrage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHouseholdCode, code);

    // Nouveau foyer créé → déclencher l'onboarding pour ce foyer
    await prefs.setBool('onboarding_in_progress', true);

    return code;
  }

  /// Rejoint un foyer existant via son code à 6 chiffres.
  ///
  /// Lève [InvalidCodeFormatException] si le format est incorrect.
  /// Lève [HouseholdNotFoundException] si le code est inconnu de Supabase.
  Future<void> joinHousehold(String code) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const InvalidCodeFormatException();
    }

    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception(
        'Utilisateur non authentifié. Connectez-vous avant de rejoindre un foyer.',
      );
    }

    final result = await _client
        .from('households')
        .select('id')
        .eq('code', code)
        .maybeSingle();

    if (result == null) throw const HouseholdNotFoundException();

    final householdId = result['id'] as String;

    // Insert membre — ignore si déjà membre (contrainte unique household_id+user_id)
    try {
      await _client.from('household_members').insert({
        'household_id': householdId,
        'user_id': user.id,
        'role': 'member',
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
      // Déjà membre de ce foyer — on continue
    }

    // Enregistrer le device pour la RLS (get_my_household_id)
    await _client.from('household_auth_devices').upsert(
      {
        'household_id': householdId,
        'auth_user_id': user.id,
        'joined_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'auth_user_id',
    );

    await _persistHouseholdId(householdId);

    // Stocker le code localement
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHouseholdCode, code);

    await InitialSyncService(_db).syncFromSupabase(householdId);
  }

  /// Retourne le [household_id] stocké localement.
  ///
  /// Vérifie que les données locales appartiennent à l'utilisateur courant.
  /// Si un autre utilisateur s'est connecté, les données stale sont purgées
  /// et on repart d'une vérification Supabase propre.
  ///
  /// Si absent localement mais que l'utilisateur est déjà lié à un foyer
  /// dans Supabase (table household_auth_devices), récupère le household_id,
  /// le persiste localement, lance la sync initiale, et le retourne.
  /// Cela évite de redemander "Rejoindre un foyer" à chaque nouveau device/navigateur.
  Future<String?> getCurrentHouseholdId() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _client.auth.currentUser;
    final local = prefs.getString(_keyHouseholdId);

    if (local != null) {
      // Vérifier que le household stocké appartient à l'utilisateur courant.
      // Si un autre user AUTHENTIFIÉ s'est connecté (nouvelle session, même
      // navigateur), les données localStorage du compte précédent seraient
      // retournées à tort.
      // IMPORTANT : si user == null (session Supabase en cours de restauration),
      // on conserve les données locales — pas de purge sur une session indéfinie.
      final storedUserId = prefs.getString(_keyAuthUserId);
      if (user == null || storedUserId == null || storedUserId == user.id) {
        // Session en cours de chargement, ou même utilisateur → OK
        return local;
      }
      // Autre utilisateur authentifié → purger les données stale
      await prefs.remove(_keyHouseholdId);
      await prefs.remove(_keyAuthUserId);
      await prefs.remove('onboarding_complete');
    }

    // Pas de household_id local valide → vérifier dans Supabase
    if (user == null) return null;

    try {
      final row = await _client
          .from('household_auth_devices')
          .select('household_id')
          .eq('auth_user_id', user.id)
          .maybeSingle();

      if (row == null) return null;

      final householdId = row['household_id'] as String;
      await _persistHouseholdId(householdId);

      // Récupérer et mettre en cache le code du foyer
      try {
        final householdRow = await _client
            .from('households')
            .select('code')
            .eq('id', householdId)
            .maybeSingle();
        if (householdRow != null) {
          await prefs.setString(
              _keyHouseholdCode, householdRow['code'] as String);
        }
      } catch (_) {
        // Le code sera récupéré au prochain accès si nécessaire
      }

      // Compte connu sur un nouvel appareil → onboarding non requis (défaut)
      await InitialSyncService(_db).syncFromSupabase(householdId);
      return householdId;
    } catch (_) {
      return null;
    }
  }

  /// Met à jour tous les enregistrements locaux drift dont le [householdId]
  /// est null pour y affecter le foyer nouvellement créé.
  Future<void> linkLocalDataToHousehold(String householdId) async {
    await (_db.update(_db.recipes)
          ..where((r) => r.householdId.isNull()))
        .write(RecipesCompanion(householdId: Value(householdId)));

    await (_db.update(_db.members)
          ..where((m) => m.householdId.isNull()))
        .write(MembersCompanion(householdId: Value(householdId)));

    await (_db.update(_db.weeklyMenus)
          ..where((m) => m.householdId.isNull()))
        .write(WeeklyMenusCompanion(householdId: Value(householdId)));

    await (_db.update(_db.ingredients)
          ..where((i) => i.householdId.isNull()))
        .write(IngredientsCompanion(householdId: Value(householdId)));

    await (_db.update(_db.mealRatings)
          ..where((r) => r.householdId.isNull()))
        .write(MealRatingsCompanion(householdId: Value(householdId)));

    await (_db.update(_db.presenceSchedules)
          ..where((s) => s.householdId.isNull()))
        .write(PresenceSchedulesCompanion(householdId: Value(householdId)));

    await (_db.update(_db.menuSlots)
          ..where((s) => s.householdId.isNull()))
        .write(MenuSlotsCompanion(householdId: Value(householdId)));
  }

  /// Retourne le code du foyer depuis le cache local.
  Future<String?> getHouseholdCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyHouseholdCode);
  }

  /// Met en cache le code du foyer localement.
  Future<void> cacheHouseholdCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHouseholdCode, code);
  }

  // ── Private ────────────────────────────────────────────────────────────────

  Future<void> _persistHouseholdId(String householdId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHouseholdId, householdId);
    // Associer le household à l'utilisateur courant pour détecter les changements de compte.
    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      await prefs.setString(_keyAuthUserId, userId);
    }
  }

  Future<String> _generateUniqueCode() async {
    final random = Random.secure();
    for (var i = 0; i < 3; i++) {
      final code = (random.nextInt(900000) + 100000).toString();
      final existing = await _client
          .from('households')
          .select('id')
          .eq('code', code)
          .maybeSingle();
      if (existing == null) return code;
    }
    throw Exception('Impossible de générer un code unique après 3 tentatives');
  }
}
