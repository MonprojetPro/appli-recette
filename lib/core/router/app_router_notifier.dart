import 'package:appli_recette/core/auth/auth_state_provider.dart';
import 'package:appli_recette/core/household/household_providers.dart';
import 'package:appli_recette/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider du notifier utilisé par GoRouter pour ré-évaluer les redirects.
final appRouterNotifierProvider = Provider<AppRouterNotifier>((ref) {
  final notifier = AppRouterNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});

/// Notifier qui déclenche la réévaluation du redirect GoRouter.
///
/// Écoute les changements d'état auth, de foyer et d'onboarding,
/// puis appelle [notifyListeners] pour que GoRouter réévalue les redirects.
class AppRouterNotifier extends ChangeNotifier {
  AppRouterNotifier(this._ref) {
    _ref.listen<AsyncValue<AuthState>>(
      authStateProvider,
      (_, __) => notifyListeners(),
    );
    _ref.listen<AsyncValue<String?>>(
      currentHouseholdIdProvider,
      (_, __) => notifyListeners(),
    );
    _ref.listen<AsyncValue<bool>>(
      onboardingNotifierProvider,
      (_, __) => notifyListeners(),
    );
  }

  final Ref _ref;
  bool _autoJoinInProgress = false;

  /// Préfixes de routes publiques (accessibles sans authentification).
  static const _publicPrefixes = [
    '/login',
    '/signup',
    '/forgot-password',
    '/verify-email',
    '/join',
  ];

  /// Logique de redirection pour GoRouter.
  ///
  /// Retourne un chemin cible ou null (pas de redirection).
  String? redirect(BuildContext context, GoRouterState state) {
    final loc = state.matchedLocation;
    final authAsync = _ref.read(authStateProvider);

    // Attendre que l'état auth soit disponible
    if (authAsync.isLoading) return null;

    final session = authAsync.value?.session;
    final isAuthenticated = session != null;
    final isPublic = _publicPrefixes.any((p) => loc.startsWith(p));

    // Non authentifié : autoriser routes publiques, bloquer le reste
    if (!isAuthenticated) {
      return isPublic ? null : '/login';
    }

    // Authentifié : attendre que les providers async soient résolus
    final householdAsync = _ref.read(currentHouseholdIdProvider);
    final onboardingAsync = _ref.read(onboardingNotifierProvider);
    if (householdAsync.isLoading || onboardingAsync.isLoading) return null;

    // Authentifié sur une route publique → rediriger vers l'app
    if (isPublic) {
      return _resolveAuthenticatedRoute();
    }

    // Route /household-setup : vérifier si vraiment nécessaire
    if (loc == '/household-setup') {
      if (householdAsync.value != null) {
        return _resolveAuthenticatedRoute();
      }
      return null;
    }

    // Route /onboarding : vérifier si déjà complété
    if (loc == '/onboarding') {
      if (onboardingAsync.value == true) return '/';
      return null;
    }

    // Routes protégées : vérifier foyer configuré
    if (householdAsync.value == null) {
      // Vérifier s'il y a un code d'invitation pending (deep-link /join)
      if (!_autoJoinInProgress) {
        _autoJoinInProgress = true;
        _tryAutoJoin();
      }
      return '/household-setup';
    }

    return null;
  }

  /// Tente un auto-join si un pending_join_code est stocké.
  ///
  /// Lancé en fire-and-forget : si le code est valide, les providers
  /// sont invalidés et le router se réévalue automatiquement vers '/'.
  Future<void> _tryAutoJoin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('pending_join_code');
      if (code == null || code.isEmpty) return;

      // Consommer le code immédiatement (éviter boucle)
      await prefs.remove('pending_join_code');

      final service = _ref.read(householdServiceProvider);
      await service.joinHousehold(code);

      // Marquer l'onboarding comme complété
      await _ref.read(onboardingNotifierProvider.notifier).complete();

      // Invalider le provider → le router se réévalue
      _ref.invalidate(currentHouseholdIdProvider);
    } catch (_) {
      // Echec silencieux — l'utilisateur reste sur /household-setup
    } finally {
      _autoJoinInProgress = false;
    }
  }

  /// Détermine la route par défaut pour un utilisateur authentifié.
  ///
  /// Retourne `null` tant que les providers async ne sont pas résolus,
  /// ce qui évite un flicker vers la home avant la vraie destination.
  String? _resolveAuthenticatedRoute() {
    final householdAsync = _ref.read(currentHouseholdIdProvider);
    if (householdAsync.isLoading) return null;
    if (householdAsync.value == null) return '/household-setup';

    final onboardingAsync = _ref.read(onboardingNotifierProvider);
    if (onboardingAsync.isLoading) return null;
    if (!(onboardingAsync.value ?? false)) return '/onboarding';

    return '/';
  }
}
