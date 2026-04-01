import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Theme-aware colors — always derived from [ThemeData] / [ColorScheme].
///
/// Prefer [tonalForAccent] for icon chips / quick actions so primary, secondary,
/// and tertiary map to Material 3 tonal containers from the seed palette.
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
        : cs.surfaceContainerLow;
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
      cs.onSurface.withValues(alpha: 0.38),
      Theme.of(context).scaffoldBackgroundColor,
    );
  }

  static Color borderColor(BuildContext context) {
    return Theme.of(context).colorScheme.outlineVariant;
  }

  static Color dividerColor(BuildContext context) {
    return Theme.of(context).colorScheme.outline.withValues(alpha: 0.35);
  }

  /// Unpaid expense — secondary tonal (accent-aware).
  static Color expenseUnpaidColor(BuildContext context) {
    return Theme.of(context).colorScheme.secondary;
  }

  /// Paid expense — tertiary tonal (accent-aware).
  static Color expensePaidColor(BuildContext context) {
    return Theme.of(context).colorScheme.tertiary;
  }

  static Color expenseUnpaidBackgroundColor(BuildContext context) {
    return Theme.of(context).colorScheme.secondaryContainer;
  }

  static Color expensePaidBackgroundColor(BuildContext context) {
    return Theme.of(context).colorScheme.tertiaryContainer;
  }

  /// Maps a saturated accent ([ColorScheme.primary] / [secondary] / [tertiary])
  /// to the matching **tonal container** pair for icons, chips, and pills.
  static ({Color background, Color foreground}) tonalForAccent(
    BuildContext context,
    Color accent,
  ) {
    final cs = Theme.of(context).colorScheme;
    final key = accent.toARGB32();
    if (key == cs.primary.toARGB32()) {
      return (
        background: cs.primaryContainer,
        foreground: cs.onPrimaryContainer,
      );
    }
    if (key == cs.secondary.toARGB32()) {
      return (
        background: cs.secondaryContainer,
        foreground: cs.onSecondaryContainer,
      );
    }
    if (key == cs.tertiary.toARGB32()) {
      return (
        background: cs.tertiaryContainer,
        foreground: cs.onTertiaryContainer,
      );
    }
    return (
      background: Color.alphaBlend(
        accent.withValues(alpha: 0.14),
        cs.surface,
      ),
      foreground: accent,
    );
  }

  static Color surfaceContainerLow(BuildContext context) {
    return Theme.of(context).colorScheme.surfaceContainerLow;
  }

  static Color surfaceContainerHigh(BuildContext context) {
    return Theme.of(context).colorScheme.surfaceContainerHigh;
  }

  // --- Layout (8px grid, matches [AppSpacing]) ---

  /// Standard horizontal inset for page content (lists, forms).
  static const EdgeInsets pagePaddingHorizontal = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
  );

  /// Standard padding on all sides for scrollable page bodies.
  static const EdgeInsets pagePaddingAll = EdgeInsets.all(AppSpacing.md);

  /// Top block under an app bar (horizontal [md], top [sm]).
  static const EdgeInsets pagePaddingTop = EdgeInsets.fromLTRB(
    AppSpacing.md,
    AppSpacing.sm,
    AppSpacing.md,
    0,
  );

  // --- Page rhythm (matches Settings: 8px grid, compact sections) ---

  /// Vertical gap between stacked sections/cards on scroll pages.
  static const double sectionGap = AppSpacing.sm;

  /// Label above a grouped card section (e.g. “Management”).
  static const EdgeInsets sectionHeaderLabelPadding = EdgeInsets.only(
    left: AppSpacing.xxs,
    bottom: AppSpacing.xs,
  );

  /// Standard list body under an app bar (horizontal + top + bottom inset).
  static const EdgeInsets listPagePadding = EdgeInsets.fromLTRB(
    AppSpacing.md,
    AppSpacing.sm,
    AppSpacing.md,
    AppSpacing.md,
  );

  /// Search / filter row above a list (aligned with [listPagePadding] horizontal).
  static const EdgeInsets listHeaderPadding = EdgeInsets.fromLTRB(
    AppSpacing.md,
    AppSpacing.md,
    AppSpacing.md,
    AppSpacing.sm,
  );

  /// Tight top under app bar (secondary toolbar / compact header).
  static const EdgeInsets listPagePaddingTightTop = EdgeInsets.fromLTRB(
    AppSpacing.md,
    AppSpacing.xs,
    AppSpacing.md,
    0,
  );

  /// When a FAB overlaps scroll content.
  static const EdgeInsets listPagePaddingFab = EdgeInsets.fromLTRB(
    AppSpacing.md,
    AppSpacing.xs,
    AppSpacing.md,
    88,
  );

  /// Rows inside card-style lists (menu tiles, timing options).
  static const EdgeInsets cardRowPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.sm,
  );

  /// Inset for info blocks inside a card.
  static const EdgeInsets cardInsetPadding = EdgeInsets.all(AppSpacing.md);

  /// Default padding for [AppSearchFilterBar].
  static const EdgeInsets searchFilterBarPadding = EdgeInsets.fromLTRB(
    AppSpacing.md,
    AppSpacing.sm,
    AppSpacing.md,
    AppSpacing.xs,
  );

  /// Auth / welcome screens — slightly more inset than standard lists.
  static const EdgeInsets pagePaddingLoose = EdgeInsets.all(AppSpacing.lg);

  /// Horizontal page gutters with a small bottom inset (dashboard strips).
  static const EdgeInsets pagePaddingHorizontalBottomXs = EdgeInsets.fromLTRB(
    AppSpacing.md,
    0,
    AppSpacing.md,
    AppSpacing.xs,
  );

  static const EdgeInsets pagePaddingHorizontalBottomTight = EdgeInsets.fromLTRB(
    AppSpacing.md,
    0,
    AppSpacing.md,
    AppSpacing.xxs,
  );

  /// Consistent [AppBar] for inner routes (matches [AppTheme] app bar colors).
  static AppBar appBarTitle(
    BuildContext context,
    String title, {
    List<Widget>? actions,
    Widget? leading,
    PreferredSizeWidget? bottom,
  }) {
    final fg = textPrimaryColor(context);
    return AppBar(
      backgroundColor: surfaceColor(context),
      foregroundColor: fg,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: leading,
      title: Text(title),
      actions: actions,
      bottom: bottom,
    );
  }

  /// Semantic error text / snackbar tint from the active theme.
  static Color errorForeground(BuildContext context) {
    return Theme.of(context).colorScheme.error;
  }
}
