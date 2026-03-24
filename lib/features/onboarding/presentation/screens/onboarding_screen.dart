import 'package:appli_recette/core/theme/app_colors.dart';
import 'package:appli_recette/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:appli_recette/features/onboarding/presentation/screens/step1_household_screen.dart';
import 'package:appli_recette/features/onboarding/presentation/screens/step2_planning_screen.dart';
import 'package:appli_recette/features/onboarding/presentation/screens/step3_recipes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Écran d'onboarding principal — 3 étapes guidées.
///
/// Parcours 1 (étapes 7-8) : après création du foyer.
/// Non affiché pour les utilisateurs qui rejoignent un foyer existant.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _totalPages = 3;
  static const _stepTitles = ['Foyer', 'Planning', 'Recettes'];

  void _nextPage() {
    _controller.animateToPage(
      _currentPage + 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    _controller.animateToPage(
      _currentPage - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _complete() async {
    await ref.read(onboardingNotifierProvider.notifier).complete();
    // Le router détecte onboarding = true → redirige vers l'accueil
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Column(
                children: [
                  // Titre + bouton Passer
                  Row(
                    children: [
                      const Icon(
                        Icons.restaurant_menu,
                        color: AppColors.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'MenuFacile',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _complete,
                        child: Text(
                          'Passer',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Indicateur de progression — 3 dots animés
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_totalPages, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: i == _currentPage ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: i == _currentPage
                              ? AppColors.primary
                              : AppColors.disabled,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),

                  // Label étape courante
                  Text(
                    'Étape ${_currentPage + 1}/$_totalPages — ${_stepTitles[_currentPage]}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.divider),

            // ── Contenu des étapes (PageView non swipeable) ─────────────────
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) =>
                    setState(() => _currentPage = page),
                children: [
                  Step1HouseholdScreen(onNext: _nextPage),
                  Step2PlanningScreen(
                    onNext: _nextPage,
                    onPrevious: _previousPage,
                  ),
                  Step3RecipesScreen(
                    onComplete: _complete,
                    onPrevious: _previousPage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
