import 'package:shared_preferences/shared_preferences.dart';

/// Service de gestion de l'état d'onboarding.
///
/// Persiste le flag dans SharedPreferences pour survivre aux redémarrages.
///
/// Logique :
/// - Nouveaux utilisateurs sans foyer : onboarding requis après création
/// - Utilisateurs existants (clé 'onboarding_complete' = true) : pas d'onboarding
/// - Après completion des 3 étapes : setComplete() persiste le flag
/// - Sign-out ne touche PAS ce flag (même compte = même état)
class OnboardingService {
  static const _key = 'onboarding_complete';

  bool? _cached;

  /// Charge l'état depuis SharedPreferences. Doit être appelé au démarrage.
  Future<bool> loadComplete() async {
    final prefs = await SharedPreferences.getInstance();
    _cached = prefs.getBool(_key) ?? true; // défaut = complet (pas d'onboarding)
    return _cached!;
  }

  /// Retourne true si l'onboarding est terminé (ou non requis).
  /// Utilise le cache mémoire si disponible, sinon défaut = true.
  bool isComplete() => _cached ?? true;

  /// Marque l'onboarding comme terminé et persiste.
  Future<void> setComplete() async {
    _cached = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  /// Signale qu'un onboarding est requis (appelé après création d'un foyer).
  Future<void> reset() async {
    _cached = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, false);
  }
}
