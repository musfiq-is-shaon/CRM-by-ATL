import 'package:flutter/material.dart';

/// Theme-aware colors — always derived from [ThemeData] / [ColorScheme].
class AppThemeColors {
  static Color backgroundColor(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  /// App bars, sheets — matches scaffold (including AMOLED black).
  static Color surfaceColor(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  static Color cardColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Theme.of(context).brightness == Brightness.dark
        ? cs.surfaceContainerHigh
        : cs.surface;
  }

  static Color textPrimaryColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  static Color textSecondaryColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  static Color textTertiaryColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Color.alphaBlend(
      cs.onSurface.withOpacity(0.38),
      Theme.of(context).scaffoldBackgroundColor,
    );
  }

  static Color borderColor(BuildContext context) {
    return Theme.of(context).colorScheme.outlineVariant;
  }

  static Color dividerColor(BuildContext context) {
    return Theme.of(context).colorScheme.outline.withOpacity(0.35);
  }

  static Color expenseUnpaidColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFE8A82E)
        : const Color(0xFFD9A23A);
  }

  static Color expensePaidColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF3EC995)
        : const Color(0xFF34A37C);
  }

  static Color expenseUnpaidBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A1F08)
        : const Color(0xFFFFF7E8);
  }

  static Color expensePaidBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF082A1F)
        : const Color(0xFFE8F8F0);
  }
}
