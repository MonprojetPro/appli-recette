import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/utils/time_utils.dart';
import 'package:flutter/material.dart';

/// Bottom sheet permettant de choisir une recette pour remplacer un créneau.
///
/// Affiche toutes les recettes avec un champ de recherche filtrable en temps réel.
class RecipePickerSheet extends StatefulWidget {
  const RecipePickerSheet({
    super.key,
    required this.recipes,
    this.onPick,
  });

  final List<Recipe> recipes;
  final void Function(String recipeId)? onPick;

  @override
  State<RecipePickerSheet> createState() => _RecipePickerSheetState();
}

class _RecipePickerSheetState extends State<RecipePickerSheet> {
  final _searchController = TextEditingController();
  final _searchNotifier = ValueNotifier<String>('');

  @override
  void initState() {
    super.initState();
    _searchController.addListener(
      () => _searchNotifier.value = _searchController.text,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // ── DragHandle ──
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // ── Titre + champ de recherche ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choisir une recette',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Rechercher…',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // ── Liste filtrée ──
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: _searchNotifier,
                builder: (context, query, _) {
                  final filtered = query.isEmpty
                      ? widget.recipes
                      : widget.recipes
                          .where(
                            (r) => r.name
                                .toLowerCase()
                                .contains(query.toLowerCase()),
                          )
                          .toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('Aucune recette trouvée'),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final recipe = filtered[index];
                      return ListTile(
                        title: Text(recipe.name),
                        subtitle: Text(_mealTypeLabel(recipe.mealType)),
                        trailing: Text(
                          formatTime(recipe.prepTimeMinutes),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onPick?.call(recipe.id);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _mealTypeLabel(String mealType) => switch (mealType) {
        'breakfast' => 'Petit-déjeuner',
        'lunch' => 'Déjeuner',
        'dinner' => 'Dîner',
        'both' => 'Déjeuner + Dîner',
        'snack' => 'Goûter',
        'dessert' => 'Dessert',
        _ => mealType,
      };

}
