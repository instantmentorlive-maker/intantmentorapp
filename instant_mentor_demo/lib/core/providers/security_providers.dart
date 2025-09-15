import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../security/encryption_service.dart';
import '../security/biometric_auth_service.dart' as bio;
import '../security/key_manager.dart';

part 'security_providers.g.dart';

// Local type aliases so generated code can refer to unprefixed names
typedef BiometricAuthService = bio.BiometricAuthService;

// Core Security Services

@Riverpod(keepAlive: true)
AdvancedEncryptionService encryptionService(EncryptionServiceRef ref) {
  return AdvancedEncryptionService.instance;
}

@Riverpod(keepAlive: true)
bio.BiometricAuthService biometricAuthService(BiometricAuthServiceRef ref) {
  return bio.BiometricAuthService.instance;
}

@Riverpod(keepAlive: true)
SecureKeyManager secureKeyManager(SecureKeyManagerRef ref) {
  return SecureKeyManager.instance;
}

// Security State Providers

/// Biometric capability provider
@riverpod
class BiometricCapability extends _$BiometricCapability {
  @override
  Future<BiometricCapabilityState> build() async {
    final service = ref.watch(biometricAuthServiceProvider);

    try {
      final capability = await service.checkCapabilities();
      return BiometricCapabilityState(
        capability: capability,
        lastChecked: DateTime.now(),
        error: null,
      );
    } catch (e) {
      return BiometricCapabilityState(
        capability: null,
        lastChecked: DateTime.now(),
        error: e.toString(),
      );
    }
  }

  /// Refresh biometric capabilities
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(biometricAuthServiceProvider);
      final capability = await service.checkCapabilities();
      return BiometricCapabilityState(
        capability: capability,
        lastChecked: DateTime.now(),
        error: null,
      );
    });
  }
}

/// Biometric session provider
@riverpod
class BiometricSession extends _$BiometricSession {
  Timer? _sessionCheckTimer;

  @override
  BiometricSessionState build() {
    // Set up periodic session validation
    _sessionCheckTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkSessionValidity(),
    );

    ref.onDispose(() {
      _sessionCheckTimer?.cancel();
    });

    return const BiometricSessionState(
      session: null,
      isValid: false,
      lastAuthenticated: null,
    );
  }

  /// Authenticate and create session
  Future<bio.BiometricAuthResult> authenticate({
    String? reason,
    bool strongAuth = false,
    Map<String, dynamic>? metadata,
  }) async {
    final service = ref.read(biometricAuthServiceProvider);

    bio.BiometricAuthResult result;
    if (strongAuth) {
      result = await service.strongAuth(
        reason: reason ?? 'Strong authentication required',
        metadata: metadata,
      );
    } else {
      result = await service.quickAuth(
        reason: reason ?? 'Authentication required',
        metadata: metadata,
      );
    }

    if (result.isAuthenticated) {
      await _updateSessionState();
    }

    return result;
  }

  /// Invalidate current session
  Future<void> invalidateSession() async {
    final service = ref.read(biometricAuthServiceProvider);
    await service.invalidateSession();
    await _updateSessionState();
  }

  /// Update authentication policy
  Future<void> updatePolicy(bio.AuthenticationPolicy policy) async {
    final service = ref.read(biometricAuthServiceProvider);
    await service.updatePolicy(policy);
    await _updateSessionState();
  }

  void _checkSessionValidity() {
    final currentState = state;
    if (currentState.isValid && currentState.session?.isExpired == true) {
      _updateSessionState();
    }
  }

  Future<void> _updateSessionState() async {
    final service = ref.read(biometricAuthServiceProvider);
    final session = service.getCurrentSession();

    state = BiometricSessionState(
      session: session,
      isValid: session != null && session.isValid,
      lastAuthenticated: session?.createdAt,
    );
  }
}

/// Key management provider
@riverpod
class KeyManagement extends _$KeyManagement {
  @override
  Future<KeyManagementState> build() async {
    final keyManager = ref.watch(secureKeyManagerProvider);

    try {
      await keyManager.initialize();
      final keys = await keyManager.listKeys(includeExpired: false);

      return KeyManagementState(
        keys: keys,
        totalKeys: keys.length,
        activeKeys: keys.where((k) => k.status == KeyStatus.active).length,
        lastUpdated: DateTime.now(),
        error: null,
      );
    } catch (e) {
      return KeyManagementState(
        keys: [],
        totalKeys: 0,
        activeKeys: 0,
        lastUpdated: DateTime.now(),
        error: e.toString(),
      );
    }
  }

  /// Generate a new key
  Future<String> generateKey({
    required KeyUsage usage,
    required String algorithm,
    int? keySize,
    Duration? expiresIn,
    KeyRotationConfig? rotationConfig,
    Map<String, dynamic>? metadata,
  }) async {
    final keyManager = ref.read(secureKeyManagerProvider);

    final keyId = await keyManager.generateKey(
      usage: usage,
      algorithm: algorithm,
      keySize: keySize,
      expiresIn: expiresIn,
      rotationConfig: rotationConfig,
      metadata: metadata,
    );

    await refresh();
    return keyId;
  }

  /// Rotate a key
  Future<String> rotateKey(String keyId, {bool retainOldVersion = true}) async {
    final keyManager = ref.read(secureKeyManagerProvider);
    final newKeyId =
        await keyManager.rotateKey(keyId, retainOldVersion: retainOldVersion);
    await refresh();
    return newKeyId;
  }

  /// Revoke a key
  Future<void> revokeKey(String keyId) async {
    final keyManager = ref.read(secureKeyManagerProvider);
    await keyManager.revokeKey(keyId);
    await refresh();
  }

  /// Delete a key
  Future<void> deleteKey(String keyId) async {
    final keyManager = ref.read(secureKeyManagerProvider);
    await keyManager.deleteKey(keyId);
    await refresh();
  }

  /// Refresh key list
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final keyManager = ref.read(secureKeyManagerProvider);
      final keys = await keyManager.listKeys(includeExpired: false);

      return KeyManagementState(
        keys: keys,
        totalKeys: keys.length,
        activeKeys: keys.where((k) => k.status == KeyStatus.active).length,
        lastUpdated: DateTime.now(),
        error: null,
      );
    });
  }
}

/// Encryption operations provider
@riverpod
class EncryptionOperations extends _$EncryptionOperations {
  @override
  EncryptionOperationsState build() {
    return const EncryptionOperationsState(
      operationsCount: 0,
      encryptionCount: 0,
      decryptionCount: 0,
      lastOperation: null,
    );
  }

  /// Encrypt data with AES-GCM
  Future<EncryptionResult> encryptAESGCM(List<int> data, String keyId) async {
    final encryptionService = ref.read(encryptionServiceProvider);
    final keyManager = ref.read(secureKeyManagerProvider);

    final key = await keyManager.getKey(keyId);
    if (key == null) {
      throw Exception('Key not found: $keyId');
    }

    final result = encryptionService.encryptAESGCM(
      Uint8List.fromList(data),
      key,
    );

    _updateOperationCount(isEncryption: true);
    return result;
  }

  /// Decrypt data with AES-GCM
  Future<Uint8List> decryptAESGCM(EncryptionResult result, String keyId) async {
    final encryptionService = ref.read(encryptionServiceProvider);
    final keyManager = ref.read(secureKeyManagerProvider);

    final key = await keyManager.getKey(keyId);
    if (key == null) {
      throw Exception('Key not found: $keyId');
    }

    final decryptedData = encryptionService.decryptAESGCM(result, key);
    _updateOperationCount(isEncryption: false);
    return decryptedData;
  }

  /// Encrypt data with RSA
  Future<EncryptionResult> encryptRSA(List<int> data, String keyId) async {
    final encryptionService = ref.read(encryptionServiceProvider);
    final keyManager = ref.read(secureKeyManagerProvider);

    final keyMetadata = await keyManager.getKeyMetadata(keyId);
    if (keyMetadata == null) {
      throw Exception('Key not found: $keyId');
    }

    // Get public key for RSA encryption
    final key = await keyManager.getKey(keyId);
    if (key == null) {
      throw Exception('Key data not found: $keyId');
    }

    final result = encryptionService.encryptRSA(
      Uint8List.fromList(data),
      key,
    );

    _updateOperationCount(isEncryption: true);
    return result;
  }

  /// Generate HMAC
  Future<Uint8List> generateHMAC(List<int> data, String keyId,
      {String algorithm = 'SHA-256'}) async {
    final encryptionService = ref.read(encryptionServiceProvider);
    final keyManager = ref.read(secureKeyManagerProvider);

    final key = await keyManager.getKey(keyId);
    if (key == null) {
      throw Exception('Key not found: $keyId');
    }

    final hmac = encryptionService.generateHMAC(
      Uint8List.fromList(data),
      key,
      algorithm: algorithm,
    );

    _updateOperationCount(isEncryption: true);
    return hmac;
  }

  void _updateOperationCount({required bool isEncryption}) {
    final currentState = state;
    state = currentState.copyWith(
      operationsCount: currentState.operationsCount + 1,
      encryptionCount: isEncryption
          ? currentState.encryptionCount + 1
          : currentState.encryptionCount,
      decryptionCount: !isEncryption
          ? currentState.decryptionCount + 1
          : currentState.decryptionCount,
      lastOperation: DateTime.now(),
    );
  }

  /// Reset operation counters
  void resetCounters() {
    state = const EncryptionOperationsState(
      operationsCount: 0,
      encryptionCount: 0,
      decryptionCount: 0,
      lastOperation: null,
    );
  }
}

/// Security audit provider
@riverpod
class SecurityAudit extends _$SecurityAudit {
  @override
  Future<SecurityAuditState> build() async {
    return await _performSecurityAudit();
  }

  /// Perform security audit
  Future<void> performAudit() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await _performSecurityAudit();
    });
  }

  Future<SecurityAuditState> _performSecurityAudit() async {
    final issues = <SecurityIssue>[];
    final recommendations = <String>[];

    // Check biometric capabilities
    try {
      final biometricService = ref.read(biometricAuthServiceProvider);
      final capabilities = await biometricService.checkCapabilities();

      if (!capabilities.isAvailable) {
        issues.add(const SecurityIssue(
          severity: SecuritySeverity.medium,
          category: 'Authentication',
          description: 'Biometric authentication not available',
          recommendation:
              'Enable biometric authentication for enhanced security',
        ));
        recommendations.add(
            'Set up biometric authentication (fingerprint/face recognition)');
      }
    } catch (e) {
      issues.add(const SecurityIssue(
        severity: SecuritySeverity.low,
        category: 'System',
        description: 'Unable to check biometric capabilities',
        recommendation: 'Verify device security settings',
      ));
    }

    // Check key management
    try {
      final keyManager = ref.read(secureKeyManagerProvider);
      final keys = await keyManager.listKeys(includeExpired: true);

      final expiredKeys = keys.where((k) => k.isExpired).length;
      if (expiredKeys > 0) {
        issues.add(SecurityIssue(
          severity: SecuritySeverity.high,
          category: 'Key Management',
          description: '$expiredKeys expired keys found',
          recommendation: 'Remove or rotate expired keys immediately',
        ));
        recommendations.add('Clean up expired encryption keys');
      }

      final deprecatedKeys =
          keys.where((k) => k.status == KeyStatus.deprecated).length;
      if (deprecatedKeys > 5) {
        issues.add(SecurityIssue(
          severity: SecuritySeverity.medium,
          category: 'Key Management',
          description: 'Too many deprecated keys ($deprecatedKeys)',
          recommendation: 'Clean up old key versions',
        ));
        recommendations.add('Archive or delete old key versions');
      }
    } catch (e) {
      issues.add(const SecurityIssue(
        severity: SecuritySeverity.medium,
        category: 'Key Management',
        description: 'Unable to audit key management',
        recommendation: 'Check key storage integrity',
      ));
    }

    // General security recommendations
    if (issues.isEmpty) {
      recommendations
          .add('Enable automatic key rotation for enhanced security');
      recommendations
          .add('Review and update authentication policies regularly');
      recommendations.add('Monitor security audit logs');
    }

    return SecurityAuditState(
      issues: issues,
      recommendations: recommendations,
      lastAuditTime: DateTime.now(),
      overallScore: _calculateSecurityScore(issues),
    );
  }

  double _calculateSecurityScore(List<SecurityIssue> issues) {
    if (issues.isEmpty) return 100.0;

    double score = 100.0;
    for (final issue in issues) {
      switch (issue.severity) {
        case SecuritySeverity.critical:
          score -= 25.0;
          break;
        case SecuritySeverity.high:
          score -= 15.0;
          break;
        case SecuritySeverity.medium:
          score -= 8.0;
          break;
        case SecuritySeverity.low:
          score -= 3.0;
          break;
      }
    }

    return score.clamp(0.0, 100.0);
  }
}

// State Classes

class BiometricCapabilityState {
  final bio.BiometricCapability? capability;
  final DateTime lastChecked;
  final String? error;

  const BiometricCapabilityState({
    required this.capability,
    required this.lastChecked,
    this.error,
  });

  bool get isAvailable => capability?.isAvailable ?? false;
  List<bio.BiometricType> get availableTypes =>
      capability?.availableTypes ?? [];
}

class BiometricSessionState {
  final bio.BiometricSession? session;
  final bool isValid;
  final DateTime? lastAuthenticated;

  const BiometricSessionState({
    required this.session,
    required this.isValid,
    this.lastAuthenticated,
  });

  Duration? get timeUntilExpiry {
    if (session?.expiresAt == null) return null;
    final remaining = session!.expiresAt.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }
}

class KeyManagementState {
  final List<SecureKeyMetadata> keys;
  final int totalKeys;
  final int activeKeys;
  final DateTime lastUpdated;
  final String? error;

  const KeyManagementState({
    required this.keys,
    required this.totalKeys,
    required this.activeKeys,
    required this.lastUpdated,
    this.error,
  });

  int get expiredKeys => keys.where((k) => k.isExpired).length;
  int get deprecatedKeys =>
      keys.where((k) => k.status == KeyStatus.deprecated).length;

  List<SecureKeyMetadata> getKeysByUsage(KeyUsage usage) {
    return keys.where((k) => k.usage == usage).toList();
  }
}

class EncryptionOperationsState {
  final int operationsCount;
  final int encryptionCount;
  final int decryptionCount;
  final DateTime? lastOperation;

  const EncryptionOperationsState({
    required this.operationsCount,
    required this.encryptionCount,
    required this.decryptionCount,
    this.lastOperation,
  });

  EncryptionOperationsState copyWith({
    int? operationsCount,
    int? encryptionCount,
    int? decryptionCount,
    DateTime? lastOperation,
  }) {
    return EncryptionOperationsState(
      operationsCount: operationsCount ?? this.operationsCount,
      encryptionCount: encryptionCount ?? this.encryptionCount,
      decryptionCount: decryptionCount ?? this.decryptionCount,
      lastOperation: lastOperation ?? this.lastOperation,
    );
  }
}

class SecurityAuditState {
  final List<SecurityIssue> issues;
  final List<String> recommendations;
  final DateTime lastAuditTime;
  final double overallScore;

  const SecurityAuditState({
    required this.issues,
    required this.recommendations,
    required this.lastAuditTime,
    required this.overallScore,
  });

  int get criticalIssues =>
      issues.where((i) => i.severity == SecuritySeverity.critical).length;
  int get highIssues =>
      issues.where((i) => i.severity == SecuritySeverity.high).length;
  int get mediumIssues =>
      issues.where((i) => i.severity == SecuritySeverity.medium).length;
  int get lowIssues =>
      issues.where((i) => i.severity == SecuritySeverity.low).length;

  String get scoreGrade {
    if (overallScore >= 90) return 'A';
    if (overallScore >= 80) return 'B';
    if (overallScore >= 70) return 'C';
    if (overallScore >= 60) return 'D';
    return 'F';
  }
}

enum SecuritySeverity { critical, high, medium, low }

class SecurityIssue {
  final SecuritySeverity severity;
  final String category;
  final String description;
  final String recommendation;

  const SecurityIssue({
    required this.severity,
    required this.category,
    required this.description,
    required this.recommendation,
  });
}
