import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/json_parse.dart';
import '../../core/services/notification_service.dart';
import '../../core/network/storage_service.dart';
import '../../data/models/task_model.dart';

class NotificationSettings {
  final bool enabled;
  final int
  daysBefore; // 0 = same day, 1 = 1 day before, 3 = 3 days before, 7 = 7 days before

  const NotificationSettings({this.enabled = true, this.daysBefore = 1});

  NotificationSettings copyWith({bool? enabled, int? daysBefore}) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      daysBefore: daysBefore ?? this.daysBefore,
    );
  }

  Map<String, dynamic> toJson() {
    return {'enabled': enabled, 'daysBefore': daysBefore};
  }

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      enabled: parseOptionalBool(json['enabled']) ?? true,
      daysBefore: parseOptionalInt(json['daysBefore']) ?? 1,
    );
  }
}

class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  final NotificationService _notificationService;
  final StorageService _storageService;

  // Callback to reschedule notifications with current tasks
  void Function(List<Task> tasks)? onSettingsChanged;

  NotificationSettingsNotifier(this._notificationService, this._storageService)
    : super(const NotificationSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final json = await _storageService.getNotificationSettings();
      if (json != null) {
        state = NotificationSettings.fromJson(json);
      }
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _storageService.saveNotificationSettings(state.toJson());
    } catch (e) {
      debugPrint('Error saving notification settings: $e');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await _saveSettings();

    if (!enabled) {
      await _notificationService.cancelAllNotifications();
    } else {
      // Trigger notification reschedule if callback is set
      _triggerReschedule();
    }
  }

  Future<void> setDaysBefore(int days) async {
    state = state.copyWith(daysBefore: days);
    await _saveSettings();

    // Trigger notification reschedule if callback is set
    _triggerReschedule();
  }

  void _triggerReschedule() {
    if (onSettingsChanged != null) {
      // This will be called with the current task list
      // The actual implementation will pass tasks from the caller
    }
  }

  /// Call this method to reschedule notifications with the current task list
  Future<void> rescheduleNotifications(List<Task> tasks) async {
    if (!state.enabled) {
      await _notificationService.cancelAllNotifications();
      return;
    }

    // Filter tasks that are not completed and have upcoming deadlines
    final pendingTasks = tasks.where((task) {
      if (task.status == 'completed') return false;
      if (task.dueDatetime == null) return false;

      final now = DateTime.now();
      final daysUntilDue = task.dueDatetime!.difference(now).inDays;

      // Include tasks that are due within the notification window or are overdue (but not more than 1 day overdue)
      return daysUntilDue <= state.daysBefore && daysUntilDue >= -1;
    }).toList();

    await _notificationService.scheduleNotificationsForTasks(
      tasks: pendingTasks,
      daysBefore: state.daysBefore,
    );
  }

  Future<void> updateSettings(NotificationSettings settings) async {
    state = settings;
    await _saveSettings();

    // Trigger notification reschedule if callback is set
    _triggerReschedule();
  }
}

// Provider for notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// Provider for storage service
final notificationStorageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

// Provider for notification settings
final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>((
      ref,
    ) {
      final notificationService = ref.watch(notificationServiceProvider);
      final storageService = ref.watch(notificationStorageServiceProvider);
      return NotificationSettingsNotifier(notificationService, storageService);
    });

// Provider to check tasks and schedule notifications
final taskDeadlineNotifierProvider = Provider<void Function(List<Task>)>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  final settings = ref.watch(notificationSettingsProvider);

  return (List<Task> tasks) async {
    if (!settings.enabled) return;

    // Filter tasks that are not completed and have upcoming deadlines
    final pendingTasks = tasks.where((task) {
      if (task.status == 'completed') return false;
      if (task.dueDatetime == null) return false;

      final now = DateTime.now();
      final daysUntilDue = task.dueDatetime!.difference(now).inDays;

      // Only schedule if the task is due within the notification window
      return daysUntilDue <= settings.daysBefore && daysUntilDue >= -1;
    }).toList();

    await notificationService.scheduleNotificationsForTasks(
      tasks: pendingTasks,
      daysBefore: settings.daysBefore,
    );
  };
});
