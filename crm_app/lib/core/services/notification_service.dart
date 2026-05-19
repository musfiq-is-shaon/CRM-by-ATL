import 'dart:math' show min;

import 'package:flutter/foundation.dart'
    show
        TargetPlatform,
        debugPrint,
        defaultTargetPlatform,
        kDebugMode,
        kIsWeb;
import 'package:flutter/material.dart'
    show
        AppLifecycleState,
        ScaffoldMessenger,
        SnackBar,
        SnackBarBehavior,
        Text,
        TextOverflow,
        WidgetsBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../../data/models/task_model.dart';
import '../navigation/app_navigator.dart';

/// One calendar day’s shift window (local wall-clock) for attendance reminders.
typedef AttendanceShiftWindow = ({
  DateTime anchorLocal,
  DateTime windowEndLocal,
});

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Reserved range for shift check-in reminders (IDs per day × days ahead).
  static const int attendanceReminderIdBase = 8810000;
  /// Slot 0 = [earlyReminderMinutesBeforeShiftStart] before start; slot 1 = shift start;
  /// slot 2 = [lateThresholdMinutesAfterShiftStart] after start (late threshold).
  static const int attendanceReminderSlotsPerDay = 3;
  /// First reminder: this many minutes **before** shift start.
  static const int earlyReminderMinutesBeforeShiftStart = 15;
  /// Third reminder offset from shift start (late threshold).
  static const int lateThresholdMinutesAfterShiftStart = 15;
  /// Pre-schedule this many calendar days so alarms fire without opening the app (OS-held).
  static const int attendanceReminderDaysAhead = 6;

  /// iOS keeps roughly **64** pending local notifications per app; we cap attendance batch size.
  /// (Android can schedule more — see [attendanceReminderDaysAhead].)
  static bool get _isAppleMobile =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Calendar days of shift windows to schedule (1 on iOS, [attendanceReminderDaysAhead] elsewhere).
  static int get effectiveAttendanceDaysAhead =>
      _isAppleMobile ? 1 : attendanceReminderDaysAhead;

  static int get attendanceReminderTotalIds =>
      attendanceReminderSlotsPerDay * attendanceReminderDaysAhead;

  static bool notificationIdIsAttendanceReminder(int id) =>
      id >= attendanceReminderIdBase &&
      id < attendanceReminderIdBase + attendanceReminderTotalIds;

  Future<void> initialize() async {
    if (_isInitialized) return;

    tz_data.initializeTimeZones();
    await _syncLocalTimeZone();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    // Do not prompt on plugin init — OS consent runs after the user opts in in-app
    // (App Store Review Guideline 4.5.4).
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _ensureAndroidNotificationChannels();

    _isInitialized = true;
  }

  /// Android 8+: channels must exist before FCM can post with [crm_fcm_default] (see AndroidManifest meta-data).
  Future<void> _ensureAndroidNotificationChannels() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    const channels = <AndroidNotificationChannel>[
      AndroidNotificationChannel(
        'crm_fcm_default',
        'Push notifications',
        description: 'Real-time alerts from your CRM (Firebase)',
        importance: Importance.max,
        playSound: true,
        showBadge: true,
      ),
      AndroidNotificationChannel(
        'general_channel',
        'General notifications',
        description: 'Other in-app notifications',
        importance: Importance.high,
        playSound: true,
      ),
    ];
    for (final c in channels) {
      await android.createNotificationChannel(c);
    }
  }

  /// Foreground FCM: same channel id as [com.google.firebase.messaging.default_notification_channel_id] on Android.
  Future<void> showFcmForegroundNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'crm_fcm_default',
      'Push notifications',
      channelDescription: 'Real-time alerts from your CRM (Firebase)',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      visibility: NotificationVisibility.public,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
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
    _showForegroundInAppBanner(title, body);
  }

  /// When the app is open, the status-bar tray is easy to miss; mirror the alert in-app.
  void _showForegroundInAppBanner(String title, String body) {
    if (kIsWeb) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    void show() {
      if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      final ctx = appNavigatorKey.currentContext;
      if (ctx == null) return;
      final messenger = ScaffoldMessenger.maybeOf(ctx);
      messenger?.clearSnackBars();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            body.isEmpty ? title : '$title\n$body',
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          showCloseIcon: true,
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => show());
  }

  /// Maps [tz.local] to the device IANA zone. Without this, the timezone
  /// package defaults to UTC and scheduled wall-clock times are wrong.
  Future<void> _syncLocalTimeZone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Keep package default (UTC) if the OS reports an unknown identifier.
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap — payload is task id or attendance payload.
    if (kDebugMode) {
      debugPrint('Notification tapped: ${response.payload}');
    }
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
      // Required on Android 12+ for [AndroidScheduleMode.exactAllowWhileIdle] used by
      // shift reminders; without it, zoned alarms may never fire (silent failure on some OEMs).
      await android.requestExactAlarmsPermission();
    }
    if (iOS != null) {
      granted = await iOS.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    // Android < 33: POST_NOTIFICATIONS does not exist; the plugin may return null (treat as allowed).
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return granted ?? true;
    }
    return granted ?? false;
  }

  /// Android 12+ (API 31+): whether the app may use exact alarms for the shift-start
  /// notification. Without this, the OS may batch or delay the alarm.
  Future<bool?> canScheduleExactAlarmsAndroid() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return android?.canScheduleExactNotifications();
  }

  /// Opens the system screen where the user can allow **Alarms & reminders** for this app.
  Future<void> requestExactAlarmsAndroid() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestExactAlarmsPermission();
  }

  Future<void> scheduleTaskDeadlineNotification({
    required Task task,
    required int daysBefore,
  }) async {
    if (task.dueDatetime == null) return;

    final now = DateTime.now();

    // Calculate notification time: due date minus daysBefore
    // For example: if due date is March 13 and daysBefore=1,
    // notification will be March 12 (1 day before)
    final notificationTime = task.dueDatetime!.subtract(
      Duration(days: daysBefore),
    );

    // For daysBefore=0 (on due date), we want to notify at the start of the due date day
    // For daysBefore>0, we want to notify at the same time on the day before

    // Don't schedule if the task is already completed
    if (task.status == 'completed') return;

    if (kDebugMode) {
      debugPrint('=== Scheduling Notification ===');
      debugPrint('Task: ${task.title}');
      debugPrint('Due: ${task.dueDatetime}');
      debugPrint('DaysBefore: $daysBefore');
      debugPrint('Notification Time: $notificationTime');
      debugPrint('Now: $now');
      debugPrint('Is in future: ${notificationTime.isAfter(now)}');
      debugPrint('==============================');
    }

    // Don't schedule if the notification time has already passed
    if (notificationTime.isBefore(now)) {
      if (kDebugMode) {
        debugPrint('Skipping - notification time has passed');
      }
      return;
    }

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

    if (kDebugMode) {
      debugPrint('Notification scheduled with ID: $notificationId');
    }
  }

  Future<void> scheduleNotificationsForTasks({
    required List<Task> tasks,
    required int daysBefore,
  }) async {
    // Cancel task (and other) notifications but keep shift check-in reminders in
    // [attendanceReminderIdBase..] — those are resynced from [syncAttendanceCheckInReminders].
    final pending = await _notifications.pendingNotificationRequests();
    for (final p in pending) {
      if (!notificationIdIsAttendanceReminder(p.id)) {
        await _notifications.cancel(p.id);
      }
    }

    for (final task in tasks) {
      await scheduleTaskDeadlineNotification(
        task: task,
        daysBefore: daysBefore,
      );
    }
  }

  /// Clears all scheduled shift-start check-in reminders (IDs in [attendanceReminderIdBase] range).
  ///
  /// Batched cancels to avoid stalling the main isolate when rescheduling.
  Future<void> cancelAttendanceCheckInReminders() async {
    const batch = 40;
    for (var i = 0; i < attendanceReminderTotalIds; i += batch) {
      final end = min(i + batch, attendanceReminderTotalIds);
      await Future.wait(
        List.generate(
          end - i,
          (j) => _notifications.cancel(attendanceReminderIdBase + i + j),
        ),
      );
    }
  }

  /// Schedules **three** OS-local notifications per shift day: **before** shift start
  /// ([earlyReminderMinutesBeforeShiftStart]), at **shift start**, and at
  /// **shift start + [lateThresholdMinutesAfterShiftStart]** (late threshold).
  ///
  /// [windows] are typically **today + next days** so upcoming times are pre-registered.
  /// Cancels when the user checks in (see attendance reminder controller).
  ///
  /// **Android:** Exact alarms improve on-time delivery (see [canScheduleExactAlarmsAndroid]).
  Future<void> scheduleAttendanceCheckInReminders({
    required List<AttendanceShiftWindow> windows,
    required String shiftLabel,
  }) async {
    if (!_isInitialized) await initialize();
    await cancelAttendanceCheckInReminders();

    if (windows.isEmpty) return;

    final now = DateTime.now();
    final androidExactOk = await canScheduleExactAlarmsAndroid();
    if (androidExactOk == false) {
      debugPrint(
        'Attendance reminders: Android "Alarms & reminders" (exact alarms) is off — '
        'reminders may be delayed or batched when the app is not running. '
        'Enable it in system settings (Notification settings in this app).',
      );
    }

    const androidDetails = AndroidNotificationDetails(
      'attendance_shift_channel',
      'Shift check-in reminders',
      channelDescription:
          'Reminds you 15 min before shift, at shift start, and at the late threshold (15 min after start)',
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

    const titleEarly = 'Shift starting soon';
    const titleStart = 'Time to check in';
    const titleLate = 'Late check-in reminder';
    final shift = shiftLabel.trim();
    final bodyEarly = shift.isNotEmpty
        ? 'Your shift ($shift) starts in $earlyReminderMinutesBeforeShiftStart minutes. Open the app to check in.'
        : 'Your shift starts in $earlyReminderMinutesBeforeShiftStart minutes. Open the app to check in.';
    final bodyStart = shift.isNotEmpty
        ? 'Your shift ($shift) has started. Open the app to check in.'
        : 'Your shift has started. Open the app to check in.';
    final bodyLate = shift.isNotEmpty
        ? 'Late threshold (15 min after start). Open the app to check in — shift ($shift).'
        : 'Late threshold (15 min after start). Open the app to check in.';

    final maxDays = effectiveAttendanceDaysAhead;
    final slotOffsetsMinutes = <int>[
      -earlyReminderMinutesBeforeShiftStart,
      0,
      lateThresholdMinutesAfterShiftStart,
    ];

    var dayIndex = 0;
    for (final w in windows) {
      if (dayIndex >= maxDays) break;

      final anchorLocal = w.anchorLocal;
      final windowEndLocal = w.windowEndLocal;
      final end = windowEndLocal.isAfter(anchorLocal)
          ? windowEndLocal
          : anchorLocal;

      final endTz = tz.TZDateTime.from(end, tz.local);
      final idBase =
          attendanceReminderIdBase + dayIndex * attendanceReminderSlotsPerDay;

      for (var s = 0; s < slotOffsetsMinutes.length; s++) {
        final offsetMin = slotOffsetsMinutes[s];
        final fireAt = anchorLocal.add(Duration(minutes: offsetMin));

        // Short shift: skip the post-start slot if it falls after the shift window end.
        if (fireAt.isAfter(end)) {
          continue;
        }

        if (fireAt.isBefore(now.subtract(const Duration(seconds: 1)))) {
          continue;
        }
        var scheduled = tz.TZDateTime.from(fireAt, tz.local);
        final tzNow = tz.TZDateTime.now(tz.local);
        if (scheduled.isBefore(tzNow.subtract(const Duration(seconds: 1)))) {
          continue;
        }
        if (!scheduled.isAfter(tzNow)) {
          scheduled = tzNow.add(const Duration(seconds: 2));
        }
        if (!scheduled.isBefore(endTz)) {
          continue;
        }

        final id = idBase + s;
        final String title;
        final String body;
        switch (s) {
          case 0:
            title = titleEarly;
            body = bodyEarly;
            break;
          case 1:
            title = titleStart;
            body = bodyStart;
            break;
          default:
            title = titleLate;
            body = bodyLate;
        }

        await _zonedScheduleAttendanceSlot(
          id: id,
          title: title,
          body: body,
          scheduled: scheduled,
          details: details,
        );
      }
      dayIndex++;
    }
  }

  Future<void> _zonedScheduleAttendanceSlot({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduled,
    required NotificationDetails details,
  }) async {
    final effectiveDetails = _shiftStartIosDetails(details);

    if (defaultTargetPlatform != TargetPlatform.android) {
      try {
        await _notifications.zonedSchedule(
          id,
          title,
          body,
          scheduled,
          effectiveDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'attendance_check_in',
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Attendance zonedSchedule failed id=$id ($e)');
        }
      }
      return;
    }

    // Prefer alarm-clock scheduling first — highest OS priority when exact-alarm allowed.
    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        effectiveDetails,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'attendance_check_in',
      );
      return;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Attendance shift-start alarmClock failed id=$id ($e), retrying exactAllowWhileIdle',
        );
      }
    }
    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        effectiveDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'attendance_check_in',
      );
      return;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Attendance shift-start exactAllowWhileIdle failed id=$id ($e), retrying inexactAllowWhileIdle',
        );
      }
    }
    try {
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        effectiveDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'attendance_check_in',
      );
    } catch (e2) {
      if (kDebugMode) {
        debugPrint('Attendance zonedSchedule inexact failed id=$id ($e2)');
      }
    }
  }

  /// iOS: time-sensitive so Focus / summary is less likely to defer shift start.
  NotificationDetails _shiftStartIosDetails(NotificationDetails base) {
    if (defaultTargetPlatform != TargetPlatform.iOS) return base;
    return NotificationDetails(
      android: base.android,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
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
