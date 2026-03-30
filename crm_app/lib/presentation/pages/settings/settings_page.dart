import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../providers/theme_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/task_provider.dart';
import '../../widgets/crm_card.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;
    final notificationSettings = ref.watch(notificationSettingsProvider);

    final bgColor = AppThemeColors.backgroundColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final textTertiary = AppThemeColors.textTertiaryColor(context);
    final primaryColor = const Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        title: Text('Settings', style: TextStyle(color: textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CRMCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSettingItem(
                  icon: Icons.notifications_outlined,
                  title: 'Task Deadline Alerts',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  primaryColor: primaryColor,
                  trailing: Switch(
                    value: notificationSettings.enabled,
                    onChanged: (value) async {
                      await ref
                          .read(notificationSettingsProvider.notifier)
                          .setEnabled(value);
                      final tasks = ref.read(tasksProvider).tasks;
                      await ref
                          .read(notificationSettingsProvider.notifier)
                          .rescheduleNotifications(tasks);
                    },
                    activeThumbColor: primaryColor,
                  ),
                  onTap: () => _showNotificationSettingsSheet(context, ref),
                ),
                _buildSettingItem(
                  icon: Icons.dark_mode_outlined,
                  title: 'Dark Mode',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  primaryColor: primaryColor,
                  trailing: Switch(
                    value: isDarkMode,
                    onChanged: (value) {
                      ref.read(themeProvider.notifier).toggleTheme();
                    },
                    activeThumbColor: primaryColor,
                  ),
                ),
                _buildSettingItem(
                  icon: Icons.language_outlined,
                  title: 'Language',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  primaryColor: primaryColor,
                  trailing: Text(
                    'English',
                    style: TextStyle(color: textSecondary, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          CRMCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSettingItem(
                  icon: Icons.info_outline,
                  title: 'App Version',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  primaryColor: primaryColor,
                  trailing: Text(
                    '1.0.0',
                    style: TextStyle(color: textSecondary, fontSize: 14),
                  ),
                ),
                _buildSettingItem(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  primaryColor: primaryColor,
                  trailing: Icon(Icons.chevron_right, color: textTertiary),
                  onTap: () {},
                ),
                _buildSettingItem(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  primaryColor: primaryColor,
                  trailing: Icon(Icons.chevron_right, color: textTertiary),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required Widget trailing,
    Color? textPrimary,
    Color? textSecondary,
    Color? primaryColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: primaryColor ?? const Color(0xFF2563EB),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  color: textPrimary ?? const Color(0xFF1E293B),
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  void _showNotificationSettingsSheet(BuildContext context, WidgetRef ref) {
    final notificationSettings = ref.read(notificationSettingsProvider);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primaryColor = const Color(0xFF2563EB);

    int selectedDays = notificationSettings.daysBefore;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notification Settings',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Get notified when a task deadline is approaching:',
                style: TextStyle(fontSize: 14, color: textSecondary),
              ),
              const SizedBox(height: 16),
              _buildDaysOption(
                title: 'On due date',
                value: 0,
                selectedValue: selectedDays,
                textPrimary: textPrimary,
                primaryColor: primaryColor,
                onChanged: (value) {
                  setModalState(() => selectedDays = value);
                },
              ),
              _buildDaysOption(
                title: '1 day before',
                value: 1,
                selectedValue: selectedDays,
                textPrimary: textPrimary,
                primaryColor: primaryColor,
                onChanged: (value) {
                  setModalState(() => selectedDays = value);
                },
              ),
              _buildDaysOption(
                title: '3 days before',
                value: 3,
                selectedValue: selectedDays,
                textPrimary: textPrimary,
                primaryColor: primaryColor,
                onChanged: (value) {
                  setModalState(() => selectedDays = value);
                },
              ),
              _buildDaysOption(
                title: '7 days before',
                value: 7,
                selectedValue: selectedDays,
                textPrimary: textPrimary,
                primaryColor: primaryColor,
                onChanged: (value) {
                  setModalState(() => selectedDays = value);
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await ref
                        .read(notificationSettingsProvider.notifier)
                        .setDaysBefore(selectedDays);
                    final tasks = ref.read(tasksProvider).tasks;
                    await ref
                        .read(notificationSettingsProvider.notifier)
                        .rescheduleNotifications(tasks);
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDaysOption({
    required String title,
    required int value,
    required int selectedValue,
    required Color textPrimary,
    required Color primaryColor,
    required Function(int) onChanged,
  }) {
    final isSelected = value == selectedValue;
    return InkWell(
      onTap: () => onChanged(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? primaryColor : Colors.grey,
              size: 22,
            ),
            const SizedBox(width: 12),
            Text(title, style: TextStyle(fontSize: 15, color: textPrimary)),
          ],
        ),
      ),
    );
  }
}
