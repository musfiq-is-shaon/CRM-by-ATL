import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/crm_card.dart';
import '../settings/settings_page.dart';
import '../admin/users_page.dart';
import 'notification_settings_page.dart';
import '../attendance/attendance_records_page.dart';
import '../leave/leave_list_page.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isAdmin = ref.watch(isAdminProvider);

    final bgColor = AppThemeColors.backgroundColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final textTertiary = AppThemeColors.textTertiaryColor(context);
    final primaryColor = const Color(0xFF2563EB);
    final errorColor = const Color(0xFFEF4444);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        title: Text('More', style: TextStyle(color: textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CRMCard(
            onTap: () {},
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      user?.name != null && user!.name.isNotEmpty
                          ? user.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: primaryColor,
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
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          user?.role ?? 'user',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: primaryColor,
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
          const SizedBox(height: 24),

          _buildSection(
            title: 'Management',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            textTertiary: textTertiary,
            primaryColor: primaryColor,
            children: [
              // Only show Users Management for admin users
              if (isAdmin)
                _buildMenuItem(
                  icon: Icons.people_outline,
                  title: 'Users Management',
                  subtitle: 'Manage app users',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  textTertiary: textTertiary,
                  primaryColor: primaryColor,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UsersPage(),
                      ),
                    );
                  },
                ),
              _buildMenuItem(
                icon: Icons.access_time_outlined,
                title: 'Attendance Records',
                subtitle: 'View attendance history',
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                textTertiary: textTertiary,
                primaryColor: primaryColor,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AttendanceRecordsPage(),
                    ),
                  );
                },
              ),
              _buildMenuItem(
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
          const SizedBox(height: 16),

          _buildSection(
            title: 'Account',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            textTertiary: textTertiary,
            primaryColor: primaryColor,
            children: [
              _buildMenuItem(
                icon: Icons.lock_outline,
                title: 'Change Password',
                subtitle: 'Update your password',
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                textTertiary: textTertiary,
                primaryColor: primaryColor,
                onTap: () {},
              ),
              _buildMenuItem(
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
                icon: Icons.help_outline,
                title: 'Help & Support',
                subtitle: 'Get help',
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                textTertiary: textTertiary,
                primaryColor: primaryColor,
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildSection(
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            textTertiary: textTertiary,
            primaryColor: primaryColor,
            children: [
              _buildMenuItem(
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
                  }
                },
              ),
              _buildMenuItem(
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
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 32),

          Center(
            child: Text(
              'Version 1.0.0',
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
            padding: const EdgeInsets.only(left: 4, bottom: 8),
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

  Widget _buildMenuItem({
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? primaryColor ?? const Color(0xFF2563EB))
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: iconColor ?? primaryColor ?? const Color(0xFF2563EB),
                size: 20,
              ),
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
                          textColor ?? textPrimary ?? const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: textTertiary ?? const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: textTertiary ?? const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}
