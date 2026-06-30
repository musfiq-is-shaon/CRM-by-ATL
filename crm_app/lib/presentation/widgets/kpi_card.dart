import 'package:flutter/material.dart';

import '../../core/theme/app_theme_colors.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/theme_extensions.dart';

class KPICard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final String? subtitle;
  final VoidCallback? onTap;

  const KPICard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = AppThemeColors.cardColor(context);
    final borderColor = AppThemeColors.borderColor(context);
    final textTertiary = AppThemeColors.textTertiaryColor(context);
    final cs = Theme.of(context).colorScheme;
    final accent = iconColor ?? context.colors.primary;
    final tonal = AppThemeColors.tonalForAccent(context, accent);
    final shadows = context.isDark
        ? AppElevation.cardDark(accent)
        : AppElevation.cardLight;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
        boxShadow: shadows,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          splashColor: cs.primary.withValues(alpha: 0.08),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: AppSizes.iconChip,
                    height: AppSizes.iconChip,
                    decoration: BoxDecoration(
                      color: tonal.background,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      icon,
                      color: tonal.foreground,
                      size: AppSizes.iconChipIcon,
                    ),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.arrow_forward_ios,
                      size: AppTypography.captionSize,
                      color: textTertiary,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(value, style: AppTypography.kpiNumber(context)),
              const SizedBox(height: AppSpacing.xs),
              Text(title, style: AppTypography.kpiLabel(context)),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle!, style: AppTypography.caption(context)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
