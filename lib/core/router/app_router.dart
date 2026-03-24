import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/router/app_router_notifier.dart';
import 'package:appli_recette/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:appli_recette/features/auth/presentation/screens/login_screen.dart';
import 'package:appli_recette/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:appli_recette/features/auth/presentation/screens/signup_screen.dart';
import 'package:appli_recette/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:appli_recette/features/generation/presentation/screens/home_screen.dart';
import 'package:appli_recette/features/household/view/household_page.dart';
import 'package:appli_recette/features/settings/presentation/screens/settings_screen.dart';
import 'package:appli_recette/features/household/view/member_form_page.dart';
import 'package:appli_recette/features/onboarding/presentation/screens/household_setup_screen.dart';
import 'package:appli_recette/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:appli_recette/features/planning/view/planning_page.dart';
import 'package:appli_recette/features/recipes/view/create_full_recipe_page.dart';
import 'package:appli_recette/features/recipes/view/recipe_detail_screen.dart';
import 'package:appli_recette/features/recipes/view/recipes_page.dart';
import 'package:appli_recette/features/generation/presentation/providers/generation_provider.dart';
import 'package:appli_recette/features/planning/presentation/providers/planning_provider.dart';
import 'package:appli_recette/features/recipes/presentation/providers/recipes_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Routes de l'application.
abstract class AppRoutes {
  static const home = '/';
  static const recipes = '/recipes';
  static const household = '/household';
  static const planning = '/planning';
  static const createFullRecipe = '/recipes/create-full';
  static const recipeDetail = '/recipes/:id';
  static const recipeEdit = '/recipes/:id/edit';

  // Household — membres
  static const memberAdd = '/household/member/add';
  static const memberEdit = '/household/member/:id/edit';

  // Auth (Story 8.1)
  static const login = '/login';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';
  static const verifyEmail = '/verify-email';

  // Setup (Story 8.2)
  static const householdSetup = '/household-setup';

  // Settings (Story 8.3)
  static const settings = '/settings';

  // Invitation deep-link (Story 8.3)
  static const join = '/join';

  // Reset mot de passe (Parcours 4)
  static const resetPassword = '/reset-password';

  // Onboarding
  static const onboarding = '/onboarding';

  /// Génère le chemin d'édition pour un membre donné.
  static String memberEditPath(String id) => '/household/member/$id/edit';
}

/// Provider du GoRouter — accède à [AppRouterNotifier] pour les redirects.
///
/// Utilise [appRouterNotifierProvider] comme [refreshListenable] afin de
/// ré-évaluer les redirects à chaque changement d'auth, foyer ou onboarding.
final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(appRouterNotifierProvider);

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      // ─── Routes auth (hors shell) ─────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => LoginScreen(
          existingAccount:
              state.uri.queryParameters['existing'] == 'true',
        ),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (context, state) => VerifyEmailScreen(
          email: state.uri.queryParameters['email'] ?? state.extra as String?,
        ),
      ),

      // ─── Setup foyer (hors shell — Story 8.2/8.3) ───────────────────────
      GoRoute(
        path: AppRoutes.householdSetup,
        builder: (context, state) => HouseholdSetupScreen(
          initialCode: state.uri.queryParameters['code'],
        ),
      ),

      // ─── Deep-link invitation (Story 8.3) ────────────────────────────────
      // Le code est sauvegardé par le redirect global (app_router_notifier).
      // Cette route ne sera jamais affichée (toujours redirigée).
      GoRoute(
        path: AppRoutes.join,
        builder: (context, state) => const SizedBox.shrink(),
      ),

      // ─── Réglages (Story 8.3) ────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),

      // ─── Onboarding 3 étapes (hors shell) ────────────────────────────────
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // ─── Shell principal avec BottomNavigationBar ─────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.recipes,
                builder: (context, state) => const RecipesPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.household,
                builder: (context, state) => const HouseholdPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.planning,
                builder: (context, state) => const PlanningPage(),
              ),
            ],
          ),
        ],
      ),

      // ─── Routes modales hors shell ─────────────────────────────────────────

      GoRoute(
        path: AppRoutes.createFullRecipe,
        builder: (context, state) => const CreateFullRecipePage(),
      ),
      GoRoute(
        path: AppRoutes.recipeDetail,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return RecipeDetailScreen(recipeId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.recipeEdit,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CreateFullRecipePage(recipeId: id);
        },
      ),

      // ─── Routes membres du foyer ───────────────────────────────────────────
      GoRoute(
        path: AppRoutes.memberAdd,
        builder: (context, state) => const MemberFormPage(),
      ),
      GoRoute(
        path: AppRoutes.memberEdit,
        redirect: (context, state) {
          if (state.extra == null) return AppRoutes.household;
          return null;
        },
        builder: (context, state) {
          final member = state.extra! as Member;
          return MemberFormPage(member: member);
        },
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

/// Shell principal avec BottomNavigationBar + FAB contextuel.
class AppShell extends ConsumerWidget {
  const AppShell({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      floatingActionButton: _buildFab(context, ref),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Recettes',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'Foyer',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Planning',
          ),
        ],
      ),
    );
  }

  Widget? _buildFab(BuildContext context, WidgetRef ref) {
    switch (navigationShell.currentIndex) {
      case 0: // Accueil — Générer le menu
        final canGenerate = ref.watch(canGenerateProvider);
        if (!canGenerate) return null;
        final weekKey = ref.watch(selectedWeekKeyProvider);
        final menuAsync = ref.watch(generateMenuProvider);
        final validatedAsync =
            ref.watch(validatedMenuDisplayProvider(weekKey));
        final isLoading = menuAsync.isLoading;
        // Regénérer si un menu existe pour CETTE semaine (en mémoire ou en drift)
        final hasMemoryMenu =
            menuAsync.value != null && menuAsync.value!.weekKey == weekKey;
        final hasValidatedMenu = validatedAsync.value != null;
        final isRegenerate = hasMemoryMenu || hasValidatedMenu;
        return FloatingActionButton(
          onPressed: isLoading
              ? null
              : () {
                  final filters = ref.read(filtersProvider);
                  ref
                      .read(generateMenuProvider.notifier)
                      .generate(filters);
                },
          tooltip: isRegenerate ? 'Regénérer le menu' : 'Générer le menu',
          child: isRegenerate
              ? const Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.autorenew, size: 44),
                    Icon(Icons.auto_awesome, size: 16),
                  ],
                )
              : const Icon(Icons.auto_awesome),
        );
      case 1: // Recettes — Nouvelle recette
        return FloatingActionButton(
          onPressed: () => context.push(AppRoutes.createFullRecipe),
          tooltip: 'Nouvelle recette',
          child: const Icon(Icons.add),
        );
      case 2: // Foyer — Ajouter un membre
        return FloatingActionButton(
          onPressed: () => context.push(AppRoutes.memberAdd),
          tooltip: 'Ajouter un membre',
          child: const Icon(Icons.person_add),
        );
      default: // Planning — pas de FAB
        return null;
    }
  }
}
