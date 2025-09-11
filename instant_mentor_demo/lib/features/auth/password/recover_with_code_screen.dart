import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../common/widgets/error_handler_widget.dart';

class RecoverWithCodeScreen extends ConsumerStatefulWidget {
  const RecoverWithCodeScreen({super.key});

  @override
  ConsumerState<RecoverWithCodeScreen> createState() => _RecoverWithCodeScreenState();
}

class _RecoverWithCodeScreenState extends ConsumerState<RecoverWithCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _codeSent = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
  _cooldownTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email first')),
      );
      return;
    }
    final emailRe = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    if (!emailRe.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email')),
      );
      return;
    }

    try {
      // Use existing OTP email flow to authenticate, then we can set a new password
      await ref.read(authProvider.notifier).sendEmailOTP(email, shouldCreateUser: false);
      if (mounted) {
        setState(() => _codeSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification code sent. Check your inbox.')),
        );
        _startCooldown();
      }
    } catch (e, st) {
      ErrorUtils.handleAndShowError(ref, e, st);
    }
  }

  void _startCooldown() {
    setState(() => _cooldown = 30);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown -= 1);
      }
    });
  }

  Future<void> _resendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    try {
      await ref.read(authProvider.notifier).resendEmailOTP(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code resent. Check your inbox.')),
        );
        _startCooldown();
      }
    } catch (e, st) {
      ErrorUtils.handleAndShowError(ref, e, st);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    try {
      // 1) Verify OTP to sign in (temporary session)
      await ref
          .read(authProvider.notifier)
          .verifyEmailOTP(email: _emailController.text.trim(), otp: _codeController.text.trim());

      // 2) Set new password for the now-authenticated user
      await ref.read(authProvider.notifier).setNewPassword(_passwordController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated. You are signed in.')),
        );
        context.go('/');
      }
    } catch (e, st) {
      ErrorUtils.handleAndShowError(ref, e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recover with Code')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please enter your email';
                  final email = v.trim();
                  final emailRe = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
                  if (!emailRe.hasMatch(email)) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        labelText: 'Verification Code',
                        prefixIcon: Icon(Icons.verified_outlined),
                      ),
                      validator: (v) {
                        if (!_codeSent) return null; // allow before sending
                        if (v == null || v.trim().isEmpty) return 'Enter the code from email';
                        if (v.trim().length < 4) return 'Code looks too short';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: auth.isLoading ? null : _sendCode,
                    child: auth.isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Send Code'),
                  ),
                ],
              ),
              if (_codeSent) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: (auth.isLoading || _cooldown > 0) ? null : _resendCode,
                      child: Text(_cooldown > 0 ? 'Resend in $_cooldown s' : 'Resend code'),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Use the same email you signed up with. Codes aren\'t sent if the account does not exist.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) {
                  if (!_codeSent) return null; // allow before sending
                  if (v == null || v.isEmpty) return 'Please enter a password';
                  if (v.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (v) {
                  if (!_codeSent) return null; // allow before sending
                  if (v == null || v.isEmpty) return 'Please confirm your password';
                  if (v != _passwordController.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: auth.isLoading ? null : _submit,
                child: auth.isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Verify & Update Password'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/forgot-password'),
                child: const Text('Use reset link instead'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
