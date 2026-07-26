import 'package:flutter/material.dart';

import '../../core/theme/app_theme_colors.dart';

/// Startup loader — centered Material spinner.
class AppLaunchLoader extends StatelessWidget {
  const AppLaunchLoader({super.key});

  @override
  Widget build(BuildContext context) {
    final bg = AppThemeColors.backgroundColor(context);
    final cs = Theme.of(context).colorScheme;

    return ColoredBox(
      color: bg,
      child: Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            color: cs.primary,
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }
}
