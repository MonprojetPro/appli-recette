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

/// Provider du notifier de routing — rafraîchit GoRouter quand l'auth change.
final appRouterNotifierProvider = Provider<AppRouterNotifier>((ref) {
  return AppRouterNotifier(ref);
});

/// Notifier de routing — gère les redirects selon l'état d'authentification,
/// du foyer et de l'onboarding.
///
/// Chaîne de décision :
/// 1. Pas authentifié + /join → sauvegarder code → /signup
/// 2. Pas authentifié → /login (sauf routes publiques)
/// 3. Authentifié + pending join code → auto-join fire-and-forget
/// 4. Authentifié + pas de foyer → /household-setup
/// 5. Authentifié + foyer + onboarding pas fait → /onboarding
/// 6. Authentifié + foyer + onboarding fait → / (accueil)
class AppRouterNotifier extends ChangeNotifier {
  AppRouterNotifier(this._ref) {
    _ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, __) {
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

    final session = Supabase.instance.client.auth.currentSession;
    final isAuthenticated = session != null;
    final isOnPublicRoute = _publicRoutes.contains(currentPath);

    // ─── Pas authentifié ───────────────────────────────────────────
    if (!isAuthenticated) {
      // /join → le code a déjà été capturé par JoinCodeHandler dans main
      // Rediriger vers /signup pour créer un compte
      if (currentPath == AppRoutes.join) {
        return AppRoutes.signup;
      }
      if (isOnPublicRoute) return null;
      return AppRoutes.login;
    }

    // ─── Authentifié ───────────────────────────────────────────────

    // Si sur une route publique → résoudre la destination authentifiée
    if (isOnPublicRoute) {
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
  ///
  /// Parcours 3 : l'utilisateur a cliqué un lien d'invitation,
  /// créé un compte, et se connecte. Le code est en mémoire/SharedPreferences.
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
    });
  }

  /// Exécute l'auto-join avec le code donné.
  Future<void> _executeAutoJoin(String code) async {
    try {
      debugPrint('[Router] Auto-join avec code: $code');
      final service = _ref.read(householdServiceProvider);
      await service.joinHousehold(code);

      // Skip onboarding pour les utilisateurs qui rejoignent
      await _ref.read(onboardingNotifierProvider.notifier).complete();

      // Consommer le code
      await JoinCodeHandler.consume();

      // Invalider le provider foyer → le router réévalue
      _ref.invalidate(currentHouseholdIdProvider);
    } catch (e) {
      debugPrint('[Router] Auto-join échoué: $e');
      // L'utilisateur verra le household-setup pour saisir manuellement
    }
  }
}
