import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart'; // Use Supabase auth provider
import '../../../core/routing/routing.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../common/widgets/enhanced_form_fields.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isStudent = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _handleSignup() async {
    debugPrint('SignupScreen: _handleSignup called');

    // Prevent multiple signup attempts
    final authState = ref.read(authProvider);
    if (authState.isLoading) {
      debugPrint(
          'SignupScreen: Already processing signup, ignoring duplicate request');
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      debugPrint('SignupScreen: Form validation failed');
      return;
    }

    final role = _isStudent ? 'student' : 'mentor';
    debugPrint('SignupScreen: Form validation passed, creating account...');
    debugPrint('SignupScreen: Email: ${_emailController.text}');
    debugPrint('SignupScreen: Name: ${_nameController.text}');
    debugPrint('SignupScreen: Role: $role');

    try {
      debugPrint('🔵 SignupScreen: Starting signup process...');
      await ref.read(authProvider.notifier).signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        additionalData: {
          'role': role,
        },
      );

      final authState = ref.read(authProvider);
      debugPrint(
          '🔵 SignupScreen: Auth state after signup - isAuthenticated: ${authState.isAuthenticated}, isNewMentorSignup: ${authState.isNewMentorSignup}, error: ${authState.error}');

      if (authState.isAuthenticated) {
        debugPrint(
            '✅ SignupScreen: Signup completed successfully - user authenticated');

        if (role == 'mentor' && authState.isNewMentorSignup) {
          debugPrint(
              '🎯 SignupScreen: New mentor account created - router should redirect to onboarding');
          // For testing, let's manually trigger the navigation if router doesn't handle it
          Future.delayed(const Duration(milliseconds: 500), () {
            if (context.mounted) {
              debugPrint('🔄 SignupScreen: Manually navigating to onboarding');
              context.go('/mentor/onboarding');
            }
          });
        } else if (role == 'student' && authState.isNewStudentSignup) {
          debugPrint(
              '🎯 SignupScreen: New student account created - router should redirect to onboarding');
          Future.delayed(const Duration(milliseconds: 500), () {
            if (context.mounted) {
              debugPrint(
                  '🔄 SignupScreen: Manually navigating to student onboarding');
              context.go('/student/onboarding');
            }
          });
        } else {
          debugPrint(
              '🏠 SignupScreen: Student account created - router will redirect to home');
        }
      } else if (authState.error != null) {
        debugPrint('❌ SignupScreen: Error during signup: ${authState.error}');

        // Check if it's an email confirmation requirement
        if (authState.error!.contains('email confirmation') ||
            authState.error!.contains('confirm') ||
            authState.error!.contains('verification')) {
          debugPrint('📧 SignupScreen: Email confirmation required');

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Account created successfully!'),
                    const Text(
                        'Please check your email to confirm your account.'),
                    if (role == 'mentor')
                      const Text(
                          'After confirmation, you\'ll be guided through mentor setup.'),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 5),
              ),
            );

            // Navigate back to login after delay
            Future.delayed(const Duration(seconds: 4), () {
              if (context.mounted) {
                context.go('/login');
              }
            });
          }
        } else if (authState.error!.contains('already exists') ||
            authState.error!.contains('already registered')) {
          // Account already exists - suggest login
          debugPrint('👤 SignupScreen: Account already exists');

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Account already exists!'),
                    Text('Please sign in with your existing account.'),
                  ],
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Sign In',
                  textColor: Colors.white,
                  onPressed: () {
                    context.go('/login');
                  },
                ),
              ),
            );

            // Auto-navigate to login after delay
            Future.delayed(const Duration(seconds: 3), () {
              if (context.mounted) {
                context.go('/login');
              }
            });
          }
        } else {
          // Some other error - display it
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Signup failed: ${authState.error}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } else {
        debugPrint(
            '⚠️ SignupScreen: Signup completed but unclear state - not authenticated and no error');
        // Try to force authentication check or navigate to login
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Account may have been created. Please try signing in.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          Future.delayed(const Duration(seconds: 2), () {
            if (context.mounted) {
              context.go('/login');
            }
          });
        }
      }
    } catch (error, stackTrace) {
      debugPrint('💥 SignupScreen: Signup failed with exception: $error');
      debugPrint('Stack trace: $stackTrace');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signup failed: ${error.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return LoadingOverlay(
      isLoading: authState.isLoading,
      message: 'Creating your account...',
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
                    'Create Account',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Join InstantMentor and start your journey',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Role Selection
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      border: Border.all(
                          color: colorScheme.outline.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Select your role',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _RoleSelectionButton(
                                icon: Icons.school,
                                label: 'Student',
                                isSelected: _isStudent,
                                onTap: () => setState(() => _isStudent = true),
                              ),
                            ),
                            Expanded(
                              child: _RoleSelectionButton(
                                icon: Icons.person,
                                label: 'Mentor',
                                isSelected: !_isStudent,
                                onTap: () => setState(() => _isStudent = false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

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

                  // Name Field with enhanced validation
                  NameFormField(
                    controller: _nameController,
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),

                  // Email Field with role-based validation
                  EmailFormField(
                    controller: _emailController,
                    isStudent: _isStudent,
                  ),

                  // Debug helper for testing - generate random email
                  if (kDebugMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: TextButton.icon(
                        onPressed: () {
                          final randomId =
                              DateTime.now().millisecondsSinceEpoch;
                          _emailController.text = 'test$randomId@example.com';
                        },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Generate Test Email',
                            style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Password Field with strength indicator
                  PasswordFormField(
                    controller: _passwordController,
                    showStrengthIndicator: true,
                    isSignup: true,
                  ),
                  const SizedBox(height: 32),

                  // Signup Button with loading state
                  LoadingButton(
                    isLoading: authState.isLoading,
                    onPressed: () {
                      debugPrint('SignupScreen: Create Account button pressed');
                      _handleSignup();
                    },
                    loadingText: _isStudent
                        ? 'Creating Student Account...'
                        : 'Creating Mentor Account...',
                    child: Text(_isStudent
                        ? 'Create Student Account'
                        : 'Create Mentor Account'),
                  ),
                  const SizedBox(height: 16),

                  // Login Link
                  TextButton(
                    onPressed: authState.isLoading
                        ? null
                        : () => context.go(AppRoutes.login),
                    child: const Text('Already have an account? Sign in'),
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

class _RoleSelectionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleSelectionButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor =
        isSelected ? colorScheme.primary : colorScheme.surface;
    final foregroundColor =
        isSelected ? colorScheme.onPrimary : colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Material(
        color: backgroundColor,
        elevation: isSelected ? 2 : 0,
        shadowColor: colorScheme.shadow.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : colorScheme.outline.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: foregroundColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: foregroundColor,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
