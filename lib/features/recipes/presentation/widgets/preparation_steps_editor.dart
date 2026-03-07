import 'package:appli_recette/core/theme/app_colors.dart';
import 'package:appli_recette/core/widgets/recipe_photo_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Modèle d'une étape en cours d'édition.
class StepEditorData {
  StepEditorData({
    String? instruction,
    List<String>? photoPaths,
  })  : instructionController =
            TextEditingController(text: instruction ?? ''),
        photoPaths = photoPaths ?? [];

  final TextEditingController instructionController;
  final List<String> photoPaths;

  void dispose() => instructionController.dispose();
}

/// Éditeur de liste d'étapes de préparation.
///
/// Gère l'ajout, la suppression, la réorganisation des étapes,
/// ainsi que la saisie de texte et l'ajout/suppression de photos par étape.
class PreparationStepsEditor extends ConsumerStatefulWidget {
  const PreparationStepsEditor({
    required this.steps,
    super.key,
  });

  /// Liste des étapes à éditer (modifiée en place).
  final List<StepEditorData> steps;

  @override
  ConsumerState<PreparationStepsEditor> createState() =>
      _PreparationStepsEditorState();
}

class _PreparationStepsEditorState
    extends ConsumerState<PreparationStepsEditor> {
  List<StepEditorData> get _steps => widget.steps;

  Future<void> _addPhoto(int stepIndex, ImageSource source) async {
    // Les photos d'étapes utilisent image_picker directement
    // pour obtenir un chemin/URL affichable (blob URL sur web, fichier local natif).
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: source, imageQuality: 85);
    if (xFile != null && mounted) {
      setState(() => _steps[stepIndex].photoPaths.add(xFile.path));
    }
  }

  Future<void> _showPhotoSourceSheet(int stepIndex) async {
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
                await _addPhoto(stepIndex, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir depuis la galerie'),
              onTap: () async {
                Navigator.of(ctx).pop();
                await _addPhoto(stepIndex, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _removePhoto(int stepIndex, int photoIndex) {
    setState(() => _steps[stepIndex].photoPaths.removeAt(photoIndex));
  }

  void _addStep() {
    setState(() => _steps.add(StepEditorData()));
  }

  void _removeStep(int index) {
    setState(() {
      _steps[index].dispose();
      _steps.removeAt(index);
    });
  }

  void _moveStep(int oldIndex, int newIndex) {
    setState(() {
      final adjustedIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
      final step = _steps.removeAt(oldIndex);
      _steps.insert(adjustedIndex, step);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_steps.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Aucune étape. Appuie sur + pour commencer.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: _steps.length,
            onReorder: _moveStep,
            itemBuilder: (context, i) {
              final step = _steps[i];
              return _StepEditorCard(
                key: ValueKey(step),
                index: i,
                step: step,
                onRemove: () => _removeStep(i),
                onAddPhoto: () => _showPhotoSourceSheet(i),
                onRemovePhoto: (photoIdx) => _removePhoto(i, photoIdx),
                onChanged: () => setState(() {}),
              );
            },
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _addStep,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter une étape'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Carte d'une étape individuelle
// ---------------------------------------------------------------------------

class _StepEditorCard extends StatelessWidget {
  const _StepEditorCard({
    required this.index,
    required this.step,
    required this.onRemove,
    required this.onAddPhoto,
    required this.onRemovePhoto,
    required this.onChanged,
    super.key,
  });

  final int index;
  final StepEditorData step;
  final VoidCallback onRemove;
  final VoidCallback onAddPhoto;
  final void Function(int) onRemovePhoto;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête : numéro + supprimer + handle réorganisation
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    '${index + 1}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Étape ${index + 1}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(
                      Icons.drag_handle,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: AppColors.textSecondary,
                  tooltip: 'Supprimer cette étape',
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Champ texte
            TextField(
              controller: step.instructionController,
              maxLines: 4,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText:
                    'Décris cette étape... (optionnel si tu ajoutes une photo)',
                alignLabelWithHint: true,
              ),
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: 8),

            // Photos existantes
            if (step.photoPaths.isNotEmpty) ...[
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: step.photoPaths.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, photoIdx) {
                    final path = step.photoPaths[photoIdx];
                    return Stack(
                      children: [
                        RecipePhotoWidget(
                          photoUrl: path,
                          width: 100,
                          height: 100,
                          borderRadius: BorderRadius.circular(8),
                          fallbackIcon: Icons.broken_image_outlined,
                          fallbackIconSize: 40,
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => onRemovePhoto(photoIdx),
                            child: const CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.black54,
                              child: Icon(
                                Icons.close,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Bouton ajouter photo
            TextButton.icon(
              onPressed: onAddPhoto,
              icon: const Icon(Icons.add_a_photo_outlined, size: 18),
              label: Text(
                step.photoPaths.isEmpty
                    ? 'Ajouter une photo'
                    : 'Ajouter une autre photo',
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
