import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/rbac_page_keys.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/theme/design_tokens.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/rbac_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../widgets/app_menu_tile.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/crm_card.dart';
import '../admin/users_page.dart';
import '../companies/companies_list_page.dart';
import '../contacts/contacts_list_page.dart';
import '../sales/deals_page.dart';
import '../settings/change_password_page.dart';
import '../settings/settings_page.dart';
import '../shifts/shifts_admin_page.dart';
import 'notification_settings_page.dart';
import 'help_support_page.dart';
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
    final jwtAdmin = ref.watch(isAdminProvider);
    final showContacts = me?.canNavContacts ?? false;
    final showCompanies = me?.canNavCompanies ?? false;
    final showLeave = me?.hasNav(RbacPageKey.leaves) ?? false;
    final showSales = me?.hasNav(RbacPageKey.sales) ?? false;
    final showHr = jwtAdmin || (me?.hasNav(RbacPageKey.hr) ?? false);

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
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                AvatarWidget(name: user?.name ?? 'User', size: 56),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'User',
                        style: AppTypography.sectionTitle(context)?.copyWith(
                              color: textPrimary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: textSecondary,
                            ),
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
                      const SizedBox(height: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          (user?.role ?? 'user').toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: textTertiary),
              ],
            ),
          ),
          SizedBox(height: AppThemeColors.sectionGap),

          AppMenuSection(
            title: 'Management',
            children: [
              CRMCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    if (showSales)
                      AppMenuTile(
                        icon: Icons.handshake_outlined,
                        title: 'Sales & Deals',
                        subtitle: 'Pipeline, orders, and renewals',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DealsPage(),
                          ),
                        ),
                      ),
                    if (showContacts)
                      AppMenuTile(
                        icon: Icons.people_outline,
                        title: 'Contacts',
                        subtitle: 'People and relationships',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ContactsListPage(),
                          ),
                        ),
                      ),
                    if (showCompanies)
                      AppMenuTile(
                        icon: Icons.business_outlined,
                        title: 'Companies',
                        subtitle: 'Accounts and organizations',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CompaniesListPage(),
                          ),
                        ),
                      ),
                    if (showLeave)
                      AppMenuTile(
                        icon: Icons.event_note_outlined,
                        title: 'Leave',
                        subtitle: 'Apply and track leave requests',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LeaveListPage(),
                          ),
                        ),
                      ),
                    if (showHr) ...[
                      AppMenuTile(
                        icon: Icons.group_outlined,
                        title: 'Users',
                        subtitle: 'Team directory and roles',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UsersPage(),
                          ),
                        ),
                      ),
                      AppMenuTile(
                        icon: Icons.schedule_outlined,
                        title: 'Shifts',
                        subtitle: 'Work schedules and timings',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ShiftsAdminPage(),
                          ),
                        ),
                      ),
                    ],
                    AppMenuTile(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      subtitle: 'Theme, profile, and preferences',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsPage(),
                        ),
                      ),
                      showDivider: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppThemeColors.sectionGap),

          AppMenuSection(
            title: 'Account',
            children: [
              CRMCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    AppMenuTile(
                      icon: Icons.lock_outline,
                      title: 'Change Password',
                      subtitle: 'Update your password',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChangePasswordPage(),
                        ),
                      ),
                    ),
                    AppMenuTile(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      subtitle: 'Manage notification preferences',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationSettingsPage(),
                        ),
                      ),
                    ),
                    AppMenuTile(
                      icon: Icons.help_outline,
                      title: 'Help & Support',
                      subtitle: 'Get help using the app',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HelpSupportPage(),
                        ),
                      ),
                      showDivider: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppThemeColors.sectionGap),

          AppMenuSection(
            children: [
              CRMCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    AppMenuTile(
                      icon: Icons.logout_rounded,
                      title: 'Logout',
                      subtitle: 'Sign out of your account',
                      accent: errorColor,
                      titleColor: errorColor,
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
                    AppMenuTile(
                      icon: Icons.delete_forever_outlined,
                      title: 'Delete Account',
                      subtitle: 'Permanently delete your account',
                      accent: errorColor,
                      titleColor: errorColor,
                      showDivider: false,
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
                                const SizedBox(height: AppSpacing.xs),
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
              ),
            ],
          ),
          SizedBox(height: AppThemeColors.sectionGap),

          Center(
            child: Text(
              'Version 1.2.3',
              style: TextStyle(fontSize: 12, color: textTertiary),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
