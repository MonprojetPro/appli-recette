import 'package:appli_recette/features/onboarding/domain/onboarding_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider du service d'onboarding.
final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return OnboardingService();
});

/// Notifier async pour l'état d'onboarding.
///
/// Charge l'état depuis SharedPreferences au build, puis expose
/// [complete()] et [reset()] pour le modifier.
final onboardingNotifierProvider =
    AsyncNotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);

class OnboardingNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final service = ref.read(onboardingServiceProvider);
    return service.isComplete();
  }

  /// Marque l'onboarding comme terminé.
  Future<void> complete() async {
    final service = ref.read(onboardingServiceProvider);
    await service.setComplete();
    state = const AsyncData(true);
  }

  /// Remet l'onboarding à faire (après création de foyer).
  Future<void> reset() async {
    final service = ref.read(onboardingServiceProvider);
    await service.reset();
    state = const AsyncData(false);
  }
}
