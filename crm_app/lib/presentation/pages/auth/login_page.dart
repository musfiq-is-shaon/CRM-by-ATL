import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/storage_service.dart';
import '../../../core/theme/app_theme_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/crm_button.dart';
import '../../widgets/crm_text_field.dart';
import 'forgot_password_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  List<SavedLoginAccount> _savedAccounts = [];
  bool _pickerOpen = false;
  /// After closing the sheet without picking, next email tap opens keyboard only (no sheet loop).
  bool _skipSavedPickerOnNextEmailTap = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSavedAccounts());
  }

  Future<void> _loadSavedAccounts() async {
    final list = await ref.read(storageServiceProvider).getSavedAccounts();
    if (!mounted) return;
    setState(() => _savedAccounts = list);
  }

  void _onEmailTap() {
    if (_savedAccounts.isEmpty) return;
    if (_emailController.text.trim().isNotEmpty) return;
    if (_pickerOpen) return;

    if (_skipSavedPickerOnNextEmailTap) {
      setState(() => _skipSavedPickerOnNextEmailTap = false);
      return;
    }
    _showSavedAccountsSheet();
  }

  Future<void> _showSavedAccountsSheet() async {
    if (_savedAccounts.isEmpty || !mounted) return;
    final loginCtx = context;
    _pickerOpen = true;
    bool? picked;
    try {
      picked = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isDismissible: true,
      builder: (sheetCtx) {
        final textPrimary = AppThemeColors.textPrimaryColor(sheetCtx);
        final textSecondary = AppThemeColors.textSecondaryColor(sheetCtx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(
                  'Saved accounts',
                  style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Choose an account to fill email and password.',
                  style: TextStyle(fontSize: 13, color: textSecondary, height: 1.3),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: math.min(
                    420,
                    MediaQuery.sizeOf(sheetCtx).height * 0.5,
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _savedAccounts.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, i) {
                    // Newest saved accounts last in storage — show recent first.
                    final a = _savedAccounts[_savedAccounts.length - 1 - i];
                    return ListTile(
                      leading: Icon(
                        Icons.account_circle_outlined,
                        color: Theme.of(sheetCtx).colorScheme.primary,
                      ),
                      title: Text(
                        a.email,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Tap to sign in with saved password',
                        style: TextStyle(fontSize: 12, color: textSecondary),
                      ),
                      onTap: () {
                        setState(() {
                          _rememberMe = true;
                          _emailController.text = a.email;
                          _passwordController.text = a.password;
                        });
                        ref.read(authProvider.notifier).clearError();
                        Navigator.of(sheetCtx).pop(true);
                        _emailFocus.unfocus();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          FocusScope.of(loginCtx).requestFocus(_passwordFocus);
                        });
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton(
                  onPressed: () => Navigator.of(sheetCtx).pop(false),
                  child: const Text('Type a different account'),
                ),
              ),
            ],
          ),
        );
      },
    );
    } finally {
      _pickerOpen = false;
    }

    if (!mounted) return;
    if (picked != true) {
      setState(() => _skipSavedPickerOnNextEmailTap = true);
      _emailFocus.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  void dispose() {
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      await ref.read(authProvider.notifier).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            rememberMe: _rememberMe,
          );
    }
  }

  void _onCredentialsChanged() {
    ref.read(authProvider.notifier).clearError();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final bgColor = AppThemeColors.backgroundColor(context);
    final textPrimary = AppThemeColors.textPrimaryColor(context);
    final textSecondary = AppThemeColors.textSecondaryColor(context);
    final showLoginWarning =
        authState.error != null && authState.status == AuthStatus.unauthenticated;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.07),
                    bgColor,
                    bgColor,
                  ],
                  stops: const [0.0, 0.38, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: AppThemeColors.pagePaddingLoose,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 48),
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colorScheme.primary,
                                  colorScheme.primary.withValues(alpha: 0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.dashboard_rounded,
                              color: colorScheme.onPrimary,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'CRM',
                            style:
                                textTheme.headlineLarge?.copyWith(
                                  color: textPrimary,
                                ) ??
                                TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Welcome back! Please login to continue',
                            style:
                                textTheme.bodySmall?.copyWith(
                                  color: textSecondary,
                                ) ??
                                TextStyle(fontSize: 14, color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                    CRMTextField(
                      label: 'Email',
                      hint: 'Enter your email',
                      controller: _emailController,
                      focusNode: _emailFocus,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Icon(Icons.email_outlined),
                      disableAutofill: true,
                      onTap: _onEmailTap,
                      onChanged: (_) {
                        setState(() => _skipSavedPickerOnNextEmailTap = false);
                        _onCredentialsChanged();
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    CRMTextField(
                      label: 'Password',
                      hint: 'Enter your password',
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      prefixIcon: const Icon(Icons.lock_outlined),
                      disableAutofill: true,
                      onChanged: (_) => _onCredentialsChanged(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                      onSubmitted: (_) => _handleLogin(),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _rememberMe = !_rememberMe;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: _rememberMe,
                                onChanged: (v) {
                                  setState(() {
                                    _rememberMe = v ?? false;
                                  });
                                },
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Remember this account on this device',
                                style: textTheme.bodyMedium?.copyWith(
                                      color: textPrimary,
                                    ) ??
                                    TextStyle(fontSize: 14, color: textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (showLoginWarning) ...[
                      const SizedBox(height: 16),
                      Material(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: colorScheme.onErrorContainer,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  authState.error!.isNotEmpty
                                      ? authState.error!
                                      : 'Could not sign in. Check your email and password.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: colorScheme.onErrorContainer,
                                        height: 1.35,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ForgotPasswordPage(),
                            ),
                          );
                        },
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(color: colorScheme.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    CRMButton(
                      text: 'Login',
                      isFullWidth: true,
                      isLoading: authState.status == AuthStatus.loading,
                      onPressed: _handleLogin,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
