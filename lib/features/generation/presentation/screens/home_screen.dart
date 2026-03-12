import 'package:appli_recette/core/auth/auth_providers.dart';
import 'package:appli_recette/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:appli_recette/core/constants/generation_constants.dart';
import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/household/household_providers.dart';
import 'package:appli_recette/core/household/invitation_service.dart';
import 'package:appli_recette/core/theme/app_colors.dart';
import 'package:appli_recette/core/widgets/sync_status_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:appli_recette/features/generation/presentation/providers/generation_provider.dart';
import 'package:appli_recette/features/generation/presentation/providers/menu_provider.dart';
import 'package:appli_recette/features/generation/presentation/widgets/generation_filters_sheet.dart';
import 'package:appli_recette/features/generation/presentation/widgets/incomplete_generation_card.dart';
import 'package:appli_recette/features/generation/presentation/widgets/meal_slot_bottom_sheet.dart';
import 'package:appli_recette/features/generation/presentation/widgets/recipe_picker_sheet.dart';
import 'package:appli_recette/features/generation/presentation/widgets/week_grid.dart';
import 'package:appli_recette/features/planning/data/utils/week_utils.dart';
import 'package:appli_recette/features/planning/presentation/providers/planning_provider.dart';
import 'package:appli_recette/features/planning/presentation/widgets/week_selector.dart';
import 'package:appli_recette/features/recipes/presentation/providers/recipes_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Écran d'accueil — affiche la grille semaine et le menu généré.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _cardDismissed = false;
  bool _highlightEmptySlots = false;

  @override
  Widget build(BuildContext context) {
    // Réinitialiser l'état local quand la semaine sélectionnée change
    ref.listen<String>(selectedWeekKeyProvider, (prev, next) {
      if (prev != next) {
        setState(() {
          _cardDismissed = false;
          _highlightEmptySlots = false;
        });
      }
    });

    final weekKey = ref.watch(selectedWeekKeyProvider);
    final isCurrentWeek = weekKey == currentWeekKey();
    final menuAsync = ref.watch(generateMenuProvider);
    final hasActiveFilters = ref.watch(hasActiveFiltersProvider);
    final recipesAsync = ref.watch(recipesStreamProvider);
    final canGenerate = ref.watch(canGenerateProvider);
    final recipeCount = ref.watch(recipeCountProvider);

    final recipes = recipesAsync.value ?? <Recipe>[];
    final recipesMap = <String, Recipe>{
      for (final r in recipes) r.id: r,
    };

    final dateRange = weekKeyToDateRange(weekKey);
    final title = _formatWeekTitle(dateRange.monday, dateRange.sunday);

    // Déterminer si la génération en cours correspond à cette semaine
    final generationState = menuAsync.value;
    final hasGenerationForWeek =
        generationState != null && generationState.weekKey == weekKey;

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/icon/logo_menufacile.png',
          height: 32,
        ),
        actions: [
          // Partager le code foyer
          Builder(
            builder: (context) {
              final code = ref.watch(householdCodeProvider).value;
              if (code == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Inviter au foyer',
                onPressed: () => ref
                    .read(invitationServiceProvider)
                    .shareInvitation(code),
              );
            },
          ),

          const SyncStatusBadge(),

          // Filtres de génération
          Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: 'Filtres',
                  onPressed: _openFiltersSheet,
                ),
                if (hasActiveFilters)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),

          // Déconnexion
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Se déconnecter',
            onPressed: () => _confirmSignOut(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Sélecteur de semaine ──
          const WeekSelector(),

          // ── Contenu principal ──
          Expanded(
            child: _buildContent(
              context: context,
              weekKey: weekKey,
              isCurrentWeek: isCurrentWeek,
              hasGenerationForWeek: hasGenerationForWeek,
              menuAsync: menuAsync,
              recipesMap: recipesMap,
              canGenerate: canGenerate,
              dateRange: dateRange,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Contenu principal — logique d'affichage selon la semaine
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildContent({
    required BuildContext context,
    required String weekKey,
    required bool isCurrentWeek,
    required bool hasGenerationForWeek,
    required AsyncValue<GeneratedMenuState?> menuAsync,
    required Map<String, Recipe> recipesMap,
    required bool canGenerate,
    required ({DateTime monday, DateTime sunday}) dateRange,
  }) {
    // Cas 1: Génération en cours / existante pour cette semaine
    if (hasGenerationForWeek) {
      return menuAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorState(context, canGenerate),
        data: (menuState) {
          if (menuState == null) {
            return _buildCurrentWeekEmpty(context, weekKey);
          }
          return _buildMenuView(
            context,
            menuState,
            recipesMap,
            weekKey,
            dateRange.monday,
          );
        },
      );
    }

    // Cas 2: Pas de génération en mémoire — vérifier menuAsync puis drift
    return menuAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildErrorState(context, canGenerate),
      data: (menuState) {
        if (menuState != null && menuState.weekKey == weekKey) {
          return _buildMenuView(
            context,
            menuState,
            recipesMap,
            weekKey,
            dateRange.monday,
          );
        }
        // Pas de génération en cours → vérifier historique drift
        return _buildValidatedMenuOrEmpty(
          context,
          weekKey,
          recipesMap,
          dateRange.monday,
          showGenerateHint: canGenerate,
        );
      },
    );
  }

  /// Charge un menu validé depuis drift ou affiche un état vide.
  Widget _buildValidatedMenuOrEmpty(
    BuildContext context,
    String weekKey,
    Map<String, Recipe> recipesMap,
    DateTime monday, {
    required bool showGenerateHint,
  }) {
    final validatedAsync = ref.watch(validatedMenuDisplayProvider(weekKey));

    return validatedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildEmptyState(context, showGenerateHint: false),
      data: (validatedMenu) {
        if (validatedMenu == null) {
          return _buildEmptyState(
            context,
            showGenerateHint: showGenerateHint,
          );
        }
        // Charger le menu drift dans generateMenuProvider pour
        // que les interactions (cadenas, events, etc.) fonctionnent
        final currentGen = ref.read(generateMenuProvider).value;
        if (currentGen == null || currentGen.weekKey != weekKey) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(generateMenuProvider.notifier).loadFromState(
                  validatedMenu,
                );
          });
        }
        return _buildMenuView(
          context,
          validatedMenu,
          recipesMap,
          weekKey,
          monday,
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // État vide
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCurrentWeekEmpty(BuildContext context, String weekKey) {
    // Semaine courante sans génération → vérifier s'il y a un menu validé
    final recipesAsync = ref.watch(recipesStreamProvider);
    final recipes = recipesAsync.value ?? <Recipe>[];
    final recipesMap = <String, Recipe>{
      for (final r in recipes) r.id: r,
    };
    final dateRange = weekKeyToDateRange(weekKey);
    final canGen = ref.watch(canGenerateProvider);
    return _buildValidatedMenuOrEmpty(
      context,
      weekKey,
      recipesMap,
      dateRange.monday,
      showGenerateHint: canGen,
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    bool showGenerateHint = true,
  }) {
    if (!showGenerateHint) {
      // Pas assez de recettes — afficher l'état unlock centré
      final count = ref.watch(recipeCountProvider);
      return _RecipeUnlockState(
        recipeCount: count,
        onAddRecipe: () => context.go('/recipes'),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Prêt à planifier tes repas ?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade500,
                    ),
                children: [
                  const TextSpan(text: 'Appuie sur '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Icon(
                      Icons.auto_awesome,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const TextSpan(text: ' en bas pour générer ton menu'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, bool canGenerate) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 8),
          Text(
            'Impossible de générer le menu.\nRéessaie dans un instant.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: canGenerate ? _generate : null,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Vue menu généré
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMenuView(
    BuildContext context,
    GeneratedMenuState menuState,
    Map<String, Recipe> recipesMap,
    String weekKey,
    DateTime monday,
  ) {
    final emptyCount = menuState.emptySlotCount;
    final showCard = !_cardDismissed && emptyCount > 0;

    return Column(
      children: [
        // ── Card génération incomplète (Story 5.6) ──
        if (showCard)
          IncompleteGenerationCard(
            emptySlotCount: emptyCount,
            onExpandFilters: _onExpandFilters,
            onCompleteManually: () {
              setState(() {
                _cardDismissed = true;
                _highlightEmptySlots = true;
              });
            },
            onLeaveEmpty: () => setState(() => _cardDismissed = true),
          ),

        // ── Grille semaine — toujours interactive ──
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: WeekGrid(
              slots: menuState.slots,
              recipesMap: recipesMap,
              monday: monday,
              isPostGeneration: true,
              lockedSlotIndices: menuState.lockedSlotIndices,
              highlightEmptySlots: _highlightEmptySlots,
              onSlotTap: (slotIndex) =>
                  _onSlotTap(slotIndex, menuState, recipesMap),
              onToggleLock: (slotIndex) => ref
                  .read(generateMenuProvider.notifier)
                  .toggleLock(slotIndex),
              onRefreshSlot: (slotIndex) =>
                  _onRefreshSlot(slotIndex, recipesMap.values.toList()),
              onDeleteSlot: (slotIndex) => ref
                  .read(generateMenuProvider.notifier)
                  .clearSlot(slotIndex),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _generate() async {
    setState(() {
      _cardDismissed = false;
      _highlightEmptySlots = false;
    });
    final filters = ref.read(filtersProvider);
    await ref.read(generateMenuProvider.notifier).generate(filters);
  }

  void _openFiltersSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => GenerationFiltersSheet(
        initialFilters: ref.read(filtersProvider),
        onApply: (newFilters) {
          ref.read(filtersProvider.notifier).update(newFilters);
        },
      ),
    );
  }

  void _onExpandFilters() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => GenerationFiltersSheet(
        initialFilters: ref.read(filtersProvider),
        onApply: (newFilters) {
          ref.read(filtersProvider.notifier).update(newFilters);
          setState(() {
            _cardDismissed = false;
            _highlightEmptySlots = false;
          });
          ref.read(generateMenuProvider.notifier).generate(newFilters);
        },
      ),
    );
  }

  void _onSlotTap(
    int slotIndex,
    GeneratedMenuState menuState,
    Map<String, Recipe> recipesMap,
  ) {
    final slot = menuState.slots[slotIndex];
    if (slot == null) {
      _onRefreshSlot(slotIndex, recipesMap.values.toList());
      return;
    }

    final recipe = recipesMap[slot.recipeId];
    if (recipe == null && !slot.isSpecialEvent) return;

    final isLocked = menuState.lockedSlotIndices.contains(slotIndex);

    showModalBottomSheet<void>(
      context: context,
      builder: (_) => MealSlotBottomSheet(
        recipeName: slot.isSpecialEvent
            ? (slot.eventLabel ?? 'Événement spécial')
            : recipe!.name,
        isLocked: isLocked,
        onViewRecipe: slot.isSpecialEvent
            ? null
            : () => context.push('/recipes/${slot.recipeId}'),
        onToggleLock: () => ref
            .read(generateMenuProvider.notifier)
            .toggleLock(slotIndex),
        onReplace: () => _onRefreshSlot(
          slotIndex,
          recipesMap.values.toList(),
        ),
        onSpecialEvent: () => _showEventLabelDialog(slotIndex),
        onDelete: () =>
            ref.read(generateMenuProvider.notifier).clearSlot(slotIndex),
      ),
    );
  }

  /// Tap sur un slot en mode read-only (menu validé) : juste voir la recette.
  void _onReadOnlySlotTap(
    int slotIndex,
    GeneratedMenuState menuState,
    Map<String, Recipe> recipesMap,
  ) {
    final slot = menuState.slots[slotIndex];
    if (slot == null || slot.isSpecialEvent) return;

    final recipe = recipesMap[slot.recipeId];
    if (recipe == null) return;

    context.push('/recipes/${slot.recipeId}');
  }

  void _onRefreshSlot(int slotIndex, List<dynamic> recipes) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RecipePickerSheet(
        recipes: recipes.cast(),
        onPick: (recipeId) => ref
            .read(generateMenuProvider.notifier)
            .replaceSlot(slotIndex, recipeId),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Vous serez redirigé vers l\'écran de connexion. '
          'Vos données locales seront conservées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final authService = ref.read(authServiceProvider);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('household_id');
    await ref.read(onboardingNotifierProvider.notifier).reset();
    ref.invalidate(currentHouseholdIdProvider);
    await authService.signOut();

    if (mounted) context.go('/login');
  }

  String _formatWeekTitle(DateTime monday, DateTime sunday) {
    final mDay = monday.day;
    final sDay = sunday.day;
    final mMonth = DateFormat.MMMM('fr_FR').format(monday);
    final sMonth = DateFormat.MMMM('fr_FR').format(sunday);
    if (monday.month == sunday.month) {
      return 'Semaine du $mDay au $sDay $mMonth';
    }
    return 'Semaine du $mDay $mMonth au $sDay $sMonth';
  }

  Future<void> _showEventLabelDialog(int slotIndex) async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nom de l\'événement'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'ex: Anniversaire, Restaurant…',
          ),
          onSubmitted: (_) =>
              Navigator.of(ctx).pop(controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || result == null) return;
    ref.read(generateMenuProvider.notifier).setSpecialEvent(
          slotIndex,
          label: result.isEmpty ? null : result,
        );
  }

  Future<void> _validateMenu(
    GeneratedMenuState menuState,
    String weekKey,
  ) async {
    await ref.read(menuHistoryNotifierProvider.notifier).save(
          weekKey: weekKey,
          slots: menuState.slots,
        );
    ref.read(generateMenuProvider.notifier).markValidated();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Menu sauvegardé ✓'),
        backgroundColor: Color(0xFF6BAE75),
        duration: Duration(seconds: 3),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// État centré — débloquage de la génération (pas assez de recettes)
// ─────────────────────────────────────────────────────────────────────────────

class _RecipeUnlockState extends StatelessWidget {
  const _RecipeUnlockState({
    required this.recipeCount,
    required this.onAddRecipe,
  });

  final int recipeCount;
  final VoidCallback onAddRecipe;
  static const _target = kMinRecipesForGeneration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = _target - recipeCount;
    final progress = (recipeCount / _target).clamp(0.0, 1.0);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.menu_book_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),

            // Titre
            Text(
              recipeCount == 0
                  ? 'Commence par tes recettes !'
                  : 'Encore $remaining recette${remaining > 1 ? 's' : ''} à ajouter',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Sous-titre
            Text(
              'Il faut au moins $_target recettes pour\ngénérer un menu hebdomadaire.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Barre de progression
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryLight.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progression',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '$recipeCount / $_target recettes',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.divider,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Bouton
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAddRecipe,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter des recettes'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
