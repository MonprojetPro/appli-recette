import 'package:appli_recette/core/auth/auth_state_provider.dart';
import 'package:appli_recette/core/auth/join_code_handler.dart';
import 'package:appli_recette/core/household/household_providers.dart';
import 'package:appli_recette/core/router/app_router.dart';
import 'package:appli_recette/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// État de l'auto-join (lien d'invitation).
enum AutoJoinStatus {
  idle,       // Pas de code en attente
  inProgress, // Tentative en cours
  failed,     // Échec — l'utilisateur doit saisir manuellement
}

/// Provider du notifier de routing — rafraîchit GoRouter quand l'auth change.
final appRouterNotifierProvider = Provider<AppRouterNotifier>((ref) {
  return AppRouterNotifier(ref);
});

/// Notifier de routing — gère les redirects selon l'état d'authentification,
/// du foyer et de l'onboarding.
///
/// Chaîne de décision :
/// 0. Password recovery → /reset-password
/// 1. Pas authentifié + /join → sauvegarder code → /signup
/// 2. Pas authentifié → /login (sauf routes publiques)
/// 3. Authentifié + pending join code → auto-join fire-and-forget
/// 4. Authentifié + pas de foyer → /household-setup
/// 5. Authentifié + foyer + onboarding pas fait → /onboarding
/// 6. Authentifié + foyer + onboarding fait → / (accueil)
class AppRouterNotifier extends ChangeNotifier {
  AppRouterNotifier(this._ref) {
    _ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, next) {
      // Détecter la session de récupération de mot de passe
      if (next.value?.event == AuthChangeEvent.passwordRecovery) {
        _isPasswordRecovery = true;
      }
      notifyListeners();
    });
    _ref.listen<AsyncValue<String?>>(currentHouseholdIdProvider, (_, __) {
      notifyListeners();
    });
    _ref.listen<AsyncValue<bool>>(onboardingNotifierProvider, (_, __) {
      notifyListeners();
    });
  }

  final Ref _ref;
  bool _autoJoinAttempted = false;
  bool _isPasswordRecovery = false;
  AutoJoinStatus _autoJoinStatus = AutoJoinStatus.idle;

  /// État de l'auto-join — lu par HouseholdSetupScreen.
  AutoJoinStatus get autoJoinStatus => _autoJoinStatus;

  /// Routes publiques accessibles sans authentification.
  static const _publicRoutes = [
    AppRoutes.login,
    AppRoutes.signup,
    AppRoutes.forgotPassword,
    AppRoutes.verifyEmail,
    AppRoutes.join,
  ];

  /// Redirect principal — appelé par GoRouter à chaque navigation.
  String? redirect(BuildContext context, GoRouterState state) {
    final authAsync = _ref.read(authStateProvider);
    final currentPath = state.matchedLocation;

    // Auth encore en chargement → pas de redirect
    if (authAsync.isLoading) return null;

    // ─── Password Recovery ────────────────────────────────────────
    // L'utilisateur a cliqué le lien de reset MDP dans son email.
    // Supabase a émis AuthChangeEvent.passwordRecovery.
    if (_isPasswordRecovery) {
      if (currentPath == AppRoutes.resetPassword) return null;
      return AppRoutes.resetPassword;
    }

    final session = Supabase.instance.client.auth.currentSession;
    final isAuthenticated = session != null;
    final isOnPublicRoute = _publicRoutes.contains(currentPath);

    // ─── Pas authentifié ───────────────────────────────────────────
    if (!isAuthenticated) {
      if (currentPath == AppRoutes.join) {
        return AppRoutes.signup;
      }
      if (isOnPublicRoute) return null;
      return AppRoutes.login;
    }

    // ─── Authentifié ───────────────────────────────────────────────

    // Lien d'invitation → toujours vers /household-setup (évite l'écran blanc
    // du SizedBox.shrink pendant que le provider household charge)
    if (currentPath == AppRoutes.join) {
      return AppRoutes.householdSetup;
    }

    // Si sur une route publique → résoudre la destination authentifiée
    if (isOnPublicRoute) {
      return _resolveAuthenticatedRoute();
    }

    // Sur /reset-password sans être en recovery → retour à l'accueil
    if (currentPath == AppRoutes.resetPassword) {
      return _resolveAuthenticatedRoute();
    }

    // Sur /household-setup → vérifier si le foyer est déjà configuré
    if (currentPath == AppRoutes.householdSetup) {
      final householdAsync = _ref.read(currentHouseholdIdProvider);
      final hasHousehold = householdAsync.value != null;
      if (hasHousehold) return _checkOnboarding();

      // Tenter auto-join si un code est en attente
      if (!_autoJoinAttempted) {
        _tryAutoJoin();
      }
      return null;
    }

    // Sur /onboarding → vérifier si déjà fait
    if (currentPath == AppRoutes.onboarding) {
      final onboardingAsync = _ref.read(onboardingNotifierProvider);
      final isComplete = onboardingAsync.value ?? false;
      if (isComplete) return AppRoutes.home;
      return null;
    }

    // Route protégée → vérifier foyer
    final householdAsync = _ref.read(currentHouseholdIdProvider);
    if (householdAsync.isLoading) return null;
    final hasHousehold = householdAsync.value != null;
    if (!hasHousehold) return AppRoutes.householdSetup;

    // Foyer OK → vérifier onboarding
    final onboardingAsync = _ref.read(onboardingNotifierProvider);
    if (onboardingAsync.isLoading) return null;
    final onboardingComplete = onboardingAsync.value ?? false;
    if (!onboardingComplete) return AppRoutes.onboarding;

    return null;
  }

  /// Réinitialise le statut auto-join après affichage de l'erreur.
  void clearAutoJoinFailed() {
    _autoJoinStatus = AutoJoinStatus.idle;
    notifyListeners();
  }

  /// Réinitialise le flag password recovery après changement de MDP.
  void clearPasswordRecovery() {
    _isPasswordRecovery = false;
    notifyListeners();
  }

  /// Détermine la destination pour un utilisateur authentifié.
  String? _resolveAuthenticatedRoute() {
    final householdAsync = _ref.read(currentHouseholdIdProvider);
    if (householdAsync.isLoading) return null;
    final hasHousehold = householdAsync.value != null;

    if (!hasHousehold) return AppRoutes.householdSetup;

    return _checkOnboarding();
  }

  /// Vérifie l'état d'onboarding et redirige.
  String _checkOnboarding() {
    final onboardingAsync = _ref.read(onboardingNotifierProvider);
    final isComplete = onboardingAsync.value ?? false;
    if (!isComplete) return AppRoutes.onboarding;
    return AppRoutes.home;
  }

  /// Auto-join fire-and-forget depuis un code d'invitation.
  void _tryAutoJoin() {
    _autoJoinAttempted = true;

    // Lecture synchrone mémoire d'abord (pas de latence)
    final memoryCode = JoinCodeHandler.pendingJoinCode;
    if (memoryCode != null) {
      _executeAutoJoin(memoryCode);
      return;
    }

    // Fallback async SharedPreferences
    JoinCodeHandler.consume().then((code) {
      if (code != null) {
        _executeAutoJoin(code);
      }
      // Pas de code → l'utilisateur saisit manuellement, pas de loading
    });
  }

  /// Exécute l'auto-join avec le code donné.
  Future<void> _executeAutoJoin(String code) async {
    _autoJoinStatus = AutoJoinStatus.inProgress;
    notifyListeners();

    try {
      debugPrint('[Router] Auto-join avec code: $code');
      final service = _ref.read(householdServiceProvider);
      await service.joinHousehold(code);

      // Skip onboarding pour les utilisateurs qui rejoignent
      await _ref.read(onboardingNotifierProvider.notifier).complete();

      // Consommer le code
      await JoinCodeHandler.consume();

      _autoJoinStatus = AutoJoinStatus.idle;

      // Invalider le provider foyer → le router réévalue (+ notifyListeners)
      _ref.invalidate(currentHouseholdIdProvider);
    } on Exception catch (e) {
      debugPrint('[Router] Auto-join échoué: $e');
      _autoJoinStatus = AutoJoinStatus.failed;
      notifyListeners();
    }
  }
}
