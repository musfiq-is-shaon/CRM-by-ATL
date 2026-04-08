import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/rbac_page_keys.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/rbac_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../widgets/crm_card.dart';
import '../settings/change_password_page.dart';
import '../settings/settings_page.dart';
import 'notification_settings_page.dart';
import 'help_support_page.dart';
import '../attendance/attendance_hub_page.dart';
import '../leave/leave_list_page.dart';
import '../profile/profile_page.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final shiftAsync = ref.watch(userProfileShiftProvider);
    final me = ref.watch(rbacMeProvider);
    final showAttendance =
        me != null &&
        (me.hasNav(RbacPageKey.attendance) || me.hasNav(RbacPageKey.hr));
    final showLeave = me?.hasNav(RbacPageKey.leaves) ?? false;

    final bgColor = AppThemeColors.backgroundColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final textTertiary = AppThemeColors.textTertiaryColor(context);
    final cs = Theme.of(context).colorScheme;
    final primaryColor = cs.primary;
    final errorColor = cs.error;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppThemeColors.appBarTitle(context, 'More'),
      body: ListView(
        padding: AppThemeColors.pagePaddingAll,
        children: [
          CRMCard(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Center(
                    child: Text(
                      user?.name != null && user!.name.isNotEmpty
                          ? user.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'User',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        style: TextStyle(fontSize: 14, color: textSecondary),
                      ),
                      shiftAsync.when(
                        skipLoadingOnReload: true,
                        data: (w) {
                          final line = w?.timingDisplayLine.trim() ?? '';
                          if (line.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              line,
                              style: TextStyle(
                                fontSize: 12,
                                color: textTertiary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                        loading: () => Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Loading shift…',
                            style: TextStyle(fontSize: 12, color: textTertiary),
                          ),
                        ),
                        error: (e, _) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          user?.role ?? 'user',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: textTertiary),
              ],
            ),
          ),
          SizedBox(height: AppThemeColors.sectionGap),

          _buildSection(
            title: 'Management',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            textTertiary: textTertiary,
            primaryColor: primaryColor,
            children: [
              if (showAttendance)
                _buildMenuItem(
                  context,
                  icon: Icons.access_time_outlined,
                  title: 'Attendance',
                  subtitle: 'History & late reconciliation requests',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  textTertiary: textTertiary,
                  primaryColor: primaryColor,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AttendanceHubPage(),
                      ),
                    );
                  },
                ),
              if (showLeave)
                _buildMenuItem(
                  context,
                  icon: Icons.event_note_outlined,
                  title: 'Leave',
                  subtitle: 'Apply and track leave requests',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  textTertiary: textTertiary,
                  primaryColor: primaryColor,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LeaveListPage(),
                      ),
                    );
                  },
                ),
              _buildMenuItem(
                context,
                icon: Icons.settings_outlined,
                title: 'Settings',
                subtitle: 'App settings',
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                textTertiary: textTertiary,
                primaryColor: primaryColor,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          SizedBox(height: AppThemeColors.sectionGap),

          _buildSection(
            title: 'Account',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            textTertiary: textTertiary,
            primaryColor: primaryColor,
            children: [
              _buildMenuItem(
                context,
                icon: Icons.lock_outline,
                title: 'Change Password',
                subtitle: 'Update your password',
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                textTertiary: textTertiary,
                primaryColor: primaryColor,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChangePasswordPage(),
                    ),
                  );
                },
              ),
              _buildMenuItem(
                context,
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Manage notifications',
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                textTertiary: textTertiary,
                primaryColor: primaryColor,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationSettingsPage(),
                    ),
                  );
                },
              ),
              _buildMenuItem(
                context,
                icon: Icons.help_outline,
                title: 'Help & Support',
                subtitle: 'Get help',
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                textTertiary: textTertiary,
                primaryColor: primaryColor,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HelpSupportPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          SizedBox(height: AppThemeColors.sectionGap),

          _buildSection(
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            textTertiary: textTertiary,
            primaryColor: primaryColor,
            children: [
              _buildMenuItem(
                context,
                icon: Icons.logout,
                title: 'Logout',
                subtitle: 'Sign out of your account',
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                textTertiary: textTertiary,
                primaryColor: primaryColor,
                iconColor: errorColor,
                textColor: errorColor,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(
                        'Logout',
                        style: TextStyle(color: textPrimary),
                      ),
                      content: Text(
                        'Are you sure you want to logout?',
                        style: TextStyle(color: textSecondary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: primaryColor),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(
                            'Logout',
                            style: TextStyle(color: errorColor),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref.read(authProvider.notifier).logout();
                    ref.invalidate(notificationsProvider);
                  }
                },
              ),
              _buildMenuItem(
                context,
                icon: Icons.delete_forever,
                title: 'Delete Account',
                subtitle: 'Permanently delete your account',
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                textTertiary: textTertiary,
                primaryColor: primaryColor,
                iconColor: errorColor,
                textColor: errorColor,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(
                        'Delete Account',
                        style: TextStyle(color: textPrimary),
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'This action cannot be undone!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: errorColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Deleting your account will:\n• Remove all your data permanently\n• Deactivate your account\n• You will be logged out',
                            style: TextStyle(color: textSecondary),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: primaryColor),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(
                            'Delete Account',
                            style: TextStyle(color: errorColor),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref.read(authProvider.notifier).deleteAccount();
                    ref.invalidate(notificationsProvider);
                  }
                },
              ),
            ],
          ),
          SizedBox(height: AppThemeColors.sectionGap),

          Center(
            child: Text(
              'Version 1.2.2',
              style: TextStyle(fontSize: 12, color: textTertiary),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSection({
    String? title,
    required List<Widget> children,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? primaryColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: AppThemeColors.sectionHeaderLabelPadding,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
          ),
        ],
        CRMCard(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? primaryColor,
    Color? iconColor,
    Color? textColor,
  }) {
    final accent =
        iconColor ?? primaryColor ?? Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: AppThemeColors.cardRowPadding,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color:
                          textColor ??
                          textPrimary ??
                          Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          textTertiary ??
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color:
                  textTertiary ??
                  Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
