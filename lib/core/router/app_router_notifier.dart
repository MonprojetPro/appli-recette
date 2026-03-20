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

  /// Stockage en mémoire du code d'invitation (évite la race condition
  /// entre la sauvegarde async SharedPreferences et _tryAutoJoin).
  String? _pendingJoinCode;

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

    // /join — sauvegarder le code et rediriger vers /signup
    if (loc.startsWith('/join')) {
      final code = state.uri.queryParameters['code'];
      if (code != null && code.isNotEmpty) {
        // Stockage synchrone en mémoire : élimine la race condition
        // entre la sauvegarde async SharedPreferences et _tryAutoJoin().
        _pendingJoinCode = code;
        // Aussi sauvegarder dans SharedPreferences pour persistance (app restart)
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('pending_join_code', code);
        });
      }
      return isAuthenticated ? '/' : '/signup';
    }

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
        _ref.read(autoJoinInProgressProvider.notifier).setInProgress(true);
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
  /// Utilise d'abord le code en mémoire (_pendingJoinCode) pour éviter
  /// la race condition avec la sauvegarde async SharedPreferences.
  Future<void> _tryAutoJoin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Priorité au code en mémoire (pas de race condition)
      final code = _pendingJoinCode ?? prefs.getString('pending_join_code');
      _pendingJoinCode = null; // Consommé

      if (code == null || code.isEmpty) return;

      final service = _ref.read(householdServiceProvider);
      await service.joinHousehold(code);

      // Consommer le code stocké après un join réussi
      await prefs.remove('pending_join_code');

      // Rejoindre via lien → onboarding skippé, aller directement à l'accueil
      await _ref.read(onboardingNotifierProvider.notifier).complete();

      // Invalider le provider → le router se réévalue vers '/'
      _ref.invalidate(currentHouseholdIdProvider);
    } catch (e) {
      // Echec — l'utilisateur reste sur /household-setup pour saisir manuellement
      debugPrint('[AutoJoin] échec: $e');
    } finally {
      _autoJoinInProgress = false;
      _ref.read(autoJoinInProgressProvider.notifier).setInProgress(false);
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
