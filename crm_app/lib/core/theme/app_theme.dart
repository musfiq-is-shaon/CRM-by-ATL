import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'design_tokens.dart';

/// Material 3 / Material You — [ColorScheme.fromSeed], Android 12+ dynamic color,
/// Google Sans typography, tonal surfaces, [NavigationBar] & [FilledButton] defaults.
class AppTheme {
  AppTheme._();

  static ThemeData light(Color accent, [ColorScheme? dynamicLight]) =>
      _theme(_colorScheme(accent, Brightness.light, dynamicLight));

  /// [amoledBlack]: true black scaffold/nav in dark mode (OLED).
  static ThemeData dark(
    Color accent,
    ColorScheme? dynamicDark, {
    bool amoledBlack = false,
  }) =>
      _theme(
        _colorScheme(accent, Brightness.dark, dynamicDark),
        amoledBlack: amoledBlack,
      );

  static ColorScheme _colorScheme(
    Color accent,
    Brightness brightness,
    ColorScheme? dynamicScheme,
  ) {
    final seed = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );

    if (dynamicScheme == null) {
      return seed
          .copyWith(
            primary: accent,
            onPrimary: AppColors.onAccent(accent),
          )
          .harmonized();
    }

    return dynamicScheme
        .copyWith(
          primary: accent,
          onPrimary: AppColors.onAccent(accent),
        )
        .harmonized();
  }

  static ThemeData _theme(ColorScheme cs, {bool amoledBlack = false}) {
    final isDark = cs.brightness == Brightness.dark;
    final scaffoldBg =
        (isDark && amoledBlack) ? Colors.black : cs.surface;

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: scaffoldBg,
      splashFactory: InkRipple.splashFactory,
      splashColor: cs.primary.withOpacity(isDark ? 0.12 : 0.08),
      highlightColor: cs.primary.withOpacity(isDark ? 0.06 : 0.04),
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );

    final textTheme = GoogleFonts.googleSansTextTheme(base.textTheme).apply(
      bodyColor: cs.onSurface,
      displayColor: cs.onSurface,
    );

    final primaryText =
        GoogleFonts.googleSansTextTheme(base.primaryTextTheme).apply(
      bodyColor: cs.onPrimary,
      displayColor: cs.onPrimary,
    );

    TextStyle gSans({
      double? fontSize,
      FontWeight? fontWeight,
      Color? color,
      double? height,
    }) =>
        GoogleFonts.googleSans(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: height,
        );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: primaryText,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: scaffoldBg,
        foregroundColor: cs.onSurface,
        surfaceTintColor: amoledBlack ? Colors.transparent : cs.surfaceTint,
        titleTextStyle: gSans(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
        iconTheme: IconThemeData(color: cs.onSurface),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: scaffoldBg,
                systemNavigationBarIconBrightness: Brightness.light,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: scaffoldBg,
                systemNavigationBarIconBrightness: Brightness.dark,
              ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        elevation: amoledBlack ? 0 : 1,
        shadowColor: Colors.transparent,
        backgroundColor: scaffoldBg,
        surfaceTintColor: amoledBlack ? Colors.transparent : cs.surfaceTint,
        indicatorColor: cs.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: cs.onPrimaryContainer, size: 24);
          }
          return IconThemeData(color: cs.onSurfaceVariant, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final style = gSans(fontSize: 12, fontWeight: FontWeight.w500);
          if (states.contains(WidgetState.selected)) {
            return style.copyWith(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            );
          }
          return style.copyWith(color: cs.onSurfaceVariant);
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scaffoldBg,
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: gSans(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: gSans(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      cardTheme: CardThemeData(
        color: cs.surfaceContainerLow,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: cs.surfaceTint,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: gSans(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: gSans(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm + 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          side: BorderSide(color: cs.outline),
          textStyle: gSans(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          textStyle: gSans(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: cs.outline.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: cs.outline.withOpacity(0.45)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: cs.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: cs.error, width: 2),
        ),
        labelStyle: gSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: cs.onSurfaceVariant,
        ),
        hintStyle: gSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant.withOpacity(0.72),
        ),
        floatingLabelStyle: gSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: cs.primary,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surfaceContainerHigh,
        elevation: 0,
        surfaceTintColor: cs.surfaceTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: gSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
        contentTextStyle: gSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surfaceContainerHigh,
        elevation: 0,
        surfaceTintColor: cs.surfaceTint,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        dragHandleColor: cs.onSurfaceVariant.withOpacity(0.35),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.inverseSurface,
        contentTextStyle: gSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: cs.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return cs.onPrimary;
          return cs.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return cs.primary.withOpacity(0.35);
          }
          return cs.surfaceContainerHighest;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        circularTrackColor: cs.primary.withOpacity(0.2),
      ),
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant.withOpacity(0.45),
        thickness: 1,
        space: 1,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: cs.primary,
        textColor: cs.onSurface,
        titleTextStyle: gSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
        subtitleTextStyle: gSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: cs.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            gSans(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
