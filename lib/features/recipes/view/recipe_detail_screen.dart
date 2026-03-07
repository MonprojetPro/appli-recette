import 'package:appli_recette/core/theme/app_colors.dart';
import 'package:appli_recette/core/utils/time_utils.dart';
import 'package:appli_recette/core/widgets/recipe_photo_widget.dart';
import 'package:appli_recette/features/household/household.dart';
import 'package:appli_recette/features/recipes/data/datasources/recipe_steps_local_datasource.dart';
import 'package:appli_recette/features/recipes/presentation/providers/recipes_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Fiche détail d'une recette.
class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({required this.recipeId, super.key});

  final String recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipeAsync = ref.watch(recipeByIdProvider(recipeId));
    final ingredientsAsync = ref.watch(ingredientsForRecipeProvider(recipeId));
    final stepsAsync = ref.watch(stepsForRecipeProvider(recipeId));
    final notifier = ref.read(recipesNotifierProvider.notifier);

    return recipeAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Erreur')),
        body: Center(child: Text('Erreur : $e')),
      ),
      data: (recipe) {
        if (recipe == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Recette introuvable')),
            body: const Center(child: Text("Cette recette n'existe plus.")),
          );
        }

        final totalTime = recipe.prepTimeMinutes +
            recipe.cookTimeMinutes +
            recipe.restTimeMinutes;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // ─── AppBar avec photo ──────────────────────────────────────
              SliverAppBar(
                expandedHeight: recipe.photoPath != null ? 260 : 0,
                pinned: true,
                actions: [
                  // Bouton favori
                  IconButton(
                    icon: Icon(
                      recipe.isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: recipe.isFavorite
                          ? AppColors.primary
                          : null,
                    ),
                    tooltip: recipe.isFavorite
                        ? 'Retirer des favoris'
                        : 'Ajouter aux favoris',
                    onPressed: () async {
                      try {
                        await notifier.toggleFavorite(
                          recipeId,
                          currentValue: recipe.isFavorite,
                        );
                      } on Exception catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur : $e')),
                          );
                        }
                      }
                    },
                  ),
                  // Bouton modifier
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Modifier',
                    onPressed: () =>
                        context.push('/recipes/$recipeId/edit'),
                  ),
                  // Bouton supprimer
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Supprimer',
                    onPressed: () => _confirmDelete(context, ref),
                  ),
                ],
                flexibleSpace: recipe.photoPath != null
                    ? FlexibleSpaceBar(
                        background: RecipePhotoWidget(
                          photoUrl: recipe.photoPath,
                          fit: BoxFit.contain,
                          fallbackIcon: Icons.broken_image_outlined,
                        ),
                      )
                    : null,
              ),

              // ─── Contenu ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nom + type + favori badge
                      Text(
                        recipe.name,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 8),

                      // Chips d'infos
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _InfoChip(
                            icon: Icons.restaurant_menu_outlined,
                            label: _mealTypeLabel(recipe.mealType),
                          ),
                          _InfoChip(
                            icon: Icons.timer_outlined,
                            label: formatTime(totalTime),
                          ),
                          if (recipe.servings > 0)
                            _InfoChip(
                              icon: Icons.people_outline,
                              label: '${recipe.servings} pers.',
                            ),
                          if (recipe.isVegetarian)
                            const _InfoChip(
                              icon: Icons.eco_outlined,
                              label: 'Végétarien',
                              color: Colors.green,
                            ),
                          if (recipe.season != 'all')
                            _InfoChip(
                              icon: Icons.wb_sunny_outlined,
                              label: _seasonLabel(recipe.season),
                            ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ─── Temps détaillé ────────────────────────────────
                      if (recipe.prepTimeMinutes > 0 ||
                          recipe.cookTimeMinutes > 0 ||
                          recipe.restTimeMinutes > 0) ...[
                        const _SectionTitle('Temps de préparation'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (recipe.prepTimeMinutes > 0)
                              _TimeBlock(
                                label: 'Préparation',
                                minutes: recipe.prepTimeMinutes,
                              ),
                            if (recipe.cookTimeMinutes > 0) ...[
                              const SizedBox(width: 16),
                              _TimeBlock(
                                label: 'Cuisson',
                                minutes: recipe.cookTimeMinutes,
                              ),
                            ],
                            if (recipe.restTimeMinutes > 0) ...[
                              const SizedBox(width: 16),
                              _TimeBlock(
                                label: 'Repos',
                                minutes: recipe.restTimeMinutes,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ─── Ingrédients ───────────────────────────────────
                      ingredientsAsync.when(
                        loading: () => const CircularProgressIndicator(),
                        error: (err, stack) => const SizedBox.shrink(),
                        data: (ingredients) {
                          if (ingredients.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionTitle(
                                'Ingrédients (${ingredients.length})',
                              ),
                              const SizedBox(height: 12),
                              ...ingredients.map(
                                (ing) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      if (ing.quantity != null)
                                        Text(
                                          '${formatQuantity(ing.quantity!)} ${ing.unit ?? ''} '.trim(),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      if (ing.quantity != null)
                                        const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          ing.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
                                      ),
                                      if (ing.supermarketSection != null)
                                        Text(
                                          ing.supermarketSection!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          );
                        },
                      ),

                      // ─── Étapes de préparation ─────────────────────────
                      stepsAsync.when(
                        loading: () => const CircularProgressIndicator(),
                        error: (err, stack) => const SizedBox.shrink(),
                        data: (steps) {
                          if (steps.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionTitle(
                                'Préparation (${steps.length} étape${steps.length > 1 ? 's' : ''})',
                              ),
                              const SizedBox(height: 12),
                              ...steps.map((step) {
                                final photos = step.photoPaths;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Numéro d'étape
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${step.stepNumber}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (step.instruction != null &&
                                                step.instruction!.isNotEmpty)
                                              Text(
                                                step.instruction!,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium,
                                              ),
                                            if (photos.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              SizedBox(
                                                height: 100,
                                                child: ListView.separated(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  itemCount: photos.length,
                                                  separatorBuilder: (_, __) =>
                                                      const SizedBox(
                                                          width: 8),
                                                  itemBuilder: (_, i) {
                                                    return RecipePhotoWidget(
                                                      photoUrl: photos[i],
                                                      height: 100,
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(8),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 8),
                            ],
                          );
                        },
                      ),

                      // ─── Notes ─────────────────────────────────────────
                      if (recipe.notes != null &&
                          recipe.notes!.isNotEmpty) ...[
                        const _SectionTitle('Notes'),
                        const SizedBox(height: 8),
                        Text(
                          recipe.notes!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ─── Variantes ─────────────────────────────────────
                      if (recipe.variants != null &&
                          recipe.variants!.isNotEmpty) ...[
                        const _SectionTitle('Variantes & astuces'),
                        const SizedBox(height: 8),
                        Text(
                          recipe.variants!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ─── Source URL ────────────────────────────────────
                      if (recipe.sourceUrl != null &&
                          recipe.sourceUrl!.isNotEmpty) ...[
                        const _SectionTitle('Source'),
                        const SizedBox(height: 8),
                        Semantics(
                          link: true,
                          label: 'Ouvrir la source : ${recipe.sourceUrl}',
                          child: InkWell(
                            onTap: () async {
                              var url = recipe.sourceUrl!;
                              // Ajouter https:// si pas de scheme
                              if (!url.startsWith('http://') &&
                                  !url.startsWith('https://')) {
                                url = 'https://$url';
                              }
                              final uri = Uri.tryParse(url);
                              // Bloquer les schemes dangereux
                              if (uri == null ||
                                  (uri.scheme != 'http' &&
                                      uri.scheme != 'https')) {
                                return;
                              }
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                recipe.sourceUrl!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppColors.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ─── Préférences du foyer ───────────────────────────
                      _PreferencesSection(recipeId: recipeId),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la recette ?'),
        content: const Text(
          'Cette action est irréversible. La recette et tous ses ingrédients seront supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Supprimer la photo de Supabase Storage si elle existe
      final recipe = ref.read(recipeByIdProvider(recipeId)).value;
      if (recipe?.photoPath != null &&
          recipe!.photoPath!.startsWith('http')) {
        try {
          final storageService = ref.read(supabaseStorageServiceProvider);
          await storageService.deleteByPublicUrl(recipe.photoPath!);
        } on Exception catch (_) {
          // Ignorer les erreurs de suppression Storage — la recette sera quand même supprimée
        }
      }
      await ref.read(recipesNotifierProvider.notifier).deleteRecipe(recipeId);
      if (context.mounted) {
        context.go('/recipes');
      }
    }
  }

  String _mealTypeLabel(String mealType) {
    return switch (mealType) {
      'breakfast' => 'Petit-déjeuner',
      'lunch' => 'Déjeuner',
      'dinner' => 'Dîner',
      'both' => 'Déjeuner + Dîner',
      'snack' => 'Goûter',
      'dessert' => 'Dessert',
      _ => mealType,
    };
  }

  String _seasonLabel(String season) {
    return switch (season) {
      'spring' => 'Printemps',
      'summer' => 'Été',
      'autumn' => 'Automne',
      'winter' => 'Hiver',
      _ => 'Toute saison',
    };
  }

}

// ---------------------------------------------------------------------------
// Widgets locaux
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
  });
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: effectiveColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: effectiveColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({required this.label, required this.minutes});
  final String label;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatTime(minutes),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}

/// Section "Préférences du foyer" affichant les notations de chaque membre.
class _PreferencesSection extends ConsumerWidget {
  const _PreferencesSection({required this.recipeId});

  final String recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersStreamProvider);
    final ratingsAsync = ref.watch(recipeRatingsProvider(recipeId));

    return membersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Text(
          'Impossible de charger les membres : $e',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.error,
              ),
        ),
      ),
      data: (members) {
        if (members.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Préférences du foyer'),
                const SizedBox(height: 8),
                Text(
                  'Ajoute des membres dans l\'onglet Foyer',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          );
        }

        return ratingsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              'Impossible de charger les notations : $e',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                  ),
            ),
          ),
          data: (ratings) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle('Préférences du foyer'),
                  const SizedBox(height: 8),
                  ...members.map((member) {
                    final memberRating = ratings
                        .where((r) => r.memberId == member.id)
                        .firstOrNull;
                    final ratingValue = memberRating != null
                        ? RatingValue.fromDb(memberRating.rating)
                        : null;
                    return MemberRatingRow(
                      member: member,
                      currentRating: ratingValue,
                      recipeId: recipeId,
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
