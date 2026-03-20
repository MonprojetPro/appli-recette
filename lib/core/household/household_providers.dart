import 'package:appli_recette/core/auth/auth_state_provider.dart';
import 'package:appli_recette/core/database/database_provider.dart';
import 'package:appli_recette/core/household/household_service.dart';
import 'package:appli_recette/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider du service de gestion du foyer.
final householdServiceProvider = Provider<HouseholdService>((ref) {
  final db = ref.watch(databaseProvider);
  return HouseholdService(db);
});

/// Notifier pour l'état d'auto-join depuis un lien d'invitation.
class AutoJoinNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  // ignore: use_setters_to_change_properties
  void setInProgress(bool value) => state = value;
}

/// True quand un auto-join depuis un lien d'invitation est en cours.
/// Permet à HouseholdSetupScreen d'afficher un spinner pendant l'opération.
final autoJoinInProgressProvider =
    NotifierProvider<AutoJoinNotifier, bool>(AutoJoinNotifier.new);

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
  final householdId = await service.getCurrentHouseholdId();

  // Synchronisation onboarding ← foyer récupéré (nouveau device ou reconnexion).
  //
  // SharedPreferences est la source de vérité pour onboarding_complete.
  // Si les prefs disent "complet" mais que le provider Riverpod ne le sait pas
  // encore (nouveau build du provider, ou 1ère résolution après install),
  // on force la mise à jour pour que le router parte vers '/' et non '/onboarding'.
  if (householdId != null) {
    final prefs = await SharedPreferences.getInstance();
    final prefsComplete = prefs.getBool('onboarding_complete') == true;
    final riverpodComplete =
        ref.read(onboardingNotifierProvider).value == true;
    if (prefsComplete && !riverpodComplete) {
      await ref.read(onboardingNotifierProvider.notifier).complete();
    }
  }

  return householdId;
});

/// Provider du code d'invitation du foyer courant.
///
/// Lit d'abord depuis SharedPreferences (cache local, instantané).
/// Fallback vers Supabase si absent du cache, avec mise en cache du résultat.
final householdCodeProvider = FutureProvider<String?>((ref) async {
  final householdId = ref.watch(currentHouseholdIdProvider).value;
  if (householdId == null) return null;

  final service = ref.watch(householdServiceProvider);

  // Cache local en priorité — évite un appel réseau à chaque démarrage
  final localCode = await service.getHouseholdCode();
  if (localCode != null) return localCode;

  // Fallback Supabase avec gestion d'erreur
  try {
    final response = await Supabase.instance.client
        .from('households')
        .select('code')
        .eq('id', householdId)
        .maybeSingle();
    final code = response?['code'] as String?;
    if (code != null) await service.cacheHouseholdCode(code);
    return code;
  } catch (_) {
    return null;
  }
});

/// Provider indiquant si un foyer est configuré.
///
/// Dérivé de [currentHouseholdIdProvider] — true si [household_id] non null.
final hasHouseholdProvider = Provider<bool>((ref) {
  return ref.watch(currentHouseholdIdProvider).value != null;
});
