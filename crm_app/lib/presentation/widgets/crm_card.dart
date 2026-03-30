import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/theme/theme_extensions.dart';

class CRMCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double borderRadius;
  final bool hasShadow;

  const CRMCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderRadius = AppRadius.md,
    this.hasShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = backgroundColor ?? context.colors.surfaceContainerHigh;
    final borderColor = context.colors.outlineVariant.withOpacity(0.65);
    final accent = context.colors.primary;
    final shadows = !hasShadow
        ? null
        : context.isDark
        ? AppElevation.cardDark(accent)
        : AppElevation.cardLight;

    // Use [Container], not [AnimatedContainer]. Theme mode changes already run
    // through MaterialApp's AnimatedTheme; animating the same colors again here
    // stacks animations and makes cards (e.g. pending tasks) look wrong.
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor),
        boxShadow: shadows,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: accent.withOpacity(0.08),
          highlightColor: accent.withOpacity(0.04),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppSpacing.md),
            child: child,
          ),
        ),
      ),
    );
  }
}
