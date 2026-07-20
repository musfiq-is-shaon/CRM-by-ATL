import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';
import 'loading_widget.dart';

enum CRMButtonType { primary, secondary, text, danger }

enum CRMButtonSize { normal, large, small }

class CRMButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final CRMButtonType type;
  final CRMButtonSize size;
  final bool isLoading;
  final String? loadingText;
  final bool isFullWidth;
  final IconData? icon;
  final double? width;

  const CRMButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = CRMButtonType.primary,
    this.size = CRMButtonSize.normal,
    this.isLoading = false,
    this.loadingText,
    this.isFullWidth = false,
    this.icon,
    this.width,
  });

  double get _height => switch (size) {
        CRMButtonSize.large => AppSizes.buttonHeightLarge,
        CRMButtonSize.small => AppSizes.buttonHeightSmall,
        CRMButtonSize.normal => AppSizes.buttonHeight,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: isFullWidth ? double.infinity : width,
      height: _height,
      child: _buildButton(context, cs),
    );
  }

  Widget _buildButton(BuildContext context, ColorScheme cs) {
    final radius = BorderRadius.circular(AppRadius.md);
    final textStyle = AppTypography.button(context);
    switch (type) {
      case CRMButtonType.primary:
        return FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            disabledBackgroundColor: cs.onSurface.withValues(alpha: 0.12),
            disabledForegroundColor: cs.onSurface.withValues(alpha: 0.38),
            elevation: 0,
            minimumSize: Size(64, _height),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            shape: RoundedRectangleBorder(borderRadius: radius),
            textStyle: textStyle,
          ),
          child: _buildChild(context, cs.onPrimary),
        );
      case CRMButtonType.secondary:
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.primary,
            backgroundColor: cs.surfaceContainerHighest,
            side: BorderSide(color: cs.outline.withValues(alpha: 0.65)),
            minimumSize: Size(64, _height),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            shape: RoundedRectangleBorder(borderRadius: radius),
            textStyle: textStyle,
          ),
          child: _buildChild(context, cs.primary),
        );
      case CRMButtonType.text:
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: cs.primary,
            minimumSize: Size(48, _height),
            textStyle: textStyle,
          ),
          child: _buildChild(context, cs.primary),
        );
      case CRMButtonType.danger:
        return FilledButton(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
            elevation: 0,
            minimumSize: Size(64, _height),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            shape: RoundedRectangleBorder(borderRadius: radius),
            textStyle: textStyle,
          ),
          child: _buildChild(context, cs.onError),
        );
    }
  }

  Widget _buildChild(BuildContext context, Color foreground) {
    if (isLoading) {
      return ButtonLoadingState(
        label: loadingText ?? text,
        color: foreground,
      );
    }

    final labelStyle = AppTypography.button(context)?.copyWith(color: foreground);

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: AppSizes.iconChipIcon),
          const SizedBox(width: AppSpacing.sm),
          Text(text, style: labelStyle),
        ],
      );
    }

    return Text(text, style: labelStyle);
  }
}
