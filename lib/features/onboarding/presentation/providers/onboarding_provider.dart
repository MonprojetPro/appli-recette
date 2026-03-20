import 'package:appli_recette/core/household/household_providers.dart';
import 'package:appli_recette/features/onboarding/domain/onboarding_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Infrastructure provider
// ---------------------------------------------------------------------------

final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return OnboardingService();
});

// ---------------------------------------------------------------------------
// Notifier principal
// ---------------------------------------------------------------------------

/// Notifier pour l'état de complétion de l'onboarding.
///
/// - [build] : lit le flag persisté (async)
/// - [complete] : marque l'onboarding comme terminé et met à jour l'état
class OnboardingNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    // Se ré-évaluer quand l'état du foyer change.
    // Garantit que les prefs sont relus après la récupération Supabase sur
    // un nouvel appareil (getCurrentHouseholdId écrit onboarding_complete=true
    // dans les prefs avant de retourner — ce watch déclenche la relecture).
    ref.watch(currentHouseholdIdProvider);
    return ref.watch(onboardingServiceProvider).isComplete();
  }

  /// Marque l'onboarding comme terminé et notifie les listeners.
  Future<void> complete() async {
    state = await AsyncValue.guard(() async {
      await ref.read(onboardingServiceProvider).setComplete();
      return true;
    });
  }

  /// Réinitialise le flag onboarding (nouveau compte / déconnexion).
  Future<void> reset() async {
    await ref.read(onboardingServiceProvider).reset();
    state = const AsyncValue.data(false);
  }
}

final onboardingNotifierProvider =
    AsyncNotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);
