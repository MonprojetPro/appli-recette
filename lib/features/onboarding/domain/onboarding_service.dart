import 'package:shared_preferences/shared_preferences.dart';

/// Service de gestion de l'état d'onboarding.
///
/// Utilise le flag [_kKeyInProgress] avec une logique inversée :
/// - Flag ABSENT (défaut) → onboarding complet (ou non nécessaire)
/// - Flag PRÉSENT et true → onboarding en cours (nouveau foyer créé)
///
/// Cela garantit que les nouveaux appareils et les reconnexions sautent
/// l'onboarding par défaut, sans nécessiter de synchronisation réseau.
class OnboardingService {
  static const _kKeyInProgress = 'onboarding_in_progress';

  /// Retourne true si l'onboarding est terminé (ou non requis).
  ///
  /// Par défaut (clé absente) = true. Seule la création d'un nouveau foyer
  /// positionne la clé à true pour déclencher l'onboarding.
  Future<bool> isComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kKeyInProgress) != true;
  }

  /// Marque l'onboarding comme terminé — supprime le flag.
  Future<void> setComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKeyInProgress);
  }

  /// Signale qu'un onboarding est requis (appelé après création d'un foyer).
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKeyInProgress, true);
  }
}
