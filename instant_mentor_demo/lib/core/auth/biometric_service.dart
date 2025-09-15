import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../utils/logger.dart';
import '../utils/result.dart';
import '../error/app_error.dart';

/// Service for handling biometric authentication
class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  
  /// Check if biometric authentication is available on device
  Future<Result<bool>> isAvailable() async {
    try {
      final bool isAvailable = await _localAuth.isDeviceSupported();
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      
      final result = isAvailable && canCheckBiometrics;
      Logger.info('BiometricService: Biometric availability - $result');
      
      return Success(result);
    } catch (e) {
      Logger.error('BiometricService: Error checking availability - $e');
      return Failure(
        AppGeneralError.unknown('Failed to check biometric availability: $e'),
      );
    }
  }
  
  /// Get list of available biometric types
  Future<Result<List<BiometricType>>> getAvailableBiometrics() async {
    try {
      final List<BiometricType> availableBiometrics = 
          await _localAuth.getAvailableBiometrics();
      
      Logger.info('BiometricService: Available biometrics - $availableBiometrics');
      return Success(availableBiometrics);
    } catch (e) {
      Logger.error('BiometricService: Error getting available biometrics - $e');
      return Failure(
        AppGeneralError.unknown('Failed to get available biometrics: $e'),
      );
    }
  }
  
  /// Authenticate using biometrics
  Future<Result<bool>> authenticate({
    required String reason,
    bool useErrorDialogs = true,
    bool stickyAuth = true,
    bool biometricOnly = false,
  }) async {
    try {
      // Check if biometric authentication is available
      final availabilityResult = await isAvailable();
      if (availabilityResult.isFailure || !availabilityResult.data!) {
        Logger.warning('BiometricService: Biometric authentication not available');
        return const Failure(
          AuthError(
            message: 'Biometric authentication is not available on this device.',
            code: 'BIOMETRIC_NOT_AVAILABLE',
          ),
        );
      }

      Logger.info('BiometricService: Starting biometric authentication');
      
      final bool authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: biometricOnly,
        ),
      );

      if (authenticated) {
        Logger.info('BiometricService: Authentication successful');
        return const Success(true);
      } else {
        Logger.warning('BiometricService: Authentication failed or cancelled');
        return const Failure(
          AuthError(
            message: 'Biometric authentication failed. Please try again.',
            code: 'BIOMETRIC_AUTH_FAILED',
          ),
        );
      }
    } on PlatformException catch (e) {
      Logger.error('BiometricService: Platform exception - ${e.code}: ${e.message}');
      
      switch (e.code) {
        case 'NotEnrolled':
          return const Failure(
            AuthError(
              message: 'No biometrics are enrolled on this device. Please set up fingerprint or face recognition in your device settings.',
              code: 'BIOMETRIC_NOT_ENROLLED',
            ),
          );
        case 'NotAvailable':
          return const Failure(
            AuthError(
              message: 'Biometric authentication is not available on this device.',
              code: 'BIOMETRIC_NOT_AVAILABLE',
            ),
          );
        case 'PasscodeNotSet':
          return const Failure(
            AuthError(
              message: 'Device passcode is not set. Please set up a screen lock in your device settings.',
              code: 'BIOMETRIC_PASSCODE_NOT_SET',
            ),
          );
        case 'LockedOut':
          return const Failure(
            AuthError(
              message: 'Biometric authentication is temporarily locked. Please try again later or use your passcode.',
              code: 'BIOMETRIC_LOCKED_OUT',
            ),
          );
        case 'PermanentlyLockedOut':
          return const Failure(
            AuthError(
              message: 'Biometric authentication is permanently locked. Please use your passcode.',
              code: 'BIOMETRIC_PERMANENTLY_LOCKED_OUT',
            ),
          );
        default:
          return Failure(
            AuthError(
              message: e.message ?? 'Unknown biometric error',
              code: 'BIOMETRIC_AUTH_FAILED',
            ),
          );
      }
    } catch (e) {
      Logger.error('BiometricService: Unexpected error - $e');
      return Failure(
        AppGeneralError.unknown('Biometric authentication error: $e'),
      );
    }
  }
  
  /// Check if device has enrolled biometrics
  Future<Result<bool>> hasEnrolledBiometrics() async {
    try {
      final biometricsResult = await getAvailableBiometrics();
      if (biometricsResult.isFailure) {
        return Failure(biometricsResult.error!);
      }
      
      final hasEnrolled = biometricsResult.data!.isNotEmpty;
      Logger.info('BiometricService: Has enrolled biometrics - $hasEnrolled');
      
      return Success(hasEnrolled);
    } catch (e) {
      Logger.error('BiometricService: Error checking enrolled biometrics - $e');
      return Failure(
        AppGeneralError.unknown('Failed to check enrolled biometrics: $e'),
      );
    }
  }
  
  /// Get user-friendly description of available biometric types
  String getBiometricTypeDescription(List<BiometricType> biometrics) {
    if (biometrics.isEmpty) return 'No biometrics available';
    
    final descriptions = <String>[];
    if (biometrics.contains(BiometricType.fingerprint)) {
      descriptions.add('Fingerprint');
    }
    if (biometrics.contains(BiometricType.face)) {
      descriptions.add('Face ID');
    }
    if (biometrics.contains(BiometricType.iris)) {
      descriptions.add('Iris');
    }
    if (biometrics.contains(BiometricType.strong)) {
      descriptions.add('Strong Biometric');
    }
    if (biometrics.contains(BiometricType.weak)) {
      descriptions.add('Weak Biometric');
    }
    
    if (descriptions.isEmpty) return 'Biometric authentication';
    if (descriptions.length == 1) return descriptions.first;
    if (descriptions.length == 2) return descriptions.join(' or ');
    
    return '${descriptions.take(descriptions.length - 1).join(', ')}, or ${descriptions.last}';
  }
}
