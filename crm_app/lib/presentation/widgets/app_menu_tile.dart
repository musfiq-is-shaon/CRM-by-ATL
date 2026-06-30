import 'package:flutter/material.dart';

import '../../core/theme/app_theme_colors.dart';
import '../../core/theme/design_tokens.dart';

/// Premium list tile for settings / More menus — icon chip, title, subtitle, chevron.
class AppMenuTile extends StatelessWidget {
  const AppMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent,
    this.titleColor,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accent;
  final Color? titleColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textTertiary = AppThemeColors.textTertiaryColor(context);
    final tone = accent ?? cs.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: AppThemeColors.cardRowPadding,
              child: Row(
                children: [
                  AppThemeColors.iconChip(context, icon: icon, accent: tone),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.cardTitle(context)?.copyWith(
                                color: titleColor ?? textPrimary,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          subtitle,
                          style: AppTypography.bodySmall(context),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: textTertiary, size: 22),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: AppSpacing.pagePadding + AppSizes.iconChip + AppSpacing.md,
            endIndent: AppSpacing.pagePadding,
            color: AppThemeColors.dividerColor(context),
          ),
      ],
    );
  }
}

/// Uppercase section label above grouped menu cards.
class AppMenuSection extends StatelessWidget {
  const AppMenuSection({
    super.key,
    this.title,
    required this.children,
  });

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Padding(
            padding: AppThemeColors.sectionHeaderLabelPadding,
            child: Text(
              title!.toUpperCase(),
              style: AppTypography.labelCaps(context, textSecondary),
            ),
          ),
        ],
        ...children,
      ],
    );
  }
}
