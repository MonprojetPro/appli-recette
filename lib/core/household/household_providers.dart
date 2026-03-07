import 'package:appli_recette/core/auth/auth_state_provider.dart';
import 'package:appli_recette/core/database/database_provider.dart';
import 'package:appli_recette/core/household/household_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider du service de gestion du foyer.
final householdServiceProvider = Provider<HouseholdService>((ref) {
  final db = ref.watch(databaseProvider);
  return HouseholdService(db);
});

/// Provider du household_id courant.
///
/// 1. Vérifie SharedPreferences (local).
/// 2. Si absent, vérifie Supabase household_auth_devices (auto-résolution).
///    Cela évite de redemander "Rejoindre un foyer" sur un nouveau navigateur.
///
/// Dépend de [authStateProvider] pour se ré-évaluer quand la session est prête.
final currentHouseholdIdProvider = FutureProvider<String?>((ref) async {
  // Se ré-évaluer quand l'état auth change (session restaurée)
  ref.watch(authStateProvider);
  final service = ref.watch(householdServiceProvider);
  return service.getCurrentHouseholdId();
});

/// Provider indiquant si un foyer est configuré.
///
/// Dérivé de [currentHouseholdIdProvider] — true si [household_id] non null.
final hasHouseholdProvider = Provider<bool>((ref) {
  return ref.watch(currentHouseholdIdProvider).value != null;
});
