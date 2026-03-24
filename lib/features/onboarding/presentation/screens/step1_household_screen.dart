import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/theme/app_colors.dart';
import 'package:appli_recette/features/household/presentation/providers/household_provider.dart';
import 'package:appli_recette/features/planning/presentation/providers/planning_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Étape 1 de l'onboarding : création du/des membres du foyer.
///
/// Le bouton Suivant est désactivé tant qu'aucun membre n'a été créé.
class Step1HouseholdScreen extends ConsumerStatefulWidget {
  const Step1HouseholdScreen({required this.onNext, super.key});

  final VoidCallback onNext;

  @override
  ConsumerState<Step1HouseholdScreen> createState() =>
      _Step1HouseholdScreenState();
}

class _Step1HouseholdScreenState extends ConsumerState<Step1HouseholdScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _ageController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _clearForm() {
    final oldName = _nameController;
    final oldAge = _ageController;
    setState(() {
      _nameController = TextEditingController();
      _ageController = TextEditingController();
    });
    _formKey.currentState?.reset();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldName.dispose();
      oldAge.dispose();
    });
  }

  Future<void> _addMember() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final ageText = _ageController.text.trim();
    final age = ageText.isNotEmpty ? int.tryParse(ageText) : null;

    // Couper la connexion IME Android AVANT le await,
    // sinon le clavier renvoie l'ancien texte et écrase le clear.
    FocusScope.of(context).unfocus();

    setState(() => _isAdding = true);
    try {
      final notifier = ref.read(householdNotifierProvider.notifier);
      final id = await notifier.addMember(name: name, age: age);

      // Vider le formulaire dès que le membre est ajouté
      if (mounted) _clearForm();

      // Initialiser le planning type pour ce nouveau membre
      await ref
          .read(planningNotifierProvider.notifier)
          .initializeForNewMember(id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final members = ref.watch(membersStreamProvider).value ?? [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Qui fait partie du foyer ?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoute au moins une personne pour commencer.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Formulaire d'ajout
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Prénom *',
                    hintText: 'Ex: Léa',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le prénom est requis';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Âge (optionnel)',
                    hintText: 'Ex: 32',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _addMember(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isAdding ? null : _addMember,
                    icon: _isAdding
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                    label: const Text('Ajouter au foyer'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Liste des membres déjà créés
          if (members.isNotEmpty) ...[
            Text(
              'Membres ajoutés',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: members.length,
                itemBuilder: (context, i) {
                  final m = members[i];
                  return _MemberChip(member: m);
                },
              ),
            ),
          ] else
            const Expanded(child: SizedBox.shrink()),

          const SizedBox(height: 16),

          // Bouton Suivant
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: members.isNotEmpty ? widget.onNext : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.disabled,
              ),
              child: const Text('Suivant →'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberChip extends ConsumerWidget {
  const _MemberChip({required this.member});
  final Member member;

  Future<void> _deleteMember(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce membre ?'),
        content: Text(
          'Supprimer ${member.name} du foyer ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(householdNotifierProvider.notifier)
          .deleteMember(member.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryLight,
          child: Text(
            member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(member.name),
        subtitle: member.age != null ? Text('${member.age} ans') : null,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          color: AppColors.error,
          tooltip: 'Supprimer',
          onPressed: () => _deleteMember(context, ref),
        ),
      ),
    );
  }
}
