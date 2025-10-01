import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart'; // Use Supabase auth provider
import '../../../core/routing/routing.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../common/widgets/enhanced_form_fields.dart';
import '../../common/widgets/error_handler_widget.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      debugPrint('LoginScreen: Attempting login...');

      try {
        await ref.read(authProvider.notifier).signIn(
              email: _emailController.text,
              password: _passwordController.text,
            );

        // Let GoRouter handle navigation automatically via redirect
        debugPrint(
            'LoginScreen: Login completed, GoRouter will handle navigation');
      } catch (error, stackTrace) {
        // Handle and show error using global error system only if widget is still mounted
        if (mounted) {
          ErrorUtils.handleAndShowError(ref, error, stackTrace);
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();

    // Clear any existing errors when login screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).clearError();
    });

    // Clear any existing errors when user starts typing
    _emailController.addListener(() {
      final authState = ref.read(authProvider);
      if (authState.error != null) {
        ref.read(authProvider.notifier).clearError();
      }
    });

    _passwordController.addListener(() {
      final authState = ref.read(authProvider);
      if (authState.error != null) {
        ref.read(authProvider.notifier).clearError();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return LoadingOverlay(
      isLoading: authState.isLoading,
      message: 'Signing in...',
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),
                  Text(
                    'Welcome Back',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue your learning journey',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Error Display
                  if (authState.error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red.shade600,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              authState.error!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Email Field with enhanced validation
                  EnhancedTextFormField(
                    controller: _emailController,
                    label: 'Email',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$')
                          .hasMatch(value!)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Field with enhanced styling
                  PasswordFormField(
                    controller: _passwordController,
                    label: 'Password',
                  ),
                  const SizedBox(height: 32),

                  // Login Button with loading state
                  LoadingButton(
                    isLoading: authState.isLoading,
                    onPressed: _handleLogin,
                    loadingText: 'Signing in...',
                    child: const Text('Sign In'),
                  ),
                  const SizedBox(height: 16),

                  // Signup Link
                  TextButton(
                    onPressed: authState.isLoading
                        ? null
                        : () => context.go(AppRoutes.signup),
                    child: const Text('Don\'t have an account? Sign up'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
