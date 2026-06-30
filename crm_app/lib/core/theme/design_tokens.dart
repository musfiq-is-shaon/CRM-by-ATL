import 'package:flutter/material.dart';

/// Spacing scale — use semantic tokens ([pagePadding], [cardPadding], etc.) in UI code.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double sectionGap = 28;

  /// Standard horizontal/vertical page gutter (16).
  static const double pagePadding = lg;

  /// Inner padding for [CRMCard] and grouped panels (16).
  static const double cardPadding = lg;

  /// Vertical gap between form fields (16).
  static const double formFieldGap = lg;

  /// Gap between stacked list cards (12).
  static const double listItemGap = md;

  /// Legacy alias — same as [xs].
  static const double xxs = xs;
}

/// Corner radii — prefer [md] for inputs/buttons, [lg] for cards.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;

  static const double small = sm;
  static const double medium = md;
  static const double large = lg;
  static const double extraLarge = xl;
  static const double full = pill;
}

/// Fixed component heights for consistent tap targets and row alignment.
abstract final class AppSizes {
  static const double buttonHeight = 48;
  static const double buttonHeightLarge = 52;
  static const double buttonHeightSmall = 40;
  static const double textFieldHeight = 52;
  static const double searchBarHeight = 48;
  static const double chipHeight = 34;
  static const double navBarHeight = 80;
  static const double iconChip = 40;
  static const double iconChipIcon = 20;
  static const double avatarDefault = 40;
  static const double emptyStateIcon = 40;
  static const double emptyStateIconBox = 72;
}

/// Material 3–style depth: minimal shadow; prefer tonal surfaces in theme.
abstract final class AppElevation {
  static const List<BoxShadow> cardLight = [
    BoxShadow(
      color: Color(0x050F172A),
      blurRadius: 12,
      offset: Offset(0, 4),
      spreadRadius: -2,
    ),
  ];

  static const List<BoxShadow> navLight = [
    BoxShadow(
      color: Color(0x040F172A),
      blurRadius: 8,
      offset: Offset(0, -2),
      spreadRadius: -2,
    ),
  ];

  static List<BoxShadow> cardDark(Color accent) => [
    BoxShadow(
      color: accent.withValues(alpha: 0.08),
      blurRadius: 14,
      offset: const Offset(0, 4),
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 10,
      offset: const Offset(0, 6),
      spreadRadius: -2,
    ),
  ];

  static const List<BoxShadow> navDark = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 12,
      offset: Offset(0, -2),
      spreadRadius: -2,
    ),
  ];

  static const List<BoxShadow> fabGlow = [
    BoxShadow(color: Color(0x28000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
}

/// Subtle motion — keep durations short for a responsive CRM feel.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;
}

/// Typography scale — always derive colors from [Theme.of(context)] at call site.
abstract final class AppTypography {
  static const double pageTitleSize = 26;
  static const double screenTitleSize = 22;
  static const double sectionTitleSize = 17;
  static const double cardTitleSize = 15;
  static const double bodySize = 14;
  static const double bodySmallSize = 13;
  static const double captionSize = 12;
  static const double buttonSize = 14;
  static const double inputSize = 15;
  static const double kpiNumberSize = 26;
  static const double kpiLabelSize = 12;

  static TextStyle? pageTitle(BuildContext context) =>
      Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontSize: pageTitleSize,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: Theme.of(context).colorScheme.onSurface,
          );

  static TextStyle? screenTitle(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: screenTitleSize,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          );

  static TextStyle? sectionTitle(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: sectionTitleSize,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          );

  static TextStyle? cardTitle(BuildContext context) =>
      Theme.of(context).textTheme.titleSmall?.copyWith(
            fontSize: cardTitleSize,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          );

  static TextStyle? body(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: bodySize,
            fontWeight: FontWeight.w400,
            color: Theme.of(context).colorScheme.onSurface,
          );

  static TextStyle? bodySmall(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: bodySmallSize,
            fontWeight: FontWeight.w400,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          );

  static TextStyle? label(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium?.copyWith(
            fontSize: bodySmallSize,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          );

  static TextStyle? caption(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: captionSize,
            fontWeight: FontWeight.w400,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          );

  static TextStyle? button(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: buttonSize,
            fontWeight: FontWeight.w600,
          );

  static TextStyle? input(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: inputSize,
            fontWeight: FontWeight.w400,
            color: Theme.of(context).colorScheme.onSurface,
          );

  static TextStyle? helper(BuildContext context) =>
      caption(context);

  static TextStyle? error(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: captionSize,
            fontWeight: FontWeight.w400,
            color: Theme.of(context).colorScheme.error,
          );

  static TextStyle? kpiNumber(BuildContext context) =>
      Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontSize: kpiNumberSize,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          );

  static TextStyle? kpiLabel(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: kpiLabelSize,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          );

  static TextStyle? labelCaps(BuildContext context, Color color) =>
      Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontSize: captionSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          );
}

/// Soft gradient overlays for hero / premium surfaces.
abstract final class AppGradients {
  static LinearGradient heroLight(Color accent) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      accent.withValues(alpha: 0.08),
      colorSchemeLightSurface.withValues(alpha: 0.0),
    ],
  );

  static LinearGradient heroDark(Color accent) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent.withValues(alpha: 0.12), const Color(0x00000000)],
  );

  static const Color colorSchemeLightSurface = Color(0xFFFFFFFF);
}
