import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/task_model.dart';
import '../../../core/services/attendance_reminder_controller.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../providers/notification_provider.dart';
import '../../providers/task_provider.dart';
import '../../widgets/crm_card.dart';
import 'reminder_reliability_guide_page.dart';

Future<void> _rescheduleTasksAndShiftAlerts(WidgetRef ref, List<Task> tasks) async {
  await ref.read(notificationSettingsProvider.notifier).rescheduleNotifications(tasks);
  await scheduleAttendanceReminders(ref.read);
}

class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final settingsNotifier = ref.read(notificationSettingsProvider.notifier);
    final tasksState = ref.watch(tasksProvider);

    final bgColor = AppThemeColors.backgroundColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppThemeColors.appBarTitle(context, 'Notification Settings'),
      body: ListView(
        padding: AppThemeColors.pagePaddingAll,
        children: [
          // Enable/Disable Notifications Section
          _buildSection(
            title: 'Notifications',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            children: [
              Padding(
                padding: AppThemeColors.cardRowPadding,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.notifications_outlined,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enable Notifications',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            'Turn this on to choose reminder timing and allow the system permission prompt. Task deadlines, shift check-in reminders, and server push (Firebase) when configured.',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: settings.enabled,
                      onChanged: (value) async {
                        await settingsNotifier.setEnabled(value);
                        await _rescheduleTasksAndShiftAlerts(
                          ref,
                          tasksState.tasks,
                        );
                      },
                      activeThumbColor: primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppThemeColors.sectionGap),

          // Notification Timing Section
          _buildSection(
            title: 'When to notify',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            children: [
              _buildTimingOption(
                title: 'On due date',
                subtitle: 'Get notified when the task is due today',
                value: 0,
                selectedValue: settings.daysBefore,
                onTap: () async {
                  if (!settings.enabled) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Turn on notifications above to use these options.'),
                        ),
                      );
                    }
                    return;
                  }
                  await settingsNotifier.setDaysBefore(0);
                  await _rescheduleTasksAndShiftAlerts(ref, tasksState.tasks);
                },
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                primaryColor: primaryColor,
              ),
              Divider(height: 1, color: AppThemeColors.borderColor(context)),
              _buildTimingOption(
                title: '1 day before',
                subtitle: 'Get notified one day before the deadline',
                value: 1,
                selectedValue: settings.daysBefore,
                onTap: () async {
                  if (!settings.enabled) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Turn on notifications above to use these options.'),
                        ),
                      );
                    }
                    return;
                  }
                  await settingsNotifier.setDaysBefore(1);
                  await _rescheduleTasksAndShiftAlerts(ref, tasksState.tasks);
                },
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                primaryColor: primaryColor,
              ),
              Divider(height: 1, color: AppThemeColors.borderColor(context)),
              _buildTimingOption(
                title: '3 days before',
                subtitle: 'Get notified three days before the deadline',
                value: 3,
                selectedValue: settings.daysBefore,
                onTap: () async {
                  if (!settings.enabled) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Turn on notifications above to use these options.'),
                        ),
                      );
                    }
                    return;
                  }
                  await settingsNotifier.setDaysBefore(3);
                  await _rescheduleTasksAndShiftAlerts(ref, tasksState.tasks);
                },
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                primaryColor: primaryColor,
              ),
              Divider(height: 1, color: AppThemeColors.borderColor(context)),
              _buildTimingOption(
                title: '7 days before',
                subtitle: 'Get notified one week before the deadline',
                value: 7,
                selectedValue: settings.daysBefore,
                onTap: () async {
                  if (!settings.enabled) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Turn on notifications above to use these options.'),
                        ),
                      );
                    }
                    return;
                  }
                  await settingsNotifier.setDaysBefore(7);
                  await _rescheduleTasksAndShiftAlerts(ref, tasksState.tasks);
                },
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                primaryColor: primaryColor,
              ),
            ],
          ),
          SizedBox(height: AppThemeColors.sectionGap),

          // Info Card
          CRMCard(
            child: Padding(
              padding: AppThemeColors.cardInsetPadding,
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: primaryColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Task alerts use your timing below. Shift check-in reminders notify 15 minutes before your shift, at shift start, and again 15 minutes after start (late threshold) when you have an assigned shift. '
                      'On Android 12 or newer, allow Alarms & reminders for this app; otherwise the system may delay or merge reminders when the app is not running.',
                      style: TextStyle(fontSize: 13, color: textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: AppThemeColors.sectionGap),
          CRMCard(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) =>
                          const ReminderReliabilityGuidePage(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: AppThemeColors.cardInsetPadding,
                  child: Row(
                    children: [
                      Icon(
                        Icons.smartphone_outlined,
                        color: primaryColor,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reminders late or missing?',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Step-by-step for Samsung, Xiaomi, OPPO, vivo, Huawei, Pixel, and more',
                              style: TextStyle(
                                fontSize: 12,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: AppThemeColors.sectionGap),

          // Test Notification Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                if (!settings.enabled) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Turn on “Enable Notifications” first, then allow alerts when the system asks.',
                        ),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                  return;
                }
                final notificationService = NotificationService();
                await notificationService.initialize();
                final ok = await notificationService.requestPermissions();
                if (!context.mounted) return;
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Notifications are not allowed for this app yet. Enable them in system Settings, then try again.',
                      ),
                      duration: Duration(seconds: 4),
                    ),
                  );
                  return;
                }
                await notificationService.sendTestNotification();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Test notification sent!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.notifications_active),
              label: const Text('Test Notification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor:
                    Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
    Color? textPrimary,
    Color? textSecondary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        CRMCard(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildTimingOption({
    required String title,
    required String subtitle,
    required int value,
    required int selectedValue,
    required VoidCallback onTap,
    Color? textPrimary,
    Color? textSecondary,
    Color? primaryColor,
  }) {
    final isSelected = value == selectedValue;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: AppThemeColors.cardRowPadding,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: primaryColor, size: 22)
            else
              Icon(
                Icons.circle_outlined,
                color: textSecondary?.withValues(alpha: 0.3),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
