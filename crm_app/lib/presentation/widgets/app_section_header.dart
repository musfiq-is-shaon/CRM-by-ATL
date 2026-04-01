import 'package:flutter/material.dart';

import '../../core/theme/app_theme_colors.dart';

/// Consistent section title + optional subtitle for list/detail screens.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing = const SizedBox.shrink(),
  });

  final String title;
  final String? subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final primary = AppThemeColors.textPrimaryColor(context);
    final secondary = AppThemeColors.textSecondaryColor(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w600,
                    ) ??
                    TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: secondary,
                        height: 1.35,
                      ) ??
                      TextStyle(
                        fontSize: 13,
                        color: secondary,
                        height: 1.35,
                      ),
                ),
              ],
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}
