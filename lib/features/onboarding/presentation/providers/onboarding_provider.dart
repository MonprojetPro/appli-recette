import 'package:appli_recette/features/onboarding/domain/onboarding_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Infrastructure provider — une seule instance par session app
// ---------------------------------------------------------------------------

final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return OnboardingService();
});

// ---------------------------------------------------------------------------
// Notifier principal — async au build (lecture SharedPreferences), sync ensuite
// ---------------------------------------------------------------------------

/// Notifier pour l'état de complétion de l'onboarding.
///
/// - Build : charge depuis SharedPreferences (async)
/// - Défaut si absent : true (complet) — pas d'onboarding pour les comptes existants
/// - [complete] : marque l'onboarding terminé + persiste
/// - [reset] : signale qu'un onboarding est requis (nouveau foyer créé) + persiste
class OnboardingNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final service = ref.read(onboardingServiceProvider);
    return service.loadComplete();
  }

  /// Marque l'onboarding comme terminé et persiste dans SharedPreferences.
  Future<void> complete() async {
    final service = ref.read(onboardingServiceProvider);
    await service.setComplete();
    state = const AsyncData(true);
  }

  /// Signale qu'un onboarding est requis (nouveau foyer créé).
  Future<void> reset() async {
    final service = ref.read(onboardingServiceProvider);
    await service.reset();
    state = const AsyncData(false);
  }
}

final onboardingNotifierProvider =
    AsyncNotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);
