import 'package:flutter/material.dart';

/// Semantic UI colors derived from the active [ColorScheme] (seed / dynamic accent).
extension ColorSchemeSemantics on ColorScheme {
  /// Background tint for a colored foreground (badge, chip, pill).
  Color tonalChipBackground(Color foreground) =>
      foreground.withValues(alpha: 0.12);

  Color get success => tertiary;

  Color get onSuccess => onTertiary;

  Color get successContainer => tertiaryContainer;

  Color get onSuccessContainer => onTertiaryContainer;

  Color get warning => secondary;

  Color get onWarning => onSecondary;

  Color get warningContainer => secondaryContainer;

  Color get onWarningContainer => onSecondaryContainer;

  Color get danger => error;

  Color get onDanger => onError;

  Color get dangerContainer => errorContainer;

  Color get onDangerContainer => onErrorContainer;

  Color get info => primary;

  Color get onInfo => onPrimary;

  Color get infoContainer => primaryContainer;

  Color get onInfoContainer => onPrimaryContainer;

  Color get neutral => onSurfaceVariant;

  Color get neutralContainer => surfaceContainerHighest;

  ({Color background, Color foreground}) semanticPair(SemanticTone tone) {
    switch (tone) {
      case SemanticTone.success:
        return (background: successContainer, foreground: onSuccessContainer);
      case SemanticTone.warning:
        return (background: warningContainer, foreground: onWarningContainer);
      case SemanticTone.danger:
        return (background: dangerContainer, foreground: onDangerContainer);
      case SemanticTone.info:
        return (background: infoContainer, foreground: onInfoContainer);
      case SemanticTone.neutral:
        return (background: neutralContainer, foreground: neutral);
    }
  }
}

enum SemanticTone { success, warning, danger, info, neutral }
