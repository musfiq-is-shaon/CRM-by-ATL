import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'color_scheme_semantics.dart';

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

  // --- Layout (matches [AppSpacing] semantic tokens) ---

  /// Standard horizontal inset for page content (lists, forms).
  static const EdgeInsets pagePaddingHorizontal = EdgeInsets.symmetric(
    horizontal: AppSpacing.pagePadding,
  );

  /// Standard padding on all sides for scrollable page bodies.
  static const EdgeInsets pagePaddingAll = EdgeInsets.all(AppSpacing.pagePadding);

  /// Top block under an app bar (horizontal page padding, top sm).
  static const EdgeInsets pagePaddingTop = EdgeInsets.fromLTRB(
    AppSpacing.pagePadding,
    AppSpacing.sm,
    AppSpacing.pagePadding,
    0,
  );

  // --- Page rhythm ---

  /// Vertical gap between stacked sections/cards on scroll pages.
  static const double sectionGap = AppSpacing.sectionGap;

  /// Label above a grouped card section (e.g. “Management”).
  static const EdgeInsets sectionHeaderLabelPadding = EdgeInsets.only(
    left: AppSpacing.xs,
    bottom: AppSpacing.sm,
  );

  /// Standard list body under an app bar (horizontal + top + bottom inset).
  static const EdgeInsets listPagePadding = EdgeInsets.fromLTRB(
    AppSpacing.pagePadding,
    AppSpacing.sm,
    AppSpacing.pagePadding,
    AppSpacing.pagePadding,
  );

  /// Search / filter row above a list (aligned with [listPagePadding] horizontal).
  static const EdgeInsets listHeaderPadding = EdgeInsets.fromLTRB(
    AppSpacing.pagePadding,
    AppSpacing.md,
    AppSpacing.pagePadding,
    AppSpacing.sm,
  );

  /// Tight top under app bar (secondary toolbar / compact header).
  static const EdgeInsets listPagePaddingTightTop = EdgeInsets.fromLTRB(
    AppSpacing.pagePadding,
    AppSpacing.sm,
    AppSpacing.pagePadding,
    0,
  );

  /// When a FAB overlaps scroll content.
  static const EdgeInsets listPagePaddingFab = EdgeInsets.fromLTRB(
    AppSpacing.pagePadding,
    AppSpacing.sm,
    AppSpacing.pagePadding,
    88,
  );

  /// Rows inside card-style lists (menu tiles, timing options).
  static const EdgeInsets cardRowPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.pagePadding,
    vertical: AppSpacing.md,
  );

  /// Inset for info blocks inside a card.
  static const EdgeInsets cardInsetPadding = EdgeInsets.all(AppSpacing.cardPadding);

  /// Default padding for [AppSearchFilterBar].
  static const EdgeInsets searchFilterBarPadding = EdgeInsets.fromLTRB(
    AppSpacing.pagePadding,
    AppSpacing.sm,
    AppSpacing.pagePadding,
    AppSpacing.sm,
  );

  /// Standard gap between stacked [CRMCard] rows in lists.
  static const EdgeInsets cardListItemMargin = EdgeInsets.only(
    bottom: AppSpacing.listItemGap,
  );

  /// Vertical gap between form fields / sections on scroll pages.
  static const double fieldGap = AppSpacing.formFieldGap;
  static const double sectionSpacing = AppSpacing.sectionGap;
  static const double cardGap = AppSpacing.listItemGap;

  /// Auth / welcome screens — slightly more inset than standard lists.
  static const EdgeInsets pagePaddingLoose = EdgeInsets.all(AppSpacing.xl);

  /// Horizontal page gutters with a small bottom inset (dashboard strips).
  static const EdgeInsets pagePaddingHorizontalBottomXs = EdgeInsets.fromLTRB(
    AppSpacing.pagePadding,
    0,
    AppSpacing.pagePadding,
    AppSpacing.sm,
  );

  static const EdgeInsets pagePaddingHorizontalBottomTight = EdgeInsets.fromLTRB(
    AppSpacing.pagePadding,
    0,
    AppSpacing.pagePadding,
    AppSpacing.xs,
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
      title: Text(
        title,
        style: AppTypography.screenTitle(context),
      ),
      actions: actions,
      bottom: bottom,
    );
  }

  /// Semantic error text / snackbar tint from the active theme.
  static Color errorForeground(BuildContext context) {
    return Theme.of(context).colorScheme.error;
  }

  static Color successForeground(BuildContext context) =>
      Theme.of(context).colorScheme.success;

  static Color warningForeground(BuildContext context) =>
      Theme.of(context).colorScheme.warning;

  static Color infoForeground(BuildContext context) =>
      Theme.of(context).colorScheme.info;

  static ({Color background, Color foreground}) semanticTone(
    BuildContext context,
    SemanticTone tone,
  ) =>
      Theme.of(context).colorScheme.semanticPair(tone);

  /// Premium hero strip behind dashboard / auth headers.
  static BoxDecoration heroSurface(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          cs.primary.withValues(alpha: isDark ? 0.18 : 0.10),
          cs.surface.withValues(alpha: 0),
        ],
      ),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(
        color: cs.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.55),
      ),
    );
  }

  /// Icon chip used in menus, quick actions, and KPI cards.
  static Widget iconChip(
    BuildContext context, {
    required IconData icon,
    required Color accent,
    double size = AppSizes.iconChip,
    double iconSize = AppSizes.iconChipIcon,
  }) {
    final tonal = tonalForAccent(context, accent);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tonal.background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(icon, size: iconSize, color: tonal.foreground),
    );
  }
}
