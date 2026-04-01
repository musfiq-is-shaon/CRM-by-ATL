import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      await ref
          .read(authProvider.notifier)
          .login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
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
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.email_outlined),
                  onChanged: (_) => _onCredentialsChanged(),
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
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  prefixIcon: const Icon(Icons.lock_outlined),
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
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
