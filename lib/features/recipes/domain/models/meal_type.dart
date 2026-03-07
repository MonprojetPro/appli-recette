import 'package:flutter/material.dart';

/// Types de repas disponibles avec leurs libellés et icônes.
enum MealType {
  breakfast('breakfast', 'Petit-déjeuner', Icons.free_breakfast_outlined),
  lunch('lunch', 'Déjeuner', Icons.lunch_dining_outlined),
  dinner('dinner', 'Dîner', Icons.dinner_dining_outlined),
  both('both', 'Déjeuner + Dîner', Icons.restaurant_outlined),
  snack('snack', 'Goûter', Icons.cookie_outlined),
  dessert('dessert', 'Dessert', Icons.cake_outlined);

  const MealType(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;

  /// Résout un MealType depuis sa valeur string, ou null si invalide.
  static MealType? tryFromValue(String value) {
    for (final type in MealType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}
