import 'package:appli_recette/features/onboarding/domain/onboarding_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Infrastructure provider — une seule instance par session app
// ---------------------------------------------------------------------------

final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return OnboardingService();
});

// ---------------------------------------------------------------------------
// Notifier principal — synchrone, pas d'async, pas de SharedPreferences
// ---------------------------------------------------------------------------

/// Notifier pour l'état de complétion de l'onboarding.
///
/// - Défaut : true (complet) — aucun appel réseau, aucun localStorage
/// - [complete] : marque l'onboarding terminé
/// - [reset] : signale qu'un onboarding est requis (nouveau foyer créé)
class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Par défaut : onboarding complet — l'onboarding ne s'affiche que
    // si reset() est explicitement appelé dans la même session.
    return ref.read(onboardingServiceProvider).isComplete();
  }

  /// Marque l'onboarding comme terminé.
  void complete() {
    ref.read(onboardingServiceProvider).setComplete();
    state = true;
  }

  /// Signale qu'un onboarding est requis (nouveau foyer créé).
  void reset() {
    ref.read(onboardingServiceProvider).reset();
    state = false;
  }
}

final onboardingNotifierProvider =
    NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);
