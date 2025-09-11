import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/routing.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../../core/providers/auth_provider.dart'; // Use Supabase auth provider
import '../../common/widgets/error_handler_widget.dart';
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
    if (_formKey.currentState?.validate() ?? false) {
      debugPrint('SignupScreen: Attempting to send OTP...');

      try {
        // Send OTP to email for verification
        await ref
            .read(authProvider.notifier)
            .sendEmailOTP(_emailController.text);

        // Navigate to OTP verification screen with signup data
        if (mounted) {
          context.go(
              '/otp-verification?email=${_emailController.text}&type=email&signup=true&password=${_passwordController.text}&name=${_nameController.text}&role=${_isStudent ? 'student' : 'mentor'}');
        }

        debugPrint('SignupScreen: OTP sent, navigating to verification');
      } catch (error, stackTrace) {
        // Handle and show error using global error system
        ErrorUtils.handleAndShowError(ref, error, stackTrace);
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
                    onPressed: _handleSignup,
                    loadingText: 'Creating Account...',
                    child: const Text('Create Account'),
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
                width: 1,
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
