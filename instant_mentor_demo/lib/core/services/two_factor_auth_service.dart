import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';

import '../services/supabase_service.dart';

class TwoFactorAuthService {
  static TwoFactorAuthService? _instance;
  static TwoFactorAuthService get instance =>
      _instance ??= TwoFactorAuthService._();

  TwoFactorAuthService._();

  final SupabaseService _supabase = SupabaseService.instance;

  /// Check if user has 2FA enabled
  Future<bool> isMFAEnabled() async {
    try {
      final user = _supabase.currentUser;
      if (user == null) return false;

      final meta = user.userMetadata ?? {};
      return meta['mfa_enabled'] == true;
    } catch (e) {
      debugPrint('Error checking MFA status: $e');
      return false;
    }
  }

  /// Generate TOTP secret and QR code URI
  Future<Map<String, dynamic>?> generateTOTPSecret() async {
    try {
      final user = _supabase.currentUser;
      if (user == null) return null;

      // Generate a random 32-character base32 secret
      final random = Random.secure();
      final secretBytes = List<int>.generate(20, (_) => random.nextInt(256));
      final secret =
          base64.encode(secretBytes).replaceAll('=', '').substring(0, 32);

      // Create TOTP URI for QR code
      final issuer = 'InstantMentor';
      final accountName = user.email ?? 'user';
      final uri =
          'otpauth://totp/$issuer:$accountName?secret=$secret&issuer=$issuer';

      return {
        'secret': secret,
        'uri': uri,
        'account_name': accountName,
        'issuer': issuer,
      };
    } catch (e) {
      debugPrint('Error generating TOTP secret: $e');
      return null;
    }
  }

  /// Verify TOTP code using HMAC-SHA1
  bool _verifyTOTP(String secret, String code) {
    try {
      // Decode base32 secret (simplified - in production use a proper base32 decoder)
      final secretBytes = base64.decode(base64.normalize(secret + '==='));

      // Get current time window (30 seconds)
      final time = DateTime.now().millisecondsSinceEpoch ~/ 1000 ~/ 30;

      // Try current and adjacent time windows for clock skew tolerance
      for (int i = -1; i <= 1; i++) {
        final timeBytes = _intToBytes(time + i);
        final hmac = Hmac(sha1, secretBytes);
        final hash = hmac.convert(timeBytes).bytes;

        // Dynamic truncation
        final offset = hash[hash.length - 1] & 0xf;
        final binary = ((hash[offset] & 0x7f) << 24) |
            ((hash[offset + 1] & 0xff) << 16) |
            ((hash[offset + 2] & 0xff) << 8) |
            (hash[offset + 3] & 0xff);

        final otp = (binary % 1000000).toString().padLeft(6, '0');

        if (otp == code) {
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error verifying TOTP: $e');
      return false;
    }
  }

  List<int> _intToBytes(int value) {
    final bytes = List<int>.filled(8, 0);
    for (int i = 7; i >= 0; i--) {
      bytes[i] = value & 0xff;
      value >>= 8;
    }
    return bytes;
  }

  /// Verify TOTP code and enable 2FA
  Future<bool> verifyAndEnableMFA(String secret, String code) async {
    try {
      // Verify the code
      final isValid = _verifyTOTP(secret, code);
      if (!isValid) return false;

      // Update user metadata to enable MFA
      final user = _supabase.currentUser;
      if (user == null) return false;

      final updatedMeta = {
        ...user.userMetadata ?? {},
        'mfa_enabled': true,
        'mfa_secret': secret,
        'mfa_type': 'totp',
      };

      await _supabase.client.auth.updateUser(
        UserAttributes(data: updatedMeta),
      );

      return true;
    } catch (e) {
      debugPrint('Error enabling MFA: $e');
      return false;
    }
  }

  /// Verify TOTP code for login
  Future<bool> verifyMFAForLogin(String code) async {
    try {
      final user = _supabase.currentUser;
      if (user == null) return false;

      final meta = user.userMetadata ?? {};
      final secret = meta['mfa_secret'] as String?;
      if (secret == null) return false;

      return _verifyTOTP(secret, code);
    } catch (e) {
      debugPrint('Error verifying MFA: $e');
      return false;
    }
  }

  /// Disable 2FA
  Future<bool> disableMFA() async {
    try {
      final user = _supabase.currentUser;
      if (user == null) return false;

      final updatedMeta = {
        ...user.userMetadata ?? {},
        'mfa_enabled': false,
        'mfa_secret': null,
        'mfa_type': null,
      };

      await _supabase.client.auth.updateUser(
        UserAttributes(data: updatedMeta),
      );

      return true;
    } catch (e) {
      debugPrint('Error disabling MFA: $e');
      return false;
    }
  }
}
