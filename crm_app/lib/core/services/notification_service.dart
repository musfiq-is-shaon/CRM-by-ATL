import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../../data/models/task_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - could navigate to task detail
    // The payload contains the task ID
    print('Notification tapped: ${response.payload}');
  }

  Future<bool> requestPermissions() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final iOS = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    bool? granted;
    if (android != null) {
      granted = await android.requestNotificationsPermission();
    }
    if (iOS != null) {
      granted = await iOS.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    return granted ?? false;
  }

  Future<void> scheduleTaskDeadlineNotification({
    required Task task,
    required int daysBefore,
  }) async {
    if (task.dueDatetime == null) return;

    final now = DateTime.now();
    final notificationTime = task.dueDatetime!.subtract(
      Duration(days: daysBefore),
    );

    // Don't schedule if the notification time has already passed
    if (notificationTime.isBefore(now)) return;

    // Don't schedule if the task is already completed
    if (task.status == 'completed') return;

    final scheduledDate = tz.TZDateTime.from(notificationTime, tz.local);

    final String title;
    final String body;

    if (daysBefore == 0) {
      title = 'Task Due Today';
      body = task.title;
    } else if (daysBefore == 1) {
      title = 'Task Due Tomorrow';
      body = task.title;
    } else {
      title = 'Task Due in $daysBefore days';
      body = task.title;
    }

    final androidDetails = AndroidNotificationDetails(
      'task_deadline_channel',
      'Task Deadline Notifications',
      channelDescription: 'Notifications for task deadline reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use task ID hash as notification ID to avoid duplicates
    final notificationId = task.id.hashCode + daysBefore;

    await _notifications.zonedSchedule(
      notificationId,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: task.id,
    );
  }

  Future<void> scheduleNotificationsForTasks({
    required List<Task> tasks,
    required int daysBefore,
  }) async {
    // Cancel existing notifications first to avoid duplicates
    await cancelAllNotifications();

    for (final task in tasks) {
      await scheduleTaskDeadlineNotification(
        task: task,
        daysBefore: daysBefore,
      );
    }
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  Future<void> cancelTaskNotifications(String taskId) async {
    // Cancel notifications for all possible day offsets for this task
    for (int i = 0; i <= 7; i++) {
      final notificationId = taskId.hashCode + i;
      await _notifications.cancel(notificationId);
    }
  }

  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'general_channel',
      'General Notifications',
      channelDescription: 'General app notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Send a test notification to verify the notification system is working
  Future<void> sendTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Test notification channel',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      999999,
      'Test Notification',
      'Notifications are working correctly!',
      details,
    );
  }
}
