import 'package:appli_recette/core/theme/app_colors.dart';
import 'package:appli_recette/core/widgets/recipe_photo_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widgets partagés pour le formulaire de recette (CreateFullRecipePage).

// ---------------------------------------------------------------------------
// En-tête de section
// ---------------------------------------------------------------------------

class RecipeFormSectionHeader extends StatelessWidget {
  const RecipeFormSectionHeader(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
        ),
        const Divider(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Champ de saisie de temps
// ---------------------------------------------------------------------------

class RecipeFormTimeField extends StatelessWidget {
  const RecipeFormTimeField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.required = false,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'min',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 14,
        ),
      ),
      onChanged: onChanged,
      validator: required
          ? (v) {
              if (v == null || v.isEmpty) return 'Requis';
              final val = int.tryParse(v);
              if (val == null || val < 0) return 'Invalide';
              return null;
            }
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Section photo
// ---------------------------------------------------------------------------

class RecipeFormPhotoSection extends StatelessWidget {
  const RecipeFormPhotoSection({
    required this.photoPath,
    required this.isLoading,
    required this.onTap,
    super.key,
  });

  final String? photoPath;
  final bool isLoading;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async => onTap(),
      child: photoPath != null
          ? Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 120,
                      maxHeight: 300,
                    ),
                    child: RecipePhotoWidget(
                      photoUrl: photoPath,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      fallbackIcon: Icons.broken_image_outlined,
                      fallbackIconSize: 40,
                    ),
                  ),
                ),
                const Positioned(
                  bottom: 8,
                  right: 8,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.black54,
                    child: Icon(
                      Icons.edit,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            )
          : Container(
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_a_photo_outlined,
                          size: 40,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ajouter une photo',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Modèle d'une ligne ingrédient
// ---------------------------------------------------------------------------

class RecipeIngredientRow {
  RecipeIngredientRow()
      : nameController = TextEditingController(),
        quantityController = TextEditingController(),
        unitController = TextEditingController(),
        sectionController = TextEditingController();

  RecipeIngredientRow.fromValues({
    required String name,
    required String quantity,
    required String unit,
    required String section,
  })  : nameController = TextEditingController(text: name),
        quantityController = TextEditingController(text: quantity),
        unitController = TextEditingController(text: unit),
        sectionController = TextEditingController(text: section);

  final TextEditingController nameController;
  final TextEditingController quantityController;
  final TextEditingController unitController;
  final TextEditingController sectionController;

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();
    sectionController.dispose();
  }
}

// ---------------------------------------------------------------------------
// Widget d'une ligne ingrédient
// ---------------------------------------------------------------------------

class RecipeIngredientRowWidget extends StatelessWidget {
  const RecipeIngredientRowWidget({
    required this.row,
    required this.onRemove,
    super.key,
  });

  final RecipeIngredientRow row;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: TextFormField(
              controller: row.quantityController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: 'Qté',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 64,
            child: TextFormField(
              controller: row.unitController,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: 'Unité',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextFormField(
              controller: row.nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: "Nom de l'ingrédient *",
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 80,
            child: TextFormField(
              controller: row.sectionController,
              decoration: const InputDecoration(
                hintText: 'Rayon',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.textSecondary,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
