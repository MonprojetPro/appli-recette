import 'package:appli_recette/core/household/household_providers.dart';
import 'package:appli_recette/core/household/household_service.dart';
import 'package:appli_recette/core/theme/app_colors.dart';
import 'package:appli_recette/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _SetupMode { selection, create, join }

/// Écran de création / jointure de foyer — Story 8.2.
///
/// Trois modes : sélection (défaut), création, jointure.
/// Le paramètre optionnel [initialCode] pré-remplit le champ code
/// lors d'un accès via un lien d'invitation (Story 8.3).
class HouseholdSetupScreen extends ConsumerStatefulWidget {
  const HouseholdSetupScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  ConsumerState<HouseholdSetupScreen> createState() =>
      _HouseholdSetupScreenState();
}

class _HouseholdSetupScreenState extends ConsumerState<HouseholdSetupScreen> {
  _SetupMode _mode = _SetupMode.selection;

  // Mode Créer
  final _createFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  // Mode Rejoindre
  final _joinFormKey = GlobalKey<FormState>();
  late final _codeController =
      TextEditingController(text: widget.initialCode ?? '');
  String _codeValue = '';

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _codeValue = widget.initialCode ?? '';
    _codeController.addListener(() {
      setState(() => _codeValue = _codeController.text);
    });

    if (widget.initialCode != null && widget.initialCode!.length == 6) {
      _mode = _SetupMode.join;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _createHousehold() async {
    if (!_createFormKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final service = ref.read(householdServiceProvider);
      final code = await service.createHousehold(name: _nameController.text.trim());
      if (mounted) {
        ref.invalidate(currentHouseholdIdProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Foyer créé — code : $code')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinHousehold() async {
    setState(() => _loading = true);
    try {
      final service = ref.read(householdServiceProvider);
      await service.joinHousehold(_codeValue);
      if (mounted) {
        // Marquer l'onboarding comme complété — le créateur du foyer
        // a déjà configuré les membres et préférences.
        await ref.read(onboardingNotifierProvider.notifier).complete();
        ref.invalidate(currentHouseholdIdProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foyer rejoint avec succès')),
        );
      }
    } on HouseholdNotFoundException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code invalide')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Text(
                'Configurer votre foyer',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Expanded(
                child: switch (_mode) {
                  _SetupMode.selection => _SelectionView(
                      onCreateTap: () =>
                          setState(() => _mode = _SetupMode.create),
                      onJoinTap: () =>
                          setState(() => _mode = _SetupMode.join),
                    ),
                  _SetupMode.create => _CreateView(
                      formKey: _createFormKey,
                      nameController: _nameController,
                      loading: _loading,
                      onSubmit: _createHousehold,
                      onBack: () => setState(() => _mode = _SetupMode.selection),
                    ),
                  _SetupMode.join => _JoinView(
                      formKey: _joinFormKey,
                      codeController: _codeController,
                      codeValue: _codeValue,
                      loading: _loading,
                      onSubmit: _joinHousehold,
                      onBack: () => setState(() => _mode = _SetupMode.selection),
                    ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sous-vues ────────────────────────────────────────────────────────────────

class _SelectionView extends StatelessWidget {
  const _SelectionView({
    required this.onCreateTap,
    required this.onJoinTap,
  });

  final VoidCallback onCreateTap;
  final VoidCallback onJoinTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _OptionCard(
          icon: Icons.add_home_outlined,
          label: 'Créer un foyer',
          description: 'Démarrez un nouveau foyer et invitez votre famille.',
          onTap: onCreateTap,
        ),
        const SizedBox(height: 16),
        _OptionCard(
          icon: Icons.group_add_outlined,
          label: 'Rejoindre un foyer',
          description: 'Entrez le code partagé par votre foyer.',
          onTap: onJoinTap,
        ),
        const SizedBox(height: 24),
        Text(
          'Synchronisez vos recettes et menus avec votre famille.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 40, color: AppColors.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateView extends StatelessWidget {
  const _CreateView({
    required this.formKey,
    required this.nameController,
    required this.loading,
    required this.onSubmit,
    required this.onBack,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final bool loading;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Nom du foyer',
              hintText: 'Ex : Famille Dupont',
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Entrez un nom' : null,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: loading ? null : onSubmit,
            child: loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Créer mon foyer'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: loading ? null : onBack,
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }
}

class _JoinView extends StatelessWidget {
  const _JoinView({
    required this.formKey,
    required this.codeController,
    required this.codeValue,
    required this.loading,
    required this.onSubmit,
    required this.onBack,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController codeController;
  final String codeValue;
  final bool loading;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final canSubmit = codeValue.length == 6 && !loading;

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: codeController,
            decoration: const InputDecoration(
              labelText: 'Code foyer (6 chiffres)',
              hintText: 'XXXXXX',
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: canSubmit ? onSubmit : null,
            child: loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Rejoindre le foyer'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: loading ? null : onBack,
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }
}
