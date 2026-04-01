import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../widgets/profile_overview_body.dart';

/// Dedicated profile screen (user + company). Also reachable from More → Profile.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppThemeColors.backgroundColor(context),
      appBar: AppThemeColors.appBarTitle(context, 'Profile'),
      body: ListView(
        padding: AppThemeColors.pagePaddingAll,
        children: const [
          ProfileOverviewBody(),
        ],
      ),
    );
  }
}
