import 'package:appli_recette/core/database/app_database.dart';
import 'package:appli_recette/core/theme/app_colors.dart';
import 'package:appli_recette/features/generation/domain/models/meal_slot_result.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Grille semaine verticale : 7 lignes (jours) x 2 colonnes (midi/soir).
class WeekGrid extends StatefulWidget {
  const WeekGrid({
    super.key,
    required this.slots,
    required this.recipesMap,
    required this.monday,
    this.isPostGeneration = false,
    this.isReadOnly = false,
    this.lockedSlotIndices = const {},
    this.highlightEmptySlots = false,
    this.onSlotTap,
    this.onToggleLock,
    this.onRefreshSlot,
    this.onDeleteSlot,
  });

  final List<MealSlotResult?> slots;
  final Map<String, Recipe> recipesMap;
  final DateTime monday;
  final bool isPostGeneration;
  final bool isReadOnly;
  final Set<int> lockedSlotIndices;
  final bool highlightEmptySlots;
  final void Function(int slotIndex)? onSlotTap;
  final void Function(int slotIndex)? onToggleLock;
  final void Function(int slotIndex)? onRefreshSlot;
  final void Function(int slotIndex)? onDeleteSlot;

  static const _days = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  @override
  State<WeekGrid> createState() => _WeekGridState();
}

class _WeekGridState extends State<WeekGrid> {
  final GlobalKey _todayKey = GlobalKey();

  /// Index du jour actuel dans la semaine (0=lundi..6=dimanche), ou -1.
  int get _todayIndex {
    final now = DateTime.now();
    for (var i = 0; i < 7; i++) {
      final date = widget.monday.add(Duration(days: i));
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        return i;
      }
    }
    return -1;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday());
  }

  @override
  void didUpdateWidget(covariant WeekGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.monday != widget.monday) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday());
    }
  }

  void _scrollToToday() {
    if (_todayKey.currentContext != null) {
      Scrollable.ensureVisible(
        _todayKey.currentContext!,
        alignment: 0.0,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayIdx = _todayIndex;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: 7,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, dayIndex) {
        final midiIndex = dayIndex * 2;
        final soirIndex = dayIndex * 2 + 1;
        final date = widget.monday.add(Duration(days: dayIndex));
        final dayLabel =
            '${WeekGrid._days[dayIndex]} ${date.day} ${DateFormat.MMMM('fr_FR').format(date)}';
        final isToday = dayIndex == todayIdx;
        return _DayRow(
          key: isToday ? _todayKey : null,
          dayLabel: dayLabel,
          isToday: isToday,
          midiSlot: _resolveSlot(midiIndex),
          soirSlot: _resolveSlot(soirIndex),
          midiLocked: widget.lockedSlotIndices.contains(midiIndex),
          soirLocked: widget.lockedSlotIndices.contains(soirIndex),
          highlightEmpty: widget.highlightEmptySlots,
          isPostGeneration: widget.isPostGeneration && !widget.isReadOnly,
          onMidiTap: () => widget.onSlotTap?.call(midiIndex),
          onSoirTap: () => widget.onSlotTap?.call(soirIndex),
          onMidiToggleLock: widget.onToggleLock != null
              ? () => widget.onToggleLock!.call(midiIndex)
              : null,
          onSoirToggleLock: widget.onToggleLock != null
              ? () => widget.onToggleLock!.call(soirIndex)
              : null,
        );
      },
    );
  }

  _SlotData _resolveSlot(int index) {
    final slot =
        widget.slots.length > index ? widget.slots[index] : null;
    if (slot == null) return const _SlotData.empty();
    if (slot.isSpecialEvent) {
      return _SlotData.specialEvent(eventLabel: slot.eventLabel);
    }
    final recipe = widget.recipesMap[slot.recipeId];
    return _SlotData(recipe: recipe);
  }
}

class _SlotData {
  const _SlotData({this.recipe, this.isSpecialEvent = false, this.eventLabel});
  const _SlotData.empty()
      : recipe = null,
        isSpecialEvent = false,
        eventLabel = null;
  const _SlotData.specialEvent({this.eventLabel})
      : recipe = null,
        isSpecialEvent = true;

  final Recipe? recipe;
  final bool isSpecialEvent;
  final String? eventLabel;
  bool get isEmpty => recipe == null && !isSpecialEvent;
}

/// Ligne d'un jour : label + 2 cartes (midi / soir).
class _DayRow extends StatelessWidget {
  const _DayRow({
    super.key,
    required this.dayLabel,
    required this.isToday,
    required this.midiSlot,
    required this.soirSlot,
    required this.midiLocked,
    required this.soirLocked,
    required this.highlightEmpty,
    required this.isPostGeneration,
    required this.onMidiTap,
    required this.onSoirTap,
    this.onMidiToggleLock,
    this.onSoirToggleLock,
  });

  final String dayLabel;
  final bool isToday;
  final _SlotData midiSlot;
  final _SlotData soirSlot;
  final bool midiLocked;
  final bool soirLocked;
  final bool highlightEmpty;
  final bool isPostGeneration;
  final VoidCallback onMidiTap;
  final VoidCallback onSoirTap;
  final VoidCallback? onMidiToggleLock;
  final VoidCallback? onSoirToggleLock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: isToday
          ? BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary,
                width: 2,
              ),
            )
          : null,
      padding: isToday
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 6)
          : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label du jour avec date
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              dayLabel,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          // Midi / Soir cote a cote
          Row(
            children: [
              Expanded(
                child: _MealCard(
                  label: 'Midi',
                  icon: Icons.wb_sunny_outlined,
                  slot: midiSlot,
                  isLocked: midiLocked,
                  highlightEmpty: highlightEmpty,
                  isPostGeneration: isPostGeneration,
                  onTap: onMidiTap,
                  onToggleLock: onMidiToggleLock,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MealCard(
                  label: 'Soir',
                  icon: Icons.nightlight_round_outlined,
                  slot: soirSlot,
                  isLocked: soirLocked,
                  highlightEmpty: highlightEmpty,
                  isPostGeneration: isPostGeneration,
                  onTap: onSoirTap,
                  onToggleLock: onSoirToggleLock,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Carte individuelle d'un creneau repas.
class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.label,
    required this.icon,
    required this.slot,
    required this.isLocked,
    required this.highlightEmpty,
    required this.isPostGeneration,
    required this.onTap,
    this.onToggleLock,
  });

  final String label;
  final IconData icon;
  final _SlotData slot;
  final bool isLocked;
  final bool highlightEmpty;
  final bool isPostGeneration;
  final VoidCallback onTap;
  final VoidCallback? onToggleLock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (slot.isSpecialEvent) {
      final displayLabel = slot.eventLabel ?? 'Événement';
      return _buildCard(
        context,
        color: AppColors.secondary.withValues(alpha: 0.12),
        borderColor: AppColors.secondary.withValues(alpha: 0.4),
        child: Row(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                displayLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onToggleLock != null)
              GestureDetector(
                onTap: onToggleLock,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    isLocked ? Icons.lock : Icons.lock_open_outlined,
                    size: 16,
                    color: isLocked
                        ? AppColors.primary
                        : Colors.grey.shade400,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (slot.isEmpty) {
      return _buildCard(
        context,
        color: Colors.grey.shade50,
        borderColor:
            highlightEmpty ? AppColors.primary : Colors.grey.shade200,
        borderWidth: highlightEmpty ? 2.0 : 1.0,
        isDashed: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 20,
              color: highlightEmpty
                  ? AppColors.primary
                  : Colors.grey.shade400,
            ),
            const SizedBox(height: 2),
            Text(
              'Ajouter',
              style: theme.textTheme.labelSmall?.copyWith(
                color: highlightEmpty
                    ? AppColors.primary
                    : Colors.grey.shade400,
                fontWeight:
                    highlightEmpty ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      );
    }

    final recipe = slot.recipe!;
    return _buildCard(
      context,
      color: isLocked
          ? AppColors.primary.withValues(alpha: 0.08)
          : Colors.white,
      borderColor: isLocked
          ? AppColors.primary
          : Colors.grey.shade200,
      borderWidth: isLocked ? 2.0 : 1.0,
      hasShadow: true,
      child: Row(
        children: [
          // Icone type de repas
          Icon(
            icon,
            size: 14,
            color: Colors.grey.shade400,
          ),
          const SizedBox(width: 6),
          if (recipe.isVegetarian)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Text('🌿', style: TextStyle(fontSize: 12)),
            ),
          // Nom recette
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (recipe.prepTimeMinutes > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${recipe.prepTimeMinutes} min',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade500,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Indicateurs
          if (recipe.isFavorite)
            const Padding(
              padding: EdgeInsets.only(left: 2),
              child: Text('⭐', style: TextStyle(fontSize: 12)),
            ),
          // Cadenas tappable
          if (onToggleLock != null && !slot.isEmpty)
            GestureDetector(
              onTap: onToggleLock,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  isLocked ? Icons.lock : Icons.lock_open_outlined,
                  size: 16,
                  color: isLocked
                      ? AppColors.primary
                      : Colors.grey.shade400,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required Color color,
    required Color borderColor,
    double borderWidth = 1.0,
    bool hasShadow = false,
    bool isDashed = false,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: borderWidth > 0
              ? Border.all(color: borderColor, width: borderWidth)
              : null,
          boxShadow: hasShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: child,
      ),
    );
  }
}
