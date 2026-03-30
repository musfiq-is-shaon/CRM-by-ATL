import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../widgets/profile_overview_body.dart';

/// Dedicated profile screen (user + company). Also reachable from More → Profile.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);

    return Scaffold(
      backgroundColor: AppThemeColors.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: surfaceColor,
        foregroundColor: textPrimary,
        title: Text('Profile', style: TextStyle(color: textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ProfileOverviewBody(),
        ],
      ),
    );
  }
}
