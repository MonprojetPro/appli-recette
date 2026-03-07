import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/theme/app_colors.dart';
import 'package:appli_recette/core/utils/time_utils.dart';
import 'package:appli_recette/features/recipes/data/datasources/recipe_steps_local_datasource.dart';
import 'package:appli_recette/features/recipes/domain/models/meal_type.dart';
import 'package:appli_recette/features/recipes/domain/repositories/ingredient_repository.dart';
import 'package:appli_recette/features/recipes/presentation/providers/recipes_provider.dart';
import 'package:appli_recette/features/recipes/presentation/widgets/preparation_steps_editor.dart';
import 'package:appli_recette/features/recipes/presentation/widgets/recipe_form_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Écran unifié de création / édition d'une recette.
///
/// - Sans [recipeId] → mode création (formulaire vide).
/// - Avec [recipeId] → mode édition (pré-remplissage depuis la DB).
class CreateFullRecipePage extends ConsumerStatefulWidget {
  const CreateFullRecipePage({super.key, this.recipeId});

  /// Si non-null, on est en mode édition.
  final String? recipeId;

  bool get isEditMode => recipeId != null;

  @override
  ConsumerState<CreateFullRecipePage> createState() =>
      _CreateFullRecipePageState();
}

class _CreateFullRecipePageState extends ConsumerState<CreateFullRecipePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _initialized = false;

  // Section 1
  final _nameController = TextEditingController();
  final _prepTimeController = TextEditingController(text: '15');
  final _cookTimeController = TextEditingController(text: '0');
  final _restTimeController = TextEditingController(text: '0');
  MealType? _selectedMealType;

  // Section 2
  String _season = 'all';
  bool _isVegetarian = false;
  final _servingsController = TextEditingController(text: '4');
  final List<RecipeIngredientRow> _ingredients = [];

  // Étapes de préparation
  final List<StepEditorData> _steps = [];

  // Section 3
  final _notesController = TextEditingController();
  final _variantsController = TextEditingController();
  final _sourceUrlController = TextEditingController();

  // Photo
  String? _photoPath;
  bool _isUploadingPhoto = false;
  // ID de recette pré-généré quand une photo est uploadée avant le save en mode création
  String? _pendingRecipeId;

  int get _totalTime =>
      (int.tryParse(_prepTimeController.text) ?? 0) +
      (int.tryParse(_cookTimeController.text) ?? 0) +
      (int.tryParse(_restTimeController.text) ?? 0);

  @override
  void dispose() {
    _nameController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _restTimeController.dispose();
    _servingsController.dispose();
    _notesController.dispose();
    _variantsController.dispose();
    _sourceUrlController.dispose();
    for (final row in _ingredients) {
      row.dispose();
    }
    for (final step in _steps) {
      step.dispose();
    }
    super.dispose();
  }

  // ─── Pré-remplissage en mode édition ──────────────────────────────────────

  void _initFromRecipe(Recipe recipe) {
    if (_initialized) return;
    _initialized = true;
    _nameController.text = recipe.name;
    _prepTimeController.text = recipe.prepTimeMinutes.toString();
    _cookTimeController.text = recipe.cookTimeMinutes.toString();
    _restTimeController.text = recipe.restTimeMinutes.toString();
    _selectedMealType =
        MealType.tryFromValue(recipe.mealType) ?? MealType.lunch;
    _season = recipe.season;
    _isVegetarian = recipe.isVegetarian;
    _servingsController.text = recipe.servings.toString();
    _notesController.text = recipe.notes ?? '';
    _variantsController.text = recipe.variants ?? '';
    _sourceUrlController.text = recipe.sourceUrl ?? '';
    _photoPath = recipe.photoPath;
  }

  void _initIngredients(List<Ingredient> ingredients) {
    if (_ingredients.isNotEmpty) return;
    for (final ing in ingredients) {
      _ingredients.add(
        RecipeIngredientRow.fromValues(
          name: ing.name,
          quantity: ing.quantity != null ? _fmtQty(ing.quantity!) : '',
          unit: ing.unit ?? '',
          section: ing.supermarketSection ?? '',
        ),
      );
    }
  }

  void _initSteps(List<RecipeStep> steps) {
    if (_steps.isNotEmpty) return;
    for (final step in steps) {
      _steps.add(
        StepEditorData(
          instruction: step.instruction,
          photoPaths: step.photoPaths,
        ),
      );
    }
  }

  static String _fmtQty(double qty) {
    return qty == qty.truncateToDouble()
        ? qty.toInt().toString()
        : qty.toString();
  }

  // ─── Photo ────────────────────────────────────────────────────────────────

  Future<void> _pickPhoto(ImageSource source) async {
    final imageService = ref.read(imageServiceProvider);
    final storageService = ref.read(supabaseStorageServiceProvider);
    setState(() => _isUploadingPhoto = true);
    try {
      // 1. Sélectionner l'image (retourne bytes bruts)
      final bytes = source == ImageSource.camera
          ? await imageService.pickFromCamera()
          : await imageService.pickFromGallery();
      if (bytes == null) return;

      // 2. Compresser < 500 Ko
      final compressed = await imageService.compressImage(bytes);

      // 3. Upload vers Supabase Storage
      final prefs = await SharedPreferences.getInstance();
      final householdId = prefs.getString('household_id');
      if (householdId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur : foyer non configuré')),
          );
        }
        return;
      }

      // Utiliser l'ID existant en mode édition, ou un ID stable en création
      // (réutilise le même UUID si l'utilisateur re-pick une photo)
      final recipeId =
          widget.recipeId ?? (_pendingRecipeId ??= const Uuid().v4());

      final url = await storageService.uploadRecipePhoto(
        bytes: compressed,
        householdId: householdId,
        recipeId: recipeId,
      );

      if (mounted) setState(() => _photoPath = url);
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur upload photo : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _showPhotoOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Prendre une photo'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir depuis la galerie'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await _pickPhoto(ImageSource.gallery);
              },
            ),
            if (_photoPath != null)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Supprimer la photo',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  // Supprimer du Storage si c'est une URL Supabase
                  if (_photoPath != null && _photoPath!.startsWith('http')) {
                    try {
                      final storageService =
                          ref.read(supabaseStorageServiceProvider);
                      await storageService.deleteByPublicUrl(_photoPath!);
                    } on Exception catch (_) {
                      // Ignorer — la photo sera supprimée côté DB
                    }
                  }
                  setState(() => _photoPath = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  // ─── Sauvegarde ───────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedMealType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionne un type de repas')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final notifier = ref.read(recipesNotifierProvider.notifier);

      // Construire la liste d'étapes
      final stepInputs = _steps
          .where(
            (s) =>
                s.instructionController.text.trim().isNotEmpty ||
                s.photoPaths.isNotEmpty,
          )
          .map(
            (s) => RecipeStepInput(
              instruction: s.instructionController.text.trim().isEmpty
                  ? null
                  : s.instructionController.text.trim(),
              photoPaths: List.of(s.photoPaths),
            ),
          )
          .toList();

      // Construire la liste d'ingrédients
      final ingInputs = _ingredients
          .where((r) => r.nameController.text.trim().isNotEmpty)
          .map(
            (r) => IngredientInput(
              name: r.nameController.text.trim(),
              quantity: double.tryParse(r.quantityController.text),
              unit: r.unitController.text.trim().isEmpty
                  ? null
                  : r.unitController.text.trim(),
              supermarketSection: r.sectionController.text.trim().isEmpty
                  ? null
                  : r.sectionController.text.trim(),
            ),
          )
          .toList();

      if (widget.isEditMode) {
        // ── Mode édition ──
        final id = widget.recipeId!;
        await notifier.replaceSteps(recipeId: id, steps: stepInputs);
        await notifier.updateRecipeWithIngredients(
          id: id,
          name: _nameController.text.trim(),
          mealType: _selectedMealType!.value,
          prepTimeMinutes: int.tryParse(_prepTimeController.text) ?? 0,
          cookTimeMinutes: int.tryParse(_cookTimeController.text) ?? 0,
          restTimeMinutes: int.tryParse(_restTimeController.text) ?? 0,
          season: _season,
          isVegetarian: _isVegetarian,
          servings: int.tryParse(_servingsController.text) ?? 4,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          variants: _variantsController.text.trim().isEmpty
              ? null
              : _variantsController.text.trim(),
          sourceUrl: _sourceUrlController.text.trim().isEmpty
              ? null
              : _sourceUrlController.text.trim(),
          photoPath: _photoPath,
          ingredients: ingInputs,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recette mise à jour !')),
          );
          Navigator.of(context).pop();
        }
      } else {
        // ── Mode création ──
        final newId = await notifier.createRecipe(
          name: _nameController.text.trim(),
          mealType: _selectedMealType!.value,
          prepTimeMinutes: int.tryParse(_prepTimeController.text) ?? 15,
          cookTimeMinutes: int.tryParse(_cookTimeController.text) ?? 0,
          restTimeMinutes: int.tryParse(_restTimeController.text) ?? 0,
        );

        await notifier.replaceSteps(recipeId: newId, steps: stepInputs);

        await notifier.updateRecipeWithIngredients(
          id: newId,
          name: _nameController.text.trim(),
          mealType: _selectedMealType!.value,
          prepTimeMinutes: int.tryParse(_prepTimeController.text) ?? 15,
          cookTimeMinutes: int.tryParse(_cookTimeController.text) ?? 0,
          restTimeMinutes: int.tryParse(_restTimeController.text) ?? 0,
          season: _season,
          isVegetarian: _isVegetarian,
          servings: int.tryParse(_servingsController.text) ?? 4,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          variants: _variantsController.text.trim().isEmpty
              ? null
              : _variantsController.text.trim(),
          sourceUrl: _sourceUrlController.text.trim().isEmpty
              ? null
              : _sourceUrlController.text.trim(),
          photoPath: _photoPath,
          ingredients: ingInputs,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '« ${_nameController.text.trim()} » ajoutée !',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.of(context).pop();
        }
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!widget.isEditMode) {
      return _buildForm(context);
    }

    // Mode édition : charger la recette, ingrédients et étapes
    final recipeAsync = ref.watch(recipeByIdProvider(widget.recipeId!));

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
        _initFromRecipe(recipe);

        final ingredientsAsync =
            ref.watch(ingredientsForRecipeProvider(widget.recipeId!));
        final stepsAsync =
            ref.watch(stepsForRecipeProvider(widget.recipeId!));

        return ingredientsAsync.when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            appBar: AppBar(title: const Text('Erreur')),
            body: Center(child: Text('$e')),
          ),
          data: (ingredients) {
            _initIngredients(ingredients);

            return stepsAsync.when(
              loading: () => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _buildForm(context), // fallback sans étapes
              data: (steps) {
                _initSteps(steps);
                return _buildForm(context);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.isEditMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Modifier la recette' : 'Nouvelle recette'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Annuler',
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enregistrer'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            // ─── Photo ──────────────────────────────────────────────────
            RecipeFormPhotoSection(
              photoPath: _photoPath,
              isLoading: _isUploadingPhoto,
              onTap: _showPhotoOptions,
            ),
            const SizedBox(height: 24),

            // ─── Section 1 : Infos essentielles ─────────────────────────
            const RecipeFormSectionHeader('Informations essentielles'),
            const SizedBox(height: 16),

            TextFormField(
              controller: _nameController,
              autofocus: !isEdit,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nom de la recette *',
                hintText: 'Ex. Poulet rôti aux herbes',
                prefixIcon: Icon(Icons.restaurant_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().length < 2) {
                  return 'Nom obligatoire (min. 2 caractères)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            Text(
              'Type de repas *',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MealType.values.map((type) {
                final isSelected = _selectedMealType == type;
                return ChoiceChip(
                  label: Text(type.label),
                  avatar: Icon(
                    type.icon,
                    size: 16,
                    color:
                        isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  labelStyle: theme.textTheme.labelMedium?.copyWith(
                    color:
                        isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                  onSelected: (_) =>
                      setState(() => _selectedMealType = type),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: RecipeFormTimeField(
                    controller: _prepTimeController,
                    label: 'Préparation *',
                    required: true,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RecipeFormTimeField(
                    controller: _cookTimeController,
                    label: 'Cuisson',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RecipeFormTimeField(
                    controller: _restTimeController,
                    label: 'Repos',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Temps total : ${formatTime(_totalTime)}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),

            // ─── Section 2 : Détails ─────────────────────────────────────
            const RecipeFormSectionHeader('Détails de la recette'),
            const SizedBox(height: 16),

            Text(
              'Saison',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ('all', 'Toute saison'),
                ('spring', 'Printemps'),
                ('summer', 'Été'),
                ('autumn', 'Automne'),
                ('winter', 'Hiver'),
              ].map((entry) {
                final isSelected = _season == entry.$1;
                return ChoiceChip(
                  label: Text(entry.$2),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  labelStyle: theme.textTheme.labelMedium?.copyWith(
                    color:
                        isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                  onSelected: (_) => setState(() => _season = entry.$1),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    value: _isVegetarian,
                    onChanged: (v) => setState(() => _isVegetarian = v),
                    title: const Text('Végétarien'),
                    secondary: const Icon(Icons.eco_outlined),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: _servingsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'Portions',
                      suffixText: 'pers.',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ingrédients',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                TextButton.icon(
                  onPressed: () => setState(
                    () => _ingredients.add(RecipeIngredientRow()),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ajouter'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._ingredients.asMap().entries.map(
                  (e) => RecipeIngredientRowWidget(
                    key: ValueKey(e.key),
                    row: e.value,
                    onRemove: () => setState(() {
                      _ingredients[e.key].dispose();
                      _ingredients.removeAt(e.key);
                    }),
                  ),
                ),
            const SizedBox(height: 24),

            // ─── Section 3 : Préparation ─────────────────────────────────
            const RecipeFormSectionHeader('Préparation'),
            const SizedBox(height: 4),
            Text(
              'Décris les étapes et/ou ajoute des photos pour chaque étape.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 12),
            PreparationStepsEditor(steps: _steps),
            const SizedBox(height: 24),

            // ─── Section 4 : Notes, variantes, URL ───────────────────────
            const RecipeFormSectionHeader('Notes & Sources'),
            const SizedBox(height: 16),

            TextFormField(
              controller: _notesController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes libres',
                hintText: 'Instructions, étapes, conseils...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _variantsController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Variantes & astuces',
                hintText: 'Substitutions, variantes possibles...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _sourceUrlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL source',
                hintText: 'https://...',
                prefixIcon: Icon(Icons.link_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final url = v.trim();
                final uri = Uri.tryParse(
                  url.startsWith('http') ? url : 'https://$url',
                );
                if (uri == null || !uri.hasAuthority) {
                  return 'URL invalide';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isEdit
                          ? 'Enregistrer les modifications'
                          : 'Enregistrer la recette',
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
