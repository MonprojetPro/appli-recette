import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/theme/app_colors.dart';
import 'package:appli_recette/core/utils/time_utils.dart';
import 'package:appli_recette/core/widgets/recipe_photo_widget.dart';
import 'package:appli_recette/features/recipes/presentation/providers/recipes_provider.dart';
import 'package:appli_recette/features/recipes/presentation/widgets/recipe_quick_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Écran principal de la collection de recettes.
class RecipesPage extends ConsumerStatefulWidget {
  const RecipesPage({super.key});

  @override
  ConsumerState<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends ConsumerState<RecipesPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipesSearchProvider(_searchQuery));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recettes'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Rechercher une recette...',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
              ],
              onChanged: (value) => setState(() => _searchQuery = value),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ),
      ),
      body: recipesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            'Erreur : $error',
            style: const TextStyle(color: AppColors.error),
          ),
        ),
        data: (recipes) {
          if (recipes.isEmpty && _searchQuery.isEmpty) {
            return const _EmptyRecipesState();
          }
          if (recipes.isEmpty) {
            return Center(
              child: Text(
                'Aucune recette pour "$_searchQuery"',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            );
          }
          return ListView.builder(
            itemCount: recipes.length,
            padding: const EdgeInsets.only(bottom: 80),
            itemBuilder: (context, index) =>
                _RecipeCard(recipe: recipes[index]),
          );
        },
      ),
    );
  }
}

/// État vide — aucune recette dans la collection.
class _EmptyRecipesState extends StatelessWidget {
  const _EmptyRecipesState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.menu_book_outlined,
              size: 80,
              color: AppColors.divider,
            ),
            const SizedBox(height: 24),
            Text(
              'Commence par ajouter une recette',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tape sur le bouton + en bas à droite '
              'pour créer ta première recette.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textHint,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte recette dans la liste.
class _RecipeCard extends ConsumerWidget {
  const _RecipeCard({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealType = MealType.tryFromValue(recipe.mealType) ?? MealType.lunch;
    final totalTime = recipe.prepTimeMinutes +
        recipe.cookTimeMinutes +
        recipe.restTimeMinutes;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/recipes/${recipe.id}'),
        child: Row(
          children: [
            // Photo ou icône
            SizedBox(
              width: 80,
              height: 80,
              child: RecipePhotoWidget(
                photoUrl: recipe.photoPath,
                width: 80,
                height: 80,
                fallbackIcon: mealType.icon,
                fallbackIconSize: 28,
              ),
            ),

            // Infos
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          mealType.label,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                        if (totalTime > 0) ...[
                          const Text(
                            ' · ',
                            style: TextStyle(color: AppColors.divider),
                          ),
                          const Icon(
                            Icons.timer_outlined,
                            size: 12,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            formatTime(totalTime),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textHint),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Badge favori + toggle
            IconButton(
              icon: Icon(
                recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: recipe.isFavorite ? AppColors.primary : AppColors.textHint,
                size: 20,
              ),
              onPressed: () => ref
                  .read(recipesNotifierProvider.notifier)
                  .toggleFavorite(recipe.id, currentValue: recipe.isFavorite),
            ),
          ],
        ),
      ),
    );
  }

}

