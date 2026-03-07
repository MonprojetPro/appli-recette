import 'package:appli_recette/core/constants/generation_constants.dart';
import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/theme/app_colors.dart';
import 'package:appli_recette/core/widgets/sync_status_badge.dart';
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
          'assets/icon/logo_menuzen.png',
          height: 32,
        ),
        actions: [
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

          // Générer/Regénérer déplacé dans le FAB contextuel (AppShell)
        ],
      ),
      body: Column(
        children: [
          // ── Sélecteur de semaine ──
          const WeekSelector(),

          // ── Banner débloquage (Story 6.2) ──
          if (isCurrentWeek && !canGenerate)
            _GenerationUnlockBanner(recipeCount: recipeCount),

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
          showGenerateHint: true,
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
    return _buildValidatedMenuOrEmpty(
      context,
      weekKey,
      recipesMap,
      dateRange.monday,
      showGenerateHint: true,
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    bool showGenerateHint = true,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            showGenerateHint
                ? 'Tape Générer pour planifier ta semaine'
                : 'Aucun menu pour cette semaine',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
            textAlign: TextAlign.center,
          ),
        ],
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
// Widget banner — débloquage de la génération (Story 6.2)
// ─────────────────────────────────────────────────────────────────────────────

class _GenerationUnlockBanner extends StatelessWidget {
  const _GenerationUnlockBanner({required this.recipeCount});

  final int recipeCount;
  static const _target = kMinRecipesForGeneration;

  String get _message {
    final remaining = _target - recipeCount;
    if (recipeCount == 0) {
      return 'Commence par ajouter $_target recettes pour générer un menu';
    }
    if (remaining == 1) {
      return 'Plus qu\'1 recette avant de pouvoir générer !';
    }
    return 'Ajoute encore $remaining recettes pour générer un menu';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFFFF3E0),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$recipeCount/$_target',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
