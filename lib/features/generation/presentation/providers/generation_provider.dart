import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/database/database_provider.dart';
import 'package:appli_recette/core/household/household_providers.dart';
import 'package:appli_recette/features/generation/domain/models/generation_filters.dart';
import 'package:appli_recette/features/generation/domain/models/generation_input.dart';
import 'package:appli_recette/features/generation/domain/models/meal_slot_result.dart';
import 'package:appli_recette/features/generation/domain/services/generation_service.dart';
import 'package:appli_recette/features/generation/presentation/providers/menu_provider.dart';
import 'package:appli_recette/features/household/data/datasources/meal_rating_datasource.dart';
import 'package:appli_recette/features/household/presentation/providers/household_provider.dart';
import 'package:appli_recette/features/planning/data/utils/week_utils.dart';
import 'package:appli_recette/features/planning/presentation/providers/planning_provider.dart';
import 'package:appli_recette/features/recipes/presentation/providers/recipes_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Datasource pour les ratings globaux (ajouté à la datasource existante)
// ─────────────────────────────────────────────────────────────────────────────

final _mealRatingDatasourceProvider = Provider<MealRatingDatasource>((ref) {
  final db = ref.watch(databaseProvider);
  return MealRatingDatasource(db);
});

/// Stream de toutes les notations du foyer courant.
final allRatingsStreamProvider = StreamProvider<List<MealRating>>((ref) {
  final householdId = ref.watch(currentHouseholdIdProvider).value;
  if (householdId == null) return const Stream.empty();
  final members = ref.watch(membersStreamProvider).value ?? [];
  if (members.isEmpty) return const Stream.empty();
  final memberIds = members.map((m) => m.id).toList();
  return ref.watch(_mealRatingDatasourceProvider).watchForMembers(memberIds);
});

// ─────────────────────────────────────────────────────────────────────────────
// filtersProvider (Story 5.3)
// ─────────────────────────────────────────────────────────────────────────────

/// Notifier pour les filtres de génération.
class FiltersNotifier extends Notifier<GenerationFilters?> {
  @override
  GenerationFilters? build() => null; // Aucun filtre par défaut

  void update(GenerationFilters filters) => state = filters;
  void reset() => state = null;
}

final filtersProvider =
    NotifierProvider<FiltersNotifier, GenerationFilters?>(FiltersNotifier.new);

/// True si des filtres actifs sont en place.
final hasActiveFiltersProvider = Provider<bool>((ref) {
  final filters = ref.watch(filtersProvider);
  return filters != null && filters.hasActiveFilters;
});

// ─────────────────────────────────────────────────────────────────────────────
// État de la génération
// ─────────────────────────────────────────────────────────────────────────────

/// État complet du menu généré pour la semaine courante.
class GeneratedMenuState {
  const GeneratedMenuState({
    required this.slots,
    required this.weekKey,
    this.lockedSlotIndices = const {},
    this.isValidated = false,
  });

  /// 14 créneaux : index 0 = lundi-midi, 1 = lundi-soir, …, 13 = dimanche-soir.
  /// null = créneau non rempli.
  final List<MealSlotResult?> slots;

  /// Clé ISO 8601 de la semaine planifiée (ex: "2026-W09").
  final String weekKey;

  /// Indices des créneaux verrouillés (ignorés lors de la regénération).
  final Set<int> lockedSlotIndices;

  /// True si le menu a été validé et sauvegardé dans drift.
  final bool isValidated;

  /// Nombre de créneaux non remplis.
  int get emptySlotCount => slots.where((s) => s == null).length;

  /// True si au moins un créneau rempli n'est pas verrouillé.
  bool get hasUnlockedFilledSlots => slots.asMap().entries.any(
        (e) => e.value != null && !lockedSlotIndices.contains(e.key),
      );

  GeneratedMenuState copyWith({
    List<MealSlotResult?>? slots,
    String? weekKey,
    Set<int>? lockedSlotIndices,
    bool? isValidated,
  }) {
    return GeneratedMenuState(
      slots: slots ?? this.slots,
      weekKey: weekKey ?? this.weekKey,
      lockedSlotIndices: lockedSlotIndices ?? this.lockedSlotIndices,
      isValidated: isValidated ?? this.isValidated,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// generateMenuProvider — AsyncNotifierProvider principal (Stories 5.1-5.4)
// ─────────────────────────────────────────────────────────────────────────────

class GenerateMenuNotifier
    extends AsyncNotifier<GeneratedMenuState?> {
  @override
  Future<GeneratedMenuState?> build() async => null; // Pas de menu au démarrage

  /// Lance la génération pour la semaine courante.
  Future<void> generate(GenerationFilters? filters) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final weekKey = ref.read(selectedWeekKeyProvider);

      // Collecter les données depuis les providers existants
      // Utiliser .first sur les streams directs pour éviter un blocage
      // lorsque les StreamProviders ne sont pas actifs (non watchés).
      final householdId = ref.read(currentHouseholdIdProvider).value;
      if (householdId == null) throw Exception('Pas de foyer configuré');

      final recipes = await ref
          .read(recipeRepositoryProvider)
          .watchAll(householdId)
          .first;
      final members = await ref
          .read(householdRepositoryProvider)
          .watchAll(householdId)
          .first;
      final presences = await ref
          .read(planningRepositoryProvider)
          .watchMergedPresences(weekKey)
          .first;
      final memberIds = members.map((m) => m.id).toList();
      final ratings = memberIds.isEmpty
          ? <MealRating>[]
          : await ref
              .read(_mealRatingDatasourceProvider)
              .watchForMembers(memberIds)
              .first;
      // Chaque semaine est indépendante — pas de déduplication inter-semaines
      final input = GenerationInput(
        weekKey: weekKey,
        recipes: recipes,
        members: members,
        presences: presences,
        ratings: ratings,
        previousMenuSlots: const [],
        filters: filters,
      );

      final currentState = state.value;
      final lockedIndices = currentState?.lockedSlotIndices ?? {};

      // Collecter les recipeIds des slots verrouillés pour la déduplication
      final lockedRecipeIds = <String>{};
      if (currentState != null && lockedIndices.isNotEmpty) {
        for (final idx in lockedIndices) {
          final slot = currentState.slots[idx];
          if (slot != null && !slot.isSpecialEvent) {
            lockedRecipeIds.add(slot.recipeId);
          }
        }
      }

      final service = GenerationService();
      final slots = service.generateMenu(
        input,
        lockedSlotIndices: lockedIndices.isNotEmpty ? lockedIndices : null,
        lockedRecipeIds:
            lockedRecipeIds.isNotEmpty ? lockedRecipeIds : null,
      );

      // Si regénération partielle, conserver les slots verrouillés
      final mergedSlots = List<MealSlotResult?>.from(slots);
      if (currentState != null && lockedIndices.isNotEmpty) {
        for (final lockedIdx in lockedIndices) {
          mergedSlots[lockedIdx] = currentState.slots[lockedIdx];
        }
      }

      final result = GeneratedMenuState(
        slots: mergedSlots,
        weekKey: weekKey,
        lockedSlotIndices: lockedIndices,
      );

      // Auto-save en drift dès la génération
      await ref.read(menuHistoryNotifierProvider.notifier).save(
            weekKey: weekKey,
            slots: mergedSlots,
          );

      return result;
    });
  }

  /// Bascule le verrouillage d'un créneau (toggle).
  void toggleLock(int slotIndex) {
    final current = state.value;
    if (current == null) return;

    final newLocked = Set<int>.from(current.lockedSlotIndices);
    if (newLocked.contains(slotIndex)) {
      newLocked.remove(slotIndex);
    } else {
      newLocked.add(slotIndex);
    }
    state = AsyncValue.data(current.copyWith(lockedSlotIndices: newLocked));
  }

  /// Remplace le créneau [slotIndex] par la recette [recipeId].
  void replaceSlot(int slotIndex, String recipeId) {
    final current = state.value;
    if (current == null) return;

    final dayIndex = slotIndex ~/ 2;
    final mealType = slotIndex.isEven ? 'lunch' : 'dinner';

    final newSlots = List<MealSlotResult?>.from(current.slots);
    newSlots[slotIndex] = MealSlotResult(
      recipeId: recipeId,
      dayIndex: dayIndex,
      mealType: mealType,
    );
    state = AsyncValue.data(current.copyWith(slots: newSlots));
  }

  /// Vide le créneau [slotIndex] (null) et le déverrouille.
  void clearSlot(int slotIndex) {
    final current = state.value;
    if (current == null) return;

    final newSlots = List<MealSlotResult?>.from(current.slots);
    newSlots[slotIndex] = null;

    final newLocked = Set<int>.from(current.lockedSlotIndices)
      ..remove(slotIndex);
    state = AsyncValue.data(
      current.copyWith(slots: newSlots, lockedSlotIndices: newLocked),
    );
  }

  /// Marque le créneau [slotIndex] comme événement spécial (sans recette).
  void setSpecialEvent(int slotIndex, {String? label}) {
    final current = state.value;
    if (current == null) return;

    final dayIndex = slotIndex ~/ 2;
    final mealType = slotIndex.isEven ? 'lunch' : 'dinner';

    final newSlots = List<MealSlotResult?>.from(current.slots);
    newSlots[slotIndex] = MealSlotResult(
      recipeId: 'special_event',
      dayIndex: dayIndex,
      mealType: mealType,
      isSpecialEvent: true,
      eventLabel: label,
    );
    state = AsyncValue.data(current.copyWith(slots: newSlots));
  }

  /// Marque le menu comme validé (appelé après save dans menuHistoryNotifier).
  void markValidated() {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(isValidated: true));
  }

  /// Charge un état existant (depuis drift) pour permettre les interactions.
  void loadFromState(GeneratedMenuState menuState) {
    state = AsyncValue.data(menuState);
  }

  /// Réinitialise la génération.
  void reset() => state = const AsyncValue.data(null);
}

final generateMenuProvider =
    AsyncNotifierProvider<GenerateMenuNotifier, GeneratedMenuState?>(
  GenerateMenuNotifier.new,
);

// ─────────────────────────────────────────────────────────────────────────────
// Providers dérivés (Story 5.4)
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Validated Menu Display (historique semaines)
// ─────────────────────────────────────────────────────────────────────────────

/// Charge un menu validé depuis drift pour une semaine donnée et le convertit
/// en [GeneratedMenuState] read-only. Retourne null si aucun menu n'existe.
final validatedMenuDisplayProvider =
    FutureProvider.family<GeneratedMenuState?, String>((ref, weekKey) async {
  final menu = await ref.watch(menuForWeekProvider(weekKey).future);
  if (menu == null) return null;

  final slots =
      await ref.read(menuRepositoryProvider).getSlotsForMenu(menu.id);

  // Convertir les MenuSlot drift en liste de 14 MealSlotResult?
  final resultSlots = List<MealSlotResult?>.filled(14, null);
  for (final slot in slots) {
    // dayOfWeek: 1=lundi → index 0, mealSlot: lunch=even, dinner=odd
    final dayIndex = slot.dayOfWeek - 1;
    final slotIndex = dayIndex * 2 + (slot.mealSlot == 'dinner' ? 1 : 0);
    if (slotIndex >= 0 && slotIndex < 14) {
      resultSlots[slotIndex] = MealSlotResult(
        recipeId: slot.recipeId ?? '',
        dayIndex: dayIndex,
        mealType: slot.mealSlot,
      );
    }
  }

  return GeneratedMenuState(
    slots: resultSlots,
    weekKey: weekKey,
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// Providers dérivés (Story 5.4)
// ─────────────────────────────────────────────────────────────────────────────

/// True si le menu affiché a au moins un créneau rempli non verrouillé.
final hasUnlockedSlotsProvider = Provider<bool>((ref) {
  final state = ref.watch(generateMenuProvider).value;
  return state?.hasUnlockedFilledSlots ?? false;
});

/// Nombre de créneaux vides dans le menu généré.
final emptySlotCountProvider = Provider<int>((ref) {
  final state = ref.watch(generateMenuProvider).value;
  return state?.emptySlotCount ?? 0;
});
