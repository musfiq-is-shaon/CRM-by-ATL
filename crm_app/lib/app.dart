import 'dart:async' show unawaited;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/attendance_reminder_controller.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'data/models/shift_model.dart';
import 'presentation/providers/accent_color_provider.dart';
import 'presentation/providers/amoled_provider.dart';
import 'presentation/providers/attendance_provider.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/user_profile_shift_provider.dart';
import 'core/network/session_expiration_provider.dart';
import 'presentation/providers/rbac_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'data/repositories/company_repository.dart';
import 'data/repositories/user_repository.dart';
import 'presentation/pages/auth/login_page.dart';
import 'presentation/pages/main/shell_page.dart' show ShellPage, loadedTabsProvider, selectedTabProvider;
import 'presentation/widgets/loading_widget.dart';

class CRMApp extends ConsumerStatefulWidget {
  const CRMApp({super.key});

  @override
  ConsumerState<CRMApp> createState() => _CRMAppState();
}

class _CRMAppState extends ConsumerState<CRMApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(themeProvider.notifier).init();
      await ref.read(accentColorProvider.notifier).init();
      await ref.read(amoledDarkProvider.notifier).init();
      if (!mounted) return;
      ref.read(authProvider.notifier).checkAuthStatus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(scheduleAttendanceReminders(ref.read));
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
          unawaited(scheduleAttendanceReminders(ref.read));
        });
      } else if (next.status == AuthStatus.unauthenticated) {
        ref.read(rbacProvider.notifier).clear();
        ref.read(selectedTabProvider.notifier).state = 0;
        ref.read(loadedTabsProvider.notifier).state = {};
        ref.read(companyRepositoryProvider).clearCache();
        ref.read(userRepositoryProvider).clearCache();
        unawaited(NotificationService().cancelAttendanceCheckInReminders());
      }
    });

    ref.listen<AttendanceState>(attendanceProvider, (previous, next) {
      unawaited(scheduleAttendanceReminders(ref.read));
    });
    ref.listen<AsyncValue<WorkShift?>>(userProfileShiftProvider, (previous, next) {
      unawaited(scheduleAttendanceReminders(ref.read));
    });

    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeProvider);
    final accent = ref.watch(accentColorProvider);
    final amoledBlack = ref.watch(amoledDarkProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: 'CRM Pro',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(accent, lightDynamic),
          darkTheme: AppTheme.dark(
            accent,
            darkDynamic,
            amoledBlack: amoledBlack,
          ),
          themeMode: themeMode,
          // Instant swap: AnimatedTheme lerp across the whole tree feels laggy on toggle.
          themeAnimationStyle: AnimationStyle.noAnimation,
          home:
              authState.status == AuthStatus.initial ||
                  authState.status == AuthStatus.loading
              ? const Scaffold(body: Center(child: LoadingWidget()))
              : authState.status == AuthStatus.authenticated
              ? const ShellPage()
              : const LoginPage(),
        );
      },
    );
  }
}
