import 'package:shared_preferences/shared_preferences.dart';

/// Service de gestion de l'état d'onboarding.
///
/// Persiste le flag `onboarding_complete` dans SharedPreferences.
/// Ce flag n'est PAS supprimé au sign-out (persiste entre sessions).
class OnboardingService {
  static const _key = 'onboarding_complete';

  /// Charge l'état depuis SharedPreferences.
  Future<bool> isComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  /// Marque l'onboarding comme complété.
  Future<void> setComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  /// Remet l'onboarding à faire (utilisé après création de foyer).
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, false);
  }
}
