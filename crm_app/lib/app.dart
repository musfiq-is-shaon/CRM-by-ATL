import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/accent_color_provider.dart';
import 'presentation/providers/amoled_provider.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/pages/auth/login_page.dart';
import 'presentation/pages/main/shell_page.dart';
import 'presentation/widgets/loading_widget.dart';

class CRMApp extends ConsumerStatefulWidget {
  const CRMApp({super.key});

  @override
  ConsumerState<CRMApp> createState() => _CRMAppState();
}

class _CRMAppState extends ConsumerState<CRMApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(themeProvider.notifier).init();
      await ref.read(accentColorProvider.notifier).init();
      await ref.read(amoledDarkProvider.notifier).init();
      if (!mounted) return;
      ref.read(authProvider.notifier).checkAuthStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
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
          themeAnimationDuration: const Duration(milliseconds: 450),
          themeAnimationCurve: Curves.fastEaseInToSlowEaseOut,
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
