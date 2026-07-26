import 'dart:async' show Timer, unawaited;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/attendance_reminder_controller.dart';
import 'core/services/fcm_notification_sync.dart';
import 'core/services/fcm_service.dart';
import 'core/navigation/app_navigator.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/accent_color_provider.dart';
import 'presentation/providers/amoled_provider.dart';
import 'presentation/providers/attendance_provider.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/dashboard_weather_provider.dart';
import 'presentation/providers/lunch_provider.dart';
import 'presentation/providers/notifications_provider.dart';
import 'presentation/providers/user_profile_shift_provider.dart';
import 'core/network/session_expiration_provider.dart';
import 'presentation/providers/rbac_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'data/repositories/company_repository.dart';
import 'data/repositories/user_repository.dart';
import 'presentation/pages/auth/login_page.dart';
import 'presentation/pages/main/shell_page.dart' show ShellPage, loadedTabsProvider, selectedTabProvider;
import 'presentation/widgets/app_launch_loader.dart';
import 'presentation/widgets/ios_force_update_gate.dart';
import 'presentation/providers/sale_provider.dart';
import 'presentation/providers/task_provider.dart';
import 'presentation/providers/contact_provider.dart';
import 'presentation/providers/leave_provider.dart';

class CRMApp extends ConsumerStatefulWidget {
  const CRMApp({super.key});

  @override
  ConsumerState<CRMApp> createState() => _CRMAppState();
}

class _CRMAppState extends ConsumerState<CRMApp> with WidgetsBindingObserver {
  static const _minLaunchDuration = Duration(milliseconds: 300);

  /// [ref.listen] on auth may not run if the user is already authenticated when this widget mounts.
  bool _fcmNotificationBridgeRegistered = false;
  bool _launchHold = true;
  Timer? _inAppNotificationPollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        _runStartup(),
        Future<void>.delayed(_minLaunchDuration),
      ]);
      if (!mounted) return;
      setState(() => _launchHold = false);
    });
  }

  Future<void> _runStartup() async {
    await ref.read(themeProvider.notifier).init();
    await ref.read(accentColorProvider.notifier).init();
    await ref.read(amoledDarkProvider.notifier).init();
    if (!mounted) return;
    // Must complete before checking auth — otherwise we skip FCM when session restores.
    await ref.read(authProvider.notifier).checkAuthStatus();
    if (!mounted) return;
    if (ref.read(authProvider).status == AuthStatus.authenticated) {
      _ensureFcmNotificationBridgeAndPolling();
    }
  }

  @override
  void dispose() {
    _inAppNotificationPollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _ensureFcmNotificationBridgeAndPolling() {
    if (!mounted) return;
    if (ref.read(authProvider).status != AuthStatus.authenticated) return;
    if (!_fcmNotificationBridgeRegistered) {
      _fcmNotificationBridgeRegistered = true;
      FcmService.instance.setForegroundSideEffects((message, showedTray) async {
        await syncNotificationsAndMaybeShowTrayFromApi(
          ref,
          message,
          showedTray,
        );
      });
      unawaited(FcmService.instance.handleInitialMessageOpenedApp());
    }
    _inAppNotificationPollTimer?.cancel();
    _inAppNotificationPollTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) {
        if (!mounted) return;
        if (ref.read(authProvider).status != AuthStatus.authenticated) return;
        unawaited(pollForNewInAppNotifications(ref));
      },
    );
    unawaited(pollForNewInAppNotifications(ref));
  }

  void _stopInAppNotificationPolling() {
    _inAppNotificationPollTimer?.cancel();
    _inAppNotificationPollTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(scheduleAttendanceReminders(ref.read));
      if (ref.read(authProvider).status == AuthStatus.authenticated) {
        unawaited(ref.read(notificationsProvider.notifier).load(silent: true));
        _ensureFcmNotificationBridgeAndPolling();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopInAppNotificationPolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(sessionExpirationTickProvider, (previous, next) {
      if (previous != next) {
        ref.read(authProvider.notifier).onSessionExpired();
      }
    });

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        ref.read(rbacProvider.notifier).load();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Defer + short debounce so Shell/RBAC/dashboard network work is not competing
          // with local notification scheduling on the same frame as navigation.
          queueScheduleAttendanceReminders(
            ref.read,
            debounce: const Duration(milliseconds: 200),
          );
          _ensureFcmNotificationBridgeAndPolling();
        });
      } else if (next.status == AuthStatus.unauthenticated) {
        ref.read(attendanceProvider.notifier).resetForLogout();
        ref.read(lunchProvider.notifier).clear();
        ref.read(rbacProvider.notifier).clear();
        ref.read(selectedTabProvider.notifier).state = 0;
        ref.read(loadedTabsProvider.notifier).state = {};
        ref.read(companyRepositoryProvider).clearCache();
        ref.read(userRepositoryProvider).clearCache();
        // Drop prior-user scoped UI state (in-flight responses ignored via gens/clear).
        ref.invalidate(notificationsProvider);
        ref.invalidate(dashboardWeatherProvider);
        ref.invalidate(salesProvider);
        ref.invalidate(tasksProvider);
        ref.invalidate(contactsProvider);
        ref.invalidate(leaveProvider);
        ref.invalidate(userProfileShiftProvider);
        unawaited(
          Future(() => NotificationService().cancelAttendanceCheckInReminders()),
        );
        _fcmNotificationBridgeRegistered = false;
        FcmService.instance.setForegroundSideEffects(null);
        _stopInAppNotificationPolling();
      }
    });

    // Narrow triggers + debounced reschedule — full [AttendanceState] updates were
    // firing on loading/records and rescheduling local notifications too often.
    ref.listen<String>(
      attendanceProvider.select((s) {
        final t = s.todayAttendance;
        if (t == null) return 'null';
        return '${t.date}|${t.checkInTime?.millisecondsSinceEpoch}|'
            '${t.hasNoShift}|${t.safeStatus}|${t.shiftStartTime}|'
            '${t.shiftEndTime}|${t.assignedShiftId}|${t.shiftName}';
      }),
      (previous, next) {
        queueScheduleAttendanceReminders(ref.read);
      },
    );
    ref.listen<String>(
      userProfileShiftProvider.select((async) {
        final w = async.valueOrNull;
        if (w == null) {
          return 'loading:${async.isLoading}|${async.hasError}';
        }
        return '${w.startTime}|${w.endTime}|${w.weekendDays}';
      }),
      (previous, next) {
        if (previous == next) return;
        queueScheduleAttendanceReminders(ref.read);
      },
    );

    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeProvider);
    final accent = ref.watch(accentColorProvider);
    final amoledBlack = ref.watch(amoledDarkProvider);
    final showLaunchLoader = _launchHold ||
        authState.status == AuthStatus.initial ||
        authState.status == AuthStatus.loading;

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'CRM',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(accent, lightDynamic),
          darkTheme: AppTheme.dark(
            accent,
            darkDynamic,
            amoledBlack: amoledBlack,
          ),
          themeMode: themeMode,
          // Short lerp: full-tree AnimatedTheme can feel heavy; keep duration small.
          themeAnimationStyle: AnimationStyle(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
          ),
          home: IosForceUpdateGate(
            child: showLaunchLoader
                ? const Scaffold(body: AppLaunchLoader())
                : authState.status == AuthStatus.authenticated
                    ? const ShellPage()
                    : const LoginPage(),
          ),
        );
      },
    );
  }
}
