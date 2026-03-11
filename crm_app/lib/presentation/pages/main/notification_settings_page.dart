import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../../core/services/notification_service.dart';
import '../../providers/notification_provider.dart';
import '../../providers/task_provider.dart';
import '../../widgets/crm_card.dart';

class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final settingsNotifier = ref.read(notificationSettingsProvider.notifier);
    final tasksState = ref.watch(tasksProvider);

    final bgColor = AppThemeColors.backgroundColor(context);
    final surfaceColor = AppThemeColors.surfaceColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final primaryColor = const Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        title: Text(
          'Notification Settings',
          style: TextStyle(color: textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Enable/Disable Notifications Section
          _buildSection(
            title: 'Notifications',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
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
                            'Receive task deadline reminders',
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
                        // Reschedule notifications with current tasks
                        await settingsNotifier.rescheduleNotifications(
                          tasksState.tasks,
                        );
                      },
                      activeColor: primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

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
                  await settingsNotifier.setDaysBefore(0);
                  // Reschedule notifications with current tasks
                  await settingsNotifier.rescheduleNotifications(
                    tasksState.tasks,
                  );
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
                  await settingsNotifier.setDaysBefore(1);
                  // Reschedule notifications with current tasks
                  await settingsNotifier.rescheduleNotifications(
                    tasksState.tasks,
                  );
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
                  await settingsNotifier.setDaysBefore(3);
                  // Reschedule notifications with current tasks
                  await settingsNotifier.rescheduleNotifications(
                    tasksState.tasks,
                  );
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
                  await settingsNotifier.setDaysBefore(7);
                  // Reschedule notifications with current tasks
                  await settingsNotifier.rescheduleNotifications(
                    tasksState.tasks,
                  );
                },
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                primaryColor: primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Info Card
          CRMCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: primaryColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Notifications are sent for upcoming task deadlines based on your selected preference.',
                      style: TextStyle(fontSize: 13, color: textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Test Notification Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final notificationService = NotificationService();
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
                foregroundColor: Colors.white,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                color: textSecondary?.withOpacity(0.3),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
