import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

/// Biometric authentication types available
enum BiometricType {
  fingerprint,
  face,
  iris,
  voice,
  weak,
  strong,
}

/// Authentication strength levels
enum AuthenticationStrength {
  weak,
  strong,
  deviceCredential,
}

/// Biometric authentication result
class BiometricAuthResult {
  final bool isAuthenticated;
  final String? errorMessage;
  final BiometricType? authenticationType;
  final AuthenticationStrength? strength;
  final String? sessionToken;

  const BiometricAuthResult({
    required this.isAuthenticated,
    this.errorMessage,
    this.authenticationType,
    this.strength,
    this.sessionToken,
  });

  factory BiometricAuthResult.success({
    BiometricType? type,
    AuthenticationStrength? strength,
    String? sessionToken,
  }) {
    return BiometricAuthResult(
      isAuthenticated: true,
      authenticationType: type,
      strength: strength,
      sessionToken: sessionToken,
    );
  }

  factory BiometricAuthResult.failure(String errorMessage) {
    return BiometricAuthResult(
      isAuthenticated: false,
      errorMessage: errorMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isAuthenticated': isAuthenticated,
      'errorMessage': errorMessage,
      'authenticationType': authenticationType?.name,
      'strength': strength?.name,
      'sessionToken': sessionToken,
    };
  }
}

/// Biometric capability information
class BiometricCapability {
  final bool isAvailable;
  final bool isDeviceSupported;
  final List<BiometricType> availableTypes;
  final bool canCheckBiometrics;
  final String? unavailabilityReason;

  const BiometricCapability({
    required this.isAvailable,
    required this.isDeviceSupported,
    required this.availableTypes,
    required this.canCheckBiometrics,
    this.unavailabilityReason,
  });

  Map<String, dynamic> toJson() {
    return {
      'isAvailable': isAvailable,
      'isDeviceSupported': isDeviceSupported,
      'availableTypes': availableTypes.map((t) => t.name).toList(),
      'canCheckBiometrics': canCheckBiometrics,
      'unavailabilityReason': unavailabilityReason,
    };
  }
}

/// Authentication policy configuration
class AuthenticationPolicy {
  final bool allowFingerprintAuth;
  final bool allowFaceAuth;
  final bool allowDeviceCredential;
  final bool requireBiometricAuth;
  final Duration sessionTimeout;
  final int maxRetryAttempts;
  final Duration lockoutDuration;
  final bool enableProgressiveAuth;

  const AuthenticationPolicy({
    this.allowFingerprintAuth = true,
    this.allowFaceAuth = true,
    this.allowDeviceCredential = true,
    this.requireBiometricAuth = false,
    this.sessionTimeout = const Duration(minutes: 15),
    this.maxRetryAttempts = 3,
    this.lockoutDuration = const Duration(minutes: 5),
    this.enableProgressiveAuth = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'allowFingerprintAuth': allowFingerprintAuth,
      'allowFaceAuth': allowFaceAuth,
      'allowDeviceCredential': allowDeviceCredential,
      'requireBiometricAuth': requireBiometricAuth,
      'sessionTimeoutMinutes': sessionTimeout.inMinutes,
      'maxRetryAttempts': maxRetryAttempts,
      'lockoutDurationMinutes': lockoutDuration.inMinutes,
      'enableProgressiveAuth': enableProgressiveAuth,
    };
  }

  factory AuthenticationPolicy.fromJson(Map<String, dynamic> json) {
    return AuthenticationPolicy(
      allowFingerprintAuth: json['allowFingerprintAuth'] ?? true,
      allowFaceAuth: json['allowFaceAuth'] ?? true,
      allowDeviceCredential: json['allowDeviceCredential'] ?? true,
      requireBiometricAuth: json['requireBiometricAuth'] ?? false,
      sessionTimeout: Duration(minutes: json['sessionTimeoutMinutes'] ?? 15),
      maxRetryAttempts: json['maxRetryAttempts'] ?? 3,
      lockoutDuration: Duration(minutes: json['lockoutDurationMinutes'] ?? 5),
      enableProgressiveAuth: json['enableProgressiveAuth'] ?? true,
    );
  }
}

/// Biometric authentication session
class BiometricSession {
  final String sessionId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final BiometricType authenticationType;
  final AuthenticationStrength strength;
  final Map<String, dynamic> metadata;

  const BiometricSession({
    required this.sessionId,
    required this.createdAt,
    required this.expiresAt,
    required this.authenticationType,
    required this.strength,
    this.metadata = const {},
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isValid => !isExpired;

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'authenticationType': authenticationType.name,
      'strength': strength.name,
      'metadata': metadata,
    };
  }

  factory BiometricSession.fromJson(Map<String, dynamic> json) {
    return BiometricSession(
      sessionId: json['sessionId'],
      createdAt: DateTime.parse(json['createdAt']),
      expiresAt: DateTime.parse(json['expiresAt']),
      authenticationType: BiometricType.values.firstWhere(
        (t) => t.name == json['authenticationType'],
      ),
      strength: AuthenticationStrength.values.firstWhere(
        (s) => s.name == json['strength'],
      ),
      metadata: json['metadata'] ?? {},
    );
  }
}

/// Advanced biometric authentication service
class BiometricAuthService {
  static BiometricAuthService? _instance;
  static BiometricAuthService get instance => _instance ??= BiometricAuthService._();
  
  BiometricAuthService._();

  final LocalAuthentication _localAuth = LocalAuthentication();
  
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  AuthenticationPolicy _policy = const AuthenticationPolicy();
  BiometricSession? _currentSession;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  /// Initialize the biometric authentication service
  Future<void> initialize({AuthenticationPolicy? policy}) async {
    if (policy != null) {
      _policy = policy;
      await _savePolicy();
    } else {
      await _loadPolicy();
    }
    
    await _loadSession();
    await _loadFailedAttempts();
    
    developer.log('Biometric authentication service initialized', name: 'BiometricAuthService');
  }

  /// Check biometric capabilities
  Future<BiometricCapability> checkCapabilities() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final availableBiometrics = await _localAuth.getAvailableBiometrics();

      final availableTypes = <BiometricType>[];
      String? unavailabilityReason;

      if (!isDeviceSupported) {
        unavailabilityReason = 'Device does not support biometric authentication';
      } else if (!isAvailable) {
        unavailabilityReason = 'No biometric authentication methods available';
      } else {
        for (final biometric in availableBiometrics) {
          switch (biometric) {
            case BiometricType.fingerprint:
              availableTypes.add(BiometricType.fingerprint);
              break;
            case BiometricType.face:
              availableTypes.add(BiometricType.face);
              break;
            case BiometricType.iris:
              availableTypes.add(BiometricType.iris);
              break;
            case BiometricType.weak:
              availableTypes.add(BiometricType.weak);
              break;
            case BiometricType.strong:
              availableTypes.add(BiometricType.strong);
              break;
          }
        }
      }

      final capability = BiometricCapability(
        isAvailable: isAvailable && isDeviceSupported && availableTypes.isNotEmpty,
        isDeviceSupported: isDeviceSupported,
        availableTypes: availableTypes,
        canCheckBiometrics: isAvailable,
        unavailabilityReason: unavailabilityReason,
      );

      developer.log('Biometric capabilities: ${capability.toJson()}', name: 'BiometricAuthService');
      return capability;
    } catch (e) {
      developer.log('Error checking biometric capabilities: $e', name: 'BiometricAuthService');
      return BiometricCapability(
        isAvailable: false,
        isDeviceSupported: false,
        availableTypes: const [],
        canCheckBiometrics: false,
        unavailabilityReason: 'Error checking capabilities: $e',
      );
    }
  }

  /// Authenticate using biometrics
  Future<BiometricAuthResult> authenticate({
    String localizedFallbackTitle = 'Use Passcode',
    String signInTitle = 'Sign in',
    String cancelButtonText = 'Cancel',
    bool biometricOnly = false,
    bool stickyAuth = true,
    Map<String, dynamic>? metadata,
  }) async {
    // Check if locked out
    if (_isLockedOut()) {
      final remaining = _lockoutUntil!.difference(DateTime.now());
      return BiometricAuthResult.failure(
        'Too many failed attempts. Try again in ${remaining.inMinutes} minutes.'
      );
    }

    try {
      final capabilities = await checkCapabilities();
      
      if (!capabilities.isAvailable) {
        return BiometricAuthResult.failure(
          capabilities.unavailabilityReason ?? 'Biometric authentication not available'
        );
      }

      // Determine authentication options
      final authOptions = <AuthenticationOption>[];
      
      if (_policy.allowFingerprintAuth && capabilities.availableTypes.contains(BiometricType.fingerprint)) {
        authOptions.add(AuthenticationOption.biometric);
      }
      
      if (_policy.allowFaceAuth && capabilities.availableTypes.contains(BiometricType.face)) {
        authOptions.add(AuthenticationOption.biometric);
      }
      
      if (_policy.allowDeviceCredential && !biometricOnly) {
        authOptions.add(AuthenticationOption.deviceCredential);
      }

      if (authOptions.isEmpty) {
        return BiometricAuthResult.failure('No suitable authentication methods available');
      }

      // Perform authentication
      final isAuthenticated = await _localAuth.authenticate(
        localizedFallbackTitle: localizedFallbackTitle,
        authMessages: [
          AndroidAuthMessages(
            signInTitle: signInTitle,
            cancelButton: cancelButtonText,
            biometricHint: 'Verify your identity',
            biometricNotRecognized: 'Biometric not recognized. Try again.',
            biometricRequiredTitle: 'Biometric authentication required',
            deviceCredentialsRequiredTitle: 'Device credential required',
            deviceCredentialsSetupDescription: 'Set up device credentials',
            goToSettingsButton: 'Settings',
            goToSettingsDescription: 'Go to settings to set up biometric authentication',
          ),
          IOSAuthMessages(
            cancelButton: cancelButtonText,
            goToSettingsButton: 'Settings',
            goToSettingsDescription: 'Go to settings to enable biometric authentication',
            lockOut: 'Reenable biometric authentication',
          ),
        ],
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: stickyAuth,
          useErrorDialogs: true,
        ),
      );

      if (isAuthenticated) {
        _failedAttempts = 0;
        _lockoutUntil = null;
        await _saveFailedAttempts();

        // Create session
        final session = await _createSession(
          authenticationType: _detectAuthenticationType(capabilities.availableTypes),
          strength: biometricOnly ? AuthenticationStrength.strong : AuthenticationStrength.deviceCredential,
          metadata: metadata ?? {},
        );

        developer.log('Biometric authentication successful', name: 'BiometricAuthService');

        return BiometricAuthResult.success(
          type: session.authenticationType,
          strength: session.strength,
          sessionToken: session.sessionId,
        );
      } else {
        await _handleFailedAttempt();
        return BiometricAuthResult.failure('Authentication failed');
      }
    } on PlatformException catch (e) {
      await _handleFailedAttempt();
      
      String errorMessage;
      switch (e.code) {
        case auth_error.notAvailable:
          errorMessage = 'Biometric authentication not available';
          break;
        case auth_error.notEnrolled:
          errorMessage = 'No biometric credentials enrolled';
          break;
        case auth_error.lockedOut:
          errorMessage = 'Biometric authentication locked out';
          break;
        case auth_error.permanentlyLockedOut:
          errorMessage = 'Biometric authentication permanently locked out';
          break;
        case auth_error.biometricOnlyNotSupported:
          errorMessage = 'Device credentials required';
          break;
        default:
          errorMessage = 'Authentication error: ${e.message}';
      }

      developer.log('Biometric authentication error: $errorMessage', name: 'BiometricAuthService');
      return BiometricAuthResult.failure(errorMessage);
    } catch (e) {
      await _handleFailedAttempt();
      developer.log('Unexpected biometric authentication error: $e', name: 'BiometricAuthService');
      return BiometricAuthResult.failure('Unexpected error: $e');
    }
  }

  /// Quick authentication for low-security operations
  Future<BiometricAuthResult> quickAuth({
    String reason = 'Quick authentication required',
    Map<String, dynamic>? metadata,
  }) async {
    if (_currentSession != null && _currentSession!.isValid) {
      developer.log('Using existing session for quick auth', name: 'BiometricAuthService');
      return BiometricAuthResult.success(
        type: _currentSession!.authenticationType,
        strength: _currentSession!.strength,
        sessionToken: _currentSession!.sessionId,
      );
    }

    return authenticate(
      signInTitle: reason,
      biometricOnly: false,
      stickyAuth: false,
      metadata: metadata,
    );
  }

  /// Strong authentication for high-security operations
  Future<BiometricAuthResult> strongAuth({
    String reason = 'Strong authentication required',
    Map<String, dynamic>? metadata,
  }) async {
    // Always require fresh authentication for strong auth
    await invalidateSession();

    return authenticate(
      signInTitle: reason,
      biometricOnly: true,
      stickyAuth: true,
      metadata: metadata,
    );
  }

  /// Check if current session is valid
  bool isSessionValid() {
    return _currentSession != null && _currentSession!.isValid;
  }

  /// Get current session
  BiometricSession? getCurrentSession() {
    return isSessionValid() ? _currentSession : null;
  }

  /// Invalidate current session
  Future<void> invalidateSession() async {
    _currentSession = null;
    await _secureStorage.delete(key: 'biometric_session');
    developer.log('Biometric session invalidated', name: 'BiometricAuthService');
  }

  /// Update authentication policy
  Future<void> updatePolicy(AuthenticationPolicy policy) async {
    _policy = policy;
    await _savePolicy();
    
    // Invalidate session if policy is more restrictive
    if (_currentSession != null && !_isPolicyCompatible(_currentSession!)) {
      await invalidateSession();
    }
    
    developer.log('Authentication policy updated', name: 'BiometricAuthService');
  }

  /// Get current policy
  AuthenticationPolicy getPolicy() {
    return _policy;
  }

  /// Reset failed attempts and lockout
  Future<void> resetFailedAttempts() async {
    _failedAttempts = 0;
    _lockoutUntil = null;
    await _saveFailedAttempts();
    developer.log('Failed attempts reset', name: 'BiometricAuthService');
  }

  /// Get failed attempts count
  int getFailedAttempts() {
    return _failedAttempts;
  }

  /// Check if currently locked out
  bool isLockedOut() {
    return _isLockedOut();
  }

  /// Get remaining lockout time
  Duration? getRemainingLockoutTime() {
    if (_lockoutUntil == null) return null;
    final remaining = _lockoutUntil!.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  // Private helper methods

  Future<BiometricSession> _createSession({
    required BiometricType authenticationType,
    required AuthenticationStrength strength,
    required Map<String, dynamic> metadata,
  }) async {
    final sessionId = _generateSessionId();
    final now = DateTime.now();
    final expiresAt = now.add(_policy.sessionTimeout);

    final session = BiometricSession(
      sessionId: sessionId,
      createdAt: now,
      expiresAt: expiresAt,
      authenticationType: authenticationType,
      strength: strength,
      metadata: metadata,
    );

    _currentSession = session;
    await _saveSession(session);

    return session;
  }

  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = List.generate(16, (i) => (timestamp + i) % 256);
    final bytes = sha256.convert(random).bytes;
    return base64Url.encode(bytes.take(24).toList());
  }

  BiometricType _detectAuthenticationType(List<BiometricType> availableTypes) {
    // Prefer stronger authentication types
    if (availableTypes.contains(BiometricType.face)) {
      return BiometricType.face;
    } else if (availableTypes.contains(BiometricType.fingerprint)) {
      return BiometricType.fingerprint;
    } else if (availableTypes.contains(BiometricType.iris)) {
      return BiometricType.iris;
    } else if (availableTypes.contains(BiometricType.strong)) {
      return BiometricType.strong;
    } else {
      return availableTypes.first;
    }
  }

  bool _isLockedOut() {
    return _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);
  }

  Future<void> _handleFailedAttempt() async {
    _failedAttempts++;
    
    if (_failedAttempts >= _policy.maxRetryAttempts) {
      _lockoutUntil = DateTime.now().add(_policy.lockoutDuration);
      developer.log('Too many failed attempts. Locked out until $_lockoutUntil', name: 'BiometricAuthService');
    }
    
    await _saveFailedAttempts();
  }

  bool _isPolicyCompatible(BiometricSession session) {
    switch (session.authenticationType) {
      case BiometricType.fingerprint:
        return _policy.allowFingerprintAuth;
      case BiometricType.face:
        return _policy.allowFaceAuth;
      case BiometricType.weak:
      case BiometricType.voice:
        return !_policy.requireBiometricAuth || _policy.allowDeviceCredential;
      default:
        return true;
    }
  }

  Future<void> _savePolicy() async {
    await _secureStorage.write(
      key: 'auth_policy',
      value: jsonEncode(_policy.toJson()),
    );
  }

  Future<void> _loadPolicy() async {
    final policyJson = await _secureStorage.read(key: 'auth_policy');
    if (policyJson != null) {
      try {
        final policyMap = jsonDecode(policyJson);
        _policy = AuthenticationPolicy.fromJson(policyMap);
      } catch (e) {
        developer.log('Error loading authentication policy: $e', name: 'BiometricAuthService');
        _policy = const AuthenticationPolicy();
      }
    }
  }

  Future<void> _saveSession(BiometricSession session) async {
    await _secureStorage.write(
      key: 'biometric_session',
      value: jsonEncode(session.toJson()),
    );
  }

  Future<void> _loadSession() async {
    final sessionJson = await _secureStorage.read(key: 'biometric_session');
    if (sessionJson != null) {
      try {
        final sessionMap = jsonDecode(sessionJson);
        final session = BiometricSession.fromJson(sessionMap);
        
        if (session.isValid) {
          _currentSession = session;
        } else {
          await _secureStorage.delete(key: 'biometric_session');
        }
      } catch (e) {
        developer.log('Error loading biometric session: $e', name: 'BiometricAuthService');
        await _secureStorage.delete(key: 'biometric_session');
      }
    }
  }

  Future<void> _saveFailedAttempts() async {
    final data = {
      'failedAttempts': _failedAttempts,
      'lockoutUntil': _lockoutUntil?.toIso8601String(),
    };
    
    await _secureStorage.write(
      key: 'failed_attempts',
      value: jsonEncode(data),
    );
  }

  Future<void> _loadFailedAttempts() async {
    final dataJson = await _secureStorage.read(key: 'failed_attempts');
    if (dataJson != null) {
      try {
        final data = jsonDecode(dataJson);
        _failedAttempts = data['failedAttempts'] ?? 0;
        
        if (data['lockoutUntil'] != null) {
          _lockoutUntil = DateTime.parse(data['lockoutUntil']);
          
          // Clear lockout if expired
          if (_lockoutUntil!.isBefore(DateTime.now())) {
            _lockoutUntil = null;
            _failedAttempts = 0;
            await _saveFailedAttempts();
          }
        }
      } catch (e) {
        developer.log('Error loading failed attempts: $e', name: 'BiometricAuthService');
        _failedAttempts = 0;
        _lockoutUntil = null;
      }
    }
  }
}
