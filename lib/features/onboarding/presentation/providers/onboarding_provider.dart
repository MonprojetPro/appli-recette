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
/// - [build] : lit le flag persisté (async). Défaut = true (complet).
/// - [complete] : marque l'onboarding comme terminé et met à jour l'état
/// - [reset] : signale qu'un onboarding est requis (nouveau foyer créé)
class OnboardingNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return ref.watch(onboardingServiceProvider).isComplete();
  }

  /// Marque l'onboarding comme terminé et notifie les listeners.
  Future<void> complete() async {
    state = await AsyncValue.guard(() async {
      await ref.read(onboardingServiceProvider).setComplete();
      return true;
    });
  }

  /// Signale qu'un onboarding est requis (nouveau foyer créé).
  Future<void> reset() async {
    await ref.read(onboardingServiceProvider).reset();
    state = const AsyncValue.data(false);
  }
}

final onboardingNotifierProvider =
    AsyncNotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);
