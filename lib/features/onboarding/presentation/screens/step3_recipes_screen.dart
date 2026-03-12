import 'package:appli_recette/core/constants/generation_constants.dart';
import 'package:appli_recette/core/theme/app_colors.dart';
import 'package:appli_recette/features/recipes/presentation/providers/recipes_provider.dart';
import 'package:appli_recette/features/recipes/view/create_full_recipe_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Étape 3 de l'onboarding : ajout des premières recettes.
///
/// Ouvre la page complète de création de recette via un bouton.
/// Le compteur "X/14 recettes" guide l'utilisateur vers le minimum requis.
/// Le bouton Terminer est actif dès qu'au moins 1 recette a été ajoutée.
class Step3RecipesScreen extends ConsumerWidget {
  const Step3RecipesScreen({
    required this.onComplete,
    required this.onPrevious,
    super.key,
  });

  final VoidCallback onComplete;
  final VoidCallback onPrevious;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recipes = ref.watch(recipesStreamProvider).value ?? [];
    final count = recipes.length;
    final remaining =
        (kMinRecipesForGeneration - count).clamp(0, kMinRecipesForGeneration);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tes premières recettes',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$kMinRecipesForGeneration recettes suffisent pour générer '
            'ton premier menu (7 jours × 2 repas) !',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Compteur de progression
          _RecipeProgressBanner(count: count),
          const SizedBox(height: 20),

          // Bouton d'ajout — ouvre la page complète
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CreateFullRecipePage(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une recette'),
            ),
          ),
          const SizedBox(height: 16),

          // Liste des recettes ajoutées
          if (recipes.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: recipes.length,
                itemBuilder: (context, i) {
                  final r = recipes[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 20,
                    ),
                    title: Text(
                      r.name,
                      style: theme.textTheme.bodyMedium,
                    ),
                    subtitle: Text(
                      r.mealType == 'lunch' ? 'Déjeuner' : 'Dîner',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            )
          else
            const Expanded(child: SizedBox.shrink()),

          const SizedBox(height: 12),

          // Message d'encouragement
          if (remaining > 0 && count > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                remaining == 1
                    ? 'Plus qu\'1 recette pour débloquer la génération !'
                    : 'Encore $remaining recettes pour débloquer la génération.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Boutons navigation
          Row(
            children: [
              TextButton.icon(
                onPressed: onPrevious,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Retour'),
              ),
              const Spacer(),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: onComplete,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: Text(
                      count >= kMinRecipesForGeneration
                          ? 'Terminer et générer !'
                          : count > 0
                              ? 'Terminer'
                              : 'Passer pour l\'instant',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Banner affichant la progression "X/14 recettes".
class _RecipeProgressBanner extends StatelessWidget {
  const _RecipeProgressBanner({required this.count});

  final int count;
  static const _target = kMinRecipesForGeneration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (count / _target).clamp(0.0, 1.0);
    final isComplete = count >= _target;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isComplete
            ? AppColors.success.withValues(alpha: 0.12)
            : AppColors.primaryLight.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isComplete ? AppColors.success : AppColors.primaryLight,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$count / $_target recettes',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isComplete ? AppColors.success : AppColors.primary,
                ),
              ),
              Icon(
                isComplete ? Icons.lock_open : Icons.lock_outline,
                size: 18,
                color: isComplete ? AppColors.success : AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation<Color>(
              isComplete ? AppColors.success : AppColors.primary,
            ),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          if (isComplete) ...[
            const SizedBox(height: 6),
            Text(
              'Génération débloquée !',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
