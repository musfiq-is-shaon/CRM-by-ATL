import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/attendance_reminder_controller.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../providers/theme_provider.dart';
import '../../providers/accent_color_provider.dart';
import '../../providers/amoled_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/task_provider.dart';
import '../../widgets/crm_card.dart';
import '../../widgets/premium_color_picker.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;
    final notificationSettings = ref.watch(notificationSettingsProvider);
    final accent = ref.watch(accentColorProvider);
    final amoledBlack = ref.watch(amoledDarkProvider);

    final bgColor = AppThemeColors.backgroundColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final textTertiary = AppThemeColors.textTertiaryColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppThemeColors.appBarTitle(context, 'Settings'),
      body: ListView(
        padding: AppThemeColors.pagePaddingAll,
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
                const SizedBox(height: 12),
                _buildSettingItem(
                  context,
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
                      await scheduleAttendanceReminders(ref.read);
                    },
                    activeThumbColor: primaryColor,
                  ),
                  onTap: () => _showNotificationSettingsSheet(context, ref),
                ),
                _buildSettingItem(
                  context,
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
                  context,
                  icon: Icons.contrast,
                  title: 'OLED black',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  primaryColor: primaryColor,
                  trailing: Switch(
                    value: amoledBlack,
                    onChanged: isDarkMode
                        ? (value) => ref
                            .read(amoledDarkProvider.notifier)
                            .setEnabled(value)
                        : null,
                    activeThumbColor: primaryColor,
                  ),
                ),
                _buildSettingItem(
                  context,
                  icon: Icons.palette_outlined,
                  title: 'Accent color',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  primaryColor: primaryColor,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent,
                          border: Border.all(
                            color: AppThemeColors.borderColor(context),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right, color: textTertiary),
                    ],
                  ),
                  onTap: () async {
                    final recent = ref
                        .read(accentColorProvider.notifier)
                        .recentColors;
                    final picked = await showPremiumColorPicker(
                      context,
                      initialColor: accent,
                      recentColors: recent,
                    );
                    if (picked != null && context.mounted) {
                      await ref
                          .read(accentColorProvider.notifier)
                          .setAccent(picked);
                    }
                  },
                ),
                _buildSettingItem(
                  context,
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
          const SizedBox(height: 12),

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
                const SizedBox(height: 12),
                _buildSettingItem(
                  context,
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
                  context,
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  primaryColor: primaryColor,
                  trailing: Icon(Icons.chevron_right, color: textTertiary),
                  onTap: () {},
                ),
                _buildSettingItem(
                  context,
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
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
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
            Icon(icon, color: primaryColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  color:
                      textPrimary ?? Theme.of(context).colorScheme.onSurface,
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
    final primaryColor = Theme.of(context).colorScheme.primary;

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
          padding: AppThemeColors.pagePaddingAll,
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
              const SizedBox(height: 16),
              Text(
                'Get notified when a task deadline is approaching:',
                style: TextStyle(fontSize: 14, color: textSecondary),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await ref
                        .read(notificationSettingsProvider.notifier)
                        .setDaysBefore(selectedDays);
                    final tasks = ref.read(tasksProvider).tasks;
                    await ref
                        .read(notificationSettingsProvider.notifier)
                        .rescheduleNotifications(tasks);
                    await scheduleAttendanceReminders(ref.read);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save'),
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
