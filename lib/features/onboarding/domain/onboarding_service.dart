/// Service de gestion de l'état d'onboarding.
///
/// Utilise un flag EN MÉMOIRE UNIQUEMENT — aucune persistance locale.
///
/// Logique :
/// - Par défaut : onboarding complet (aucun localStorage, pas de stale state)
/// - Après création d'un nouveau foyer : reset() → onboarding requis
/// - Après completion des 3 étapes : setComplete() → retour au défaut
///
/// Cela garantit que sur un nouveau device, un refresh ou une reconnexion,
/// l'onboarding n'est JAMAIS affiché à tort.
class OnboardingService {
  bool _inProgress = false;

  /// Retourne true si l'onboarding est terminé (ou non requis).
  /// Par défaut = true. Ne lit jamais le localStorage.
  bool isComplete() => !_inProgress;

  /// Marque l'onboarding comme terminé.
  void setComplete() => _inProgress = false;

  /// Signale qu'un onboarding est requis (appelé après création d'un foyer).
  void reset() => _inProgress = true;
}
