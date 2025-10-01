import 'package:flutter/material.dart';
import '../../../core/utils/form_validators.dart';

/// Enhanced text form field with improved styling and validation
class EnhancedTextFormField extends StatefulWidget {
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final void Function(String?)? onSaved;
  final void Function(String)? onChanged;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final String? helperText;
  final bool showCharacterCount;
  final int? maxLength;
  final bool autofocus;
  final FocusNode? focusNode;

  const EnhancedTextFormField({
    super.key,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.controller,
    this.validator,
    this.onSaved,
    this.onChanged,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.helperText,
    this.showCharacterCount = false,
    this.maxLength,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<EnhancedTextFormField> createState() => _EnhancedTextFormFieldState();
}

class _EnhancedTextFormFieldState extends State<EnhancedTextFormField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      onSaved: widget.onSaved,
      onChanged: widget.onChanged,
      enabled: widget.enabled,
      obscureText: _obscureText,
      keyboardType: widget.keyboardType,
      maxLines: _obscureText ? 1 : widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      autofillHints: const [],
      style: TextStyle(
        color: widget.enabled
            ? colorScheme.onSurface
            : colorScheme.onSurface.withOpacity(0.6),
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helperText,
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon, color: colorScheme.primary)
            : null,
        suffixIcon: _buildSuffixIcon(),
        labelStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
        hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
        counterText: widget.showCharacterCount ? null : '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.5)),
        ),
        filled: true,
        fillColor: widget.enabled
            ? colorScheme.surface
            : colorScheme.surface.withOpacity(0.5),
      ),
    );
  }

  Widget? _buildSuffixIcon() {
    if (widget.obscureText) {
      return IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility : Icons.visibility_off,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      );
    }

    if (widget.suffixIcon != null) {
      return Icon(
        widget.suffixIcon,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
      );
    }

    return null;
  }
}

/// Email form field with @student.com validation only
class EmailFormField extends StatefulWidget {
  final TextEditingController? controller;
  final bool isStudent;
  final bool required;
  final void Function(String)? onChanged;
  final bool autofocus;

  const EmailFormField({
    super.key,
    this.controller,
    required this.isStudent,
    this.required = true,
    this.onChanged,
    this.autofocus = false,
  });

  @override
  State<EmailFormField> createState() => _EmailFormFieldState();
}

class _EmailFormFieldState extends State<EmailFormField> {
  bool _hasInteracted = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && !_hasInteracted) {
        setState(() {
          _hasInteracted = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EnhancedTextFormField(
      controller: widget.controller,
      label: 'Email',
      prefixIcon: Icons.email_outlined,
      keyboardType: TextInputType.emailAddress,
      autofocus: widget.autofocus,
      focusNode: _focusNode,
      validator: (value) =>
          FormValidators.email(value, required: widget.required),
      onChanged: (value) {
        if (value.isNotEmpty && !_hasInteracted) {
          setState(() {
            _hasInteracted = true;
          });
        }
        widget.onChanged?.call(value);
      },
    );
  }
}

/// Password form field with strength indicator
class PasswordFormField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final bool required;
  final bool showStrengthIndicator;
  final bool isSignup;
  final void Function(String)? onChanged;

  const PasswordFormField({
    super.key,
    this.controller,
    this.label,
    this.required = true,
    this.showStrengthIndicator = false,
    this.isSignup = false,
    this.onChanged,
  });

  @override
  State<PasswordFormField> createState() => _PasswordFormFieldState();
}

class _PasswordFormFieldState extends State<PasswordFormField> {
  PasswordStrength _strength = PasswordStrength.weak;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EnhancedTextFormField(
          controller: widget.controller,
          label: widget.label ?? 'Password',
          hint: 'Enter your password',
          prefixIcon: Icons.lock_outline,
          obscureText: true,
          validator: widget.isSignup
              ? (value) => FormValidators.strongPassword(value,
                  required: widget.required)
              : (value) =>
                  FormValidators.password(value, required: widget.required),
          onChanged: (value) {
            if (widget.showStrengthIndicator) {
              setState(() {
                _strength = PasswordStrengthChecker.getStrength(value);
              });
            }
            widget.onChanged?.call(value);
          },
          helperText: widget.isSignup
              ? 'Must contain uppercase, lowercase, and numbers'
              : null,
        ),
        if (widget.showStrengthIndicator) ...[
          const SizedBox(height: 8),
          _buildStrengthIndicator(),
        ],
      ],
    );
  }

  Widget _buildStrengthIndicator() {
    final progress = PasswordStrengthChecker.getStrengthProgress(_strength);
    final color = PasswordStrengthChecker.getStrengthColor(_strength);
    final text = PasswordStrengthChecker.getStrengthText(_strength);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Confirm password form field
class ConfirmPasswordFormField extends StatelessWidget {
  final TextEditingController? controller;
  final String? originalPassword;
  final bool required;

  const ConfirmPasswordFormField({
    super.key,
    this.controller,
    required this.originalPassword,
    this.required = true,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedTextFormField(
      controller: controller,
      label: 'Confirm Password',
      hint: 'Re-enter your password',
      prefixIcon: Icons.lock_outline,
      obscureText: true,
      validator: (value) => FormValidators.confirmPassword(
          value, originalPassword,
          required: required),
    );
  }
}

/// Name form field with proper validation
class NameFormField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final bool required;
  final void Function(String)? onChanged;
  final bool autofocus;

  const NameFormField({
    super.key,
    this.controller,
    this.label,
    this.required = true,
    this.onChanged,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedTextFormField(
      controller: controller,
      label: label ?? 'Full Name',
      hint: 'Enter your full name',
      prefixIcon: Icons.person_outline,
      keyboardType: TextInputType.name,
      autofocus: autofocus,
      validator: (value) => FormValidators.name(value, required: required),
      onChanged: onChanged,
    );
  }
}
