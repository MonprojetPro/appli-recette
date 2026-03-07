import 'package:appli_recette/core/auth/auth_state_provider.dart';
import 'package:appli_recette/core/database/database_provider.dart';
import 'package:appli_recette/core/household/household_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// Provider du code d'invitation du foyer courant (depuis Supabase).
final householdCodeProvider = FutureProvider<String?>((ref) async {
  final householdId = ref.watch(currentHouseholdIdProvider).value;
  if (householdId == null) return null;

  final response = await Supabase.instance.client
      .from('households')
      .select('code')
      .eq('id', householdId)
      .single();

  return response['code'] as String?;
});

/// Provider indiquant si un foyer est configuré.
///
/// Dérivé de [currentHouseholdIdProvider] — true si [household_id] non null.
final hasHouseholdProvider = Provider<bool>((ref) {
  return ref.watch(currentHouseholdIdProvider).value != null;
});
