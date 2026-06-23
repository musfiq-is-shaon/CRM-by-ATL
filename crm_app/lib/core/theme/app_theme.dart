import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'design_tokens.dart';

/// Material 3 / Material You — [ColorScheme.fromSeed], Android 12+ dynamic color,
/// Google Sans typography, tonal surfaces, [NavigationBar] & [FilledButton] defaults.
class AppTheme {
  AppTheme._();

  static ThemeData light(Color accent, [ColorScheme? _]) =>
      _theme(_colorScheme(accent, Brightness.light));

  /// [amoledBlack]: true black scaffold/nav in dark mode (OLED).
  static ThemeData dark(
    Color accent,
    ColorScheme? _, {
    bool amoledBlack = false,
  }) => _theme(_colorScheme(accent, Brightness.dark), amoledBlack: amoledBlack);

  /// Full Material 3 tonal roles from [accent] only.
  ///
  /// We intentionally **do not** blend Android 12+ wallpaper colors into
  /// this scheme: mixing wallpaper [ColorScheme] with a user-chosen accent
  /// left **secondary**, **tertiary**, and **Container** roles tied to the
  /// wallpaper while **primary** followed the accent — inconsistent across
  /// the app. [DynamicColorBuilder] is still used so we can opt into
  /// wallpaper neutrals later if needed.
  static ColorScheme _colorScheme(Color accent, Brightness brightness) {
    final seed = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );

    return seed
        .copyWith(primary: accent, onPrimary: AppColors.onAccent(accent))
        .harmonized();
  }

  static ThemeData _theme(ColorScheme cs, {bool amoledBlack = false}) {
    final isDark = cs.brightness == Brightness.dark;
    final scaffoldBg = (isDark && amoledBlack) ? Colors.black : cs.surface;

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: scaffoldBg,
      splashFactory: InkRipple.splashFactory,
      splashColor: cs.primary.withValues(alpha: isDark ? 0.12 : 0.08),
      highlightColor: cs.primary.withValues(alpha: isDark ? 0.06 : 0.04),
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );

    final textTheme = GoogleFonts.googleSansTextTheme(
      base.textTheme,
    ).apply(bodyColor: cs.onSurface, displayColor: cs.onSurface);

    final primaryText = GoogleFonts.googleSansTextTheme(
      base.primaryTextTheme,
    ).apply(bodyColor: cs.onPrimary, displayColor: cs.onPrimary);

    TextStyle gSans({
      double? fontSize,
      FontWeight? fontWeight,
      Color? color,
      double? height,
    }) => GoogleFonts.googleSans(
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
        // Primary-tinted pill reads clearly on light surfaces and on OLED black.
        indicatorColor: cs.primary.withValues(alpha: isDark ? 0.24 : 0.14),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: cs.primary, size: 24);
          }
          return IconThemeData(
            color: cs.onSurface.withValues(alpha: isDark ? 0.72 : 0.58),
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final style = gSans(fontSize: 12, fontWeight: FontWeight.w500);
          if (states.contains(WidgetState.selected)) {
            return style.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w600,
            );
          }
          return style.copyWith(
            color: cs.onSurface.withValues(alpha: isDark ? 0.78 : 0.62),
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scaffoldBg,
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurface.withValues(
          alpha: isDark ? 0.72 : 0.58,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: gSans(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: gSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: cs.onSurface.withValues(alpha: isDark ? 0.78 : 0.62),
        ),
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
          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.45)),
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
          color: cs.onSurfaceVariant.withValues(alpha: 0.72),
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
        dragHandleColor: cs.onSurfaceVariant.withValues(alpha: 0.35),
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
            return cs.primary.withValues(alpha: 0.35);
          }
          return cs.surfaceContainerHighest;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        circularTrackColor: cs.primary.withValues(alpha: 0.2),
      ),
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant.withValues(alpha: 0.45),
        thickness: 1,
        space: 1,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerHigh,
        deleteIconColor: cs.onSurfaceVariant,
        labelStyle: gSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: cs.onSurface,
        ),
        secondaryLabelStyle: gSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: cs.onSurfaceVariant,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.55)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
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
