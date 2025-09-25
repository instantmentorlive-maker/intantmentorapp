import 'package:flutter/material.dart';

/// Enhanced form validation utilities
class FormValidators {
  /// Email validation with various options
  static String? email(
    String? value, {
    bool required = true,
    List<String>? allowedDomains,
    List<String>? blockedDomains,
  }) {
    if (value == null || value.isEmpty) {
      return required ? 'Email is required' : null;
    }

    // Basic email format validation
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }

    final lowerValue = value.toLowerCase();

    // Check allowed domains
    if (allowedDomains != null && allowedDomains.isNotEmpty) {
      final bool isAllowed =
          allowedDomains.any((domain) => lowerValue.endsWith(domain));
      if (!isAllowed) {
        return 'Email must end with: ${allowedDomains.join(', ')}';
      }
    }

    // Check blocked domains
    if (blockedDomains != null && blockedDomains.isNotEmpty) {
      final bool isBlocked =
          blockedDomains.any((domain) => lowerValue.endsWith(domain));
      if (isBlocked) {
        return 'Email domain is not allowed: ${blockedDomains.join(', ')}';
      }
    }

    return null;
  }

  /// Student email validation
  static String? studentEmail(String? value, {bool required = true}) {
    return email(value, required: required, allowedDomains: ['@student.com']);
  }

  /// Mentor email validation
  static String? mentorEmail(String? value, {bool required = true}) {
    return email(value, required: required, allowedDomains: ['@mentor.com']);
  }

  /// Role-based email validation
  static String? roleBasedEmail(String? value, bool isStudent,
      {bool required = true}) {
    return isStudent
        ? studentEmail(value, required: required)
        : mentorEmail(value, required: required);
  }

  /// Password validation with strength requirements
  static String? password(
    String? value, {
    bool required = true,
    int minLength = 6,
    int maxLength = 50,
    bool requireUppercase = false,
    bool requireLowercase = false,
    bool requireNumbers = false,
    bool requireSpecialChars = false,
  }) {
    if (value == null || value.isEmpty) {
      return required ? 'Password is required' : null;
    }

    if (value.length < minLength) {
      return 'Password must be at least $minLength characters long';
    }

    if (value.length > maxLength) {
      return 'Password must be no more than $maxLength characters long';
    }

    if (requireUppercase && !RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }

    if (requireLowercase && !RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }

    if (requireNumbers && !RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }

    if (requireSpecialChars &&
        !RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Password must contain at least one special character';
    }

    return null;
  }

  /// Strong password validation for signup
  static String? strongPassword(String? value, {bool required = true}) {
    return password(
      value,
      required: required,
      minLength: 8,
      requireUppercase: true,
      requireLowercase: true,
      requireNumbers: true,
    );
  }

  /// Confirm password validation
  static String? confirmPassword(String? value, String? originalPassword,
      {bool required = true}) {
    if (value == null || value.isEmpty) {
      return required ? 'Please confirm your password' : null;
    }

    if (value != originalPassword) {
      return 'Passwords do not match';
    }

    return null;
  }

  /// Name validation
  static String? name(
    String? value, {
    bool required = true,
    int minLength = 2,
    int maxLength = 50,
    bool allowNumbers = false,
    bool allowSpecialChars = false,
  }) {
    if (value == null || value.isEmpty) {
      return required ? 'Name is required' : null;
    }

    final trimmed = value.trim();

    if (trimmed.length < minLength) {
      return 'Name must be at least $minLength characters long';
    }

    if (trimmed.length > maxLength) {
      return 'Name must be no more than $maxLength characters long';
    }

    if (!allowNumbers && RegExp(r'[0-9]').hasMatch(trimmed)) {
      return 'Name cannot contain numbers';
    }

    if (!allowSpecialChars &&
        RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(trimmed)) {
      return 'Name cannot contain special characters';
    }

    // Check for only letters, spaces, apostrophes, and hyphens
    if (!RegExp(r"^[a-zA-Z\s'\-]+$").hasMatch(trimmed)) {
      return 'Name can only contain letters, spaces, apostrophes, and hyphens';
    }

    return null;
  }

  /// Phone number validation
  static String? phoneNumber(String? value, {bool required = true}) {
    if (value == null || value.isEmpty) {
      return required ? 'Phone number is required' : null;
    }

    // Remove all non-digit characters for validation
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.length < 10 || digitsOnly.length > 15) {
      return 'Please enter a valid phone number';
    }

    return null;
  }

  /// Generic required field validation
  static String? required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Minimum length validation
  static String? minLength(String? value, int min, String fieldName) {
    if (value == null || value.length < min) {
      return '$fieldName must be at least $min characters long';
    }
    return null;
  }

  /// Maximum length validation
  static String? maxLength(String? value, int max, String fieldName) {
    if (value != null && value.length > max) {
      return '$fieldName must be no more than $max characters long';
    }
    return null;
  }

  /// Combine multiple validators
  static String? Function(String?) combine(
      List<String? Function(String?)> validators) {
    return (value) {
      for (final validator in validators) {
        final result = validator(value);
        if (result != null) return result;
      }
      return null;
    };
  }
}

/// Password strength indicator
enum PasswordStrength { weak, fair, good, strong }

class PasswordStrengthChecker {
  static PasswordStrength getStrength(String password) {
    int score = 0;

    // Length check
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;

    // Character type checks
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;

    switch (score) {
      case 0:
      case 1:
      case 2:
        return PasswordStrength.weak;
      case 3:
      case 4:
        return PasswordStrength.fair;
      case 5:
        return PasswordStrength.good;
      default:
        return PasswordStrength.strong;
    }
  }

  static String getStrengthText(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.fair:
        return 'Fair';
      case PasswordStrength.good:
        return 'Good';
      case PasswordStrength.strong:
        return 'Strong';
    }
  }

  static Color getStrengthColor(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return const Color(0xFFFF5252);
      case PasswordStrength.fair:
        return const Color(0xFFFF9800);
      case PasswordStrength.good:
        return const Color(0xFF4CAF50);
      case PasswordStrength.strong:
        return const Color(0xFF2E7D32);
    }
  }

  static double getStrengthProgress(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.weak:
        return 0.25;
      case PasswordStrength.fair:
        return 0.5;
      case PasswordStrength.good:
        return 0.75;
      case PasswordStrength.strong:
        return 1.0;
    }
  }
}
