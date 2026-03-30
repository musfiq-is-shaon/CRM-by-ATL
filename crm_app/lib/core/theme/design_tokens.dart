import 'package:flutter/material.dart';

/// 8px grid spacing scale.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
  static const double xxxl = 48;
}

/// Consistent corner radii (modern, slightly rounded).
abstract final class AppRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double full = 9999;
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
      color: accent.withOpacity(0.08),
      blurRadius: 14,
      offset: const Offset(0, 4),
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.35),
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

/// Soft gradient overlays for hero / premium surfaces.
abstract final class AppGradients {
  static LinearGradient heroLight(Color accent) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      accent.withOpacity(0.08),
      colorSchemeLightSurface.withOpacity(0.0),
    ],
  );

  static LinearGradient heroDark(Color accent) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent.withOpacity(0.12), const Color(0x00000000)],
  );

  static const Color colorSchemeLightSurface = Color(0xFFFFFFFF);
}
