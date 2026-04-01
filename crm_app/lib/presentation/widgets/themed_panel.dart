import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/theme/theme_extensions.dart';

/// Static panel matching [CRMCard] surface + border (no tap / ink).
/// Use for grouped content so visuals stay consistent with cards across the app.
class ThemedPanel extends StatelessWidget {
  const ThemedPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = AppRadius.md,
    this.hasShadow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final bool hasShadow;

  @override
  Widget build(BuildContext context) {
    final cardColor = context.colors.surfaceContainerHigh;
    final borderColor = context.colors.outlineVariant.withValues(alpha: 0.65);
    final accent = context.colors.primary;
    final shadows = !hasShadow
        ? null
        : context.isDark
        ? AppElevation.cardDark(accent)
        : AppElevation.cardLight;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor),
        boxShadow: shadows,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppSpacing.md),
        child: child,
      ),
    );
  }
}
