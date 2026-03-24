import 'package:appli_recette/core/household/household_providers.dart';
import 'package:appli_recette/core/router/app_router_notifier.dart';
import 'package:appli_recette/core/theme/app_colors.dart';
import 'package:appli_recette/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mode d'affichage de l'écran de configuration foyer.
enum _SetupMode { selection, create, join }

/// Écran de configuration foyer — créer ou rejoindre.
///
/// Parcours 1 (étape 6) : Créer un foyer.
/// Parcours 2 (étape 6) : Rejoindre un foyer avec code 6 chiffres.
class HouseholdSetupScreen extends ConsumerStatefulWidget {
  const HouseholdSetupScreen({this.initialCode, super.key});

  /// Code pré-rempli depuis un lien d'invitation (deep link).
  final String? initialCode;

  @override
  ConsumerState<HouseholdSetupScreen> createState() =>
      _HouseholdSetupScreenState();
}

class _HouseholdSetupScreenState extends ConsumerState<HouseholdSetupScreen> {
  _SetupMode _mode = _SetupMode.selection;
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String? _createdCode;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _codeController.text = widget.initialCode!;
      _mode = _SetupMode.join;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Écouter l'état de l'auto-join depuis le router notifier
    final autoJoinStatus =
        ref.watch(appRouterNotifierProvider).autoJoinStatus;

    if (autoJoinStatus == AutoJoinStatus.inProgress) {
      return _buildAutoJoinLoading(context);
    }

    if (autoJoinStatus == AutoJoinStatus.failed) {
      // Afficher le mode sélection avec un message d'erreur
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Connexion au foyer impossible. Vérifiez le code ou saisissez-le manuellement.',
              ),
              backgroundColor: AppColors.error,
              duration: Duration(seconds: 5),
            ),
          );
          ref.read(autoJoinStatusProvider.notifier).state = AutoJoinStatus.idle;
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: _buildContent(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (_mode) {
      case _SetupMode.selection:
        return _buildSelection(context);
      case _SetupMode.create:
        return _buildCreate(context);
      case _SetupMode.join:
        return _buildJoin(context);
    }
  }

  /// Écran de chargement pendant l'auto-join via lien d'invitation.
  Widget _buildAutoJoinLoading(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 3,
                ),
                const SizedBox(height: 32),
                Text(
                  'Connexion au foyer en cours…',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Nous rejoignons votre foyer automatiquement grâce au lien d\'invitation.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cela peut prendre quelques secondes…',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textHint,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Mode sélection ──────────────────────────────────────────────────

  Widget _buildSelection(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.home_outlined, size: 80, color: AppColors.primary),
        const SizedBox(height: 24),
        Text(
          'Configurez votre foyer',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Créez un nouveau foyer ou rejoignez '
          'celui d\'un proche avec un code.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 40),

        // Bouton Créer
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: () => setState(() => _mode = _SetupMode.create),
            icon: const Icon(Icons.add_home_outlined),
            label: const Text(
              'Créer un foyer',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Bouton Rejoindre
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _mode = _SetupMode.join),
            icon: const Icon(Icons.group_add_outlined),
            label: const Text(
              'Rejoindre un foyer',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Mode créer ──────────────────────────────────────────────────────

  Widget _buildCreate(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.add_home, size: 64, color: AppColors.primary),
        const SizedBox(height: 16),
        Text(
          'Créer un foyer',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 24),

        if (_createdCode != null) ...[
          // Code généré affiché
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.success),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 48,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Foyer créé !',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Partagez ce code avec vos proches :',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Text(
                  _createdCode!,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 10,
                    color: AppColors.primary,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _continueAfterCreate,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continuer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ] else ...[
          // Formulaire nom du foyer
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Nom du foyer',
              hintText: 'ex: Famille Dupont',
              prefixIcon: const Icon(
                Icons.edit_outlined,
                color: AppColors.textHint,
              ),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _isLoading ? null : _createHousehold,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Créer',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],

        const SizedBox(height: 16),
        if (_createdCode == null)
          TextButton(
            onPressed: () => setState(() {
              _mode = _SetupMode.selection;
              _error = null;
            }),
            child: const Text(
              'Retour',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }

  // ── Mode rejoindre ──────────────────────────────────────────────────

  Widget _buildJoin(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.group_add, size: 64, color: AppColors.primary),
        const SizedBox(height: 16),
        Text(
          'Rejoindre un foyer',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Saisissez le code à 6 chiffres partagé par '
          'un membre du foyer.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 24),

        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            hintStyle: TextStyle(
              color: AppColors.textHint.withOpacity(0.3),
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
              fontFamily: 'monospace',
            ),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppColors.error)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: _isLoading ? null : _joinHousehold,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Rejoindre',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() {
            _mode = _SetupMode.selection;
            _error = null;
          }),
          child: const Text(
            'Retour',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────

  Future<void> _createHousehold() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Saisissez un nom pour votre foyer');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(householdServiceProvider);
      final code = await service.createHousehold(name: name);

      // Après création de foyer → reset onboarding pour forcer le wizard
      await ref.read(onboardingNotifierProvider.notifier).reset();

      // Invalider le provider foyer pour que le router réévalue
      ref.invalidate(currentHouseholdIdProvider);

      if (!mounted) return;
      setState(() {
        _createdCode = code;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Erreur lors de la création. Réessayez.';
      });
    }
  }

  Future<void> _joinHousehold() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Le code doit contenir 6 chiffres');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(householdServiceProvider);
      await service.joinHousehold(code);

      // Rejoindre un foyer existant → skip onboarding (données déjà là)
      await ref.read(onboardingNotifierProvider.notifier).complete();

      // Invalider le provider foyer pour que le router réévalue
      ref.invalidate(currentHouseholdIdProvider);

      // Le router redirige automatiquement vers l'accueil
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _humanizeJoinError(e);
      });
    }
  }

  void _continueAfterCreate() {
    // Le router détecte que le foyer existe + onboarding = false
    // → redirige automatiquement vers /onboarding
    ref.invalidate(currentHouseholdIdProvider);
  }

  String _humanizeJoinError(Object e) {
    final msg = e.toString();
    if (msg.contains('HouseholdNotFoundException') ||
        msg.contains('not found')) {
      return 'Code invalide. Vérifiez avec le propriétaire du foyer.';
    }
    if (msg.contains('InvalidCodeFormat')) {
      return 'Le code doit contenir exactement 6 chiffres.';
    }
    return 'Erreur lors de la connexion au foyer. Réessayez.';
  }
}
