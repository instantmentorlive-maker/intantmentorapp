import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'encryption_service.dart';

/// Key rotation policy
enum KeyRotationPolicy {
  manual,
  automatic,
  timeBasedRotation,
  usageBasedRotation,
}

/// Key usage purpose
enum KeyUsage {
  encryption,
  signing,
  authentication,
  keyDerivation,
  messageAuth,
  dataProtection,
}

/// Key status
enum KeyStatus {
  active,
  rotating,
  deprecated,
  revoked,
  expired,
}

/// Secure key metadata
class SecureKeyMetadata {
  final String keyId;
  final KeyType keyType;
  final KeyUsage usage;
  final KeyStatus status;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? lastUsed;
  final DateTime? lastRotated;
  final int usageCount;
  final String algorithm;
  final int keySize;
  final Map<String, dynamic> customMetadata;

  const SecureKeyMetadata({
    required this.keyId,
    required this.keyType,
    required this.usage,
    required this.status,
    required this.createdAt,
    this.expiresAt,
    this.lastUsed,
    this.lastRotated,
    required this.usageCount,
    required this.algorithm,
    required this.keySize,
    this.customMetadata = const {},
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isActive => status == KeyStatus.active && !isExpired;

  SecureKeyMetadata copyWith({
    KeyStatus? status,
    DateTime? lastUsed,
    DateTime? lastRotated,
    int? usageCount,
    Map<String, dynamic>? customMetadata,
  }) {
    return SecureKeyMetadata(
      keyId: keyId,
      keyType: keyType,
      usage: usage,
      status: status ?? this.status,
      createdAt: createdAt,
      expiresAt: expiresAt,
      lastUsed: lastUsed ?? this.lastUsed,
      lastRotated: lastRotated ?? this.lastRotated,
      usageCount: usageCount ?? this.usageCount,
      algorithm: algorithm,
      keySize: keySize,
      customMetadata: customMetadata ?? this.customMetadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'keyId': keyId,
      'keyType': keyType.name,
      'usage': usage.name,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'lastUsed': lastUsed?.toIso8601String(),
      'lastRotated': lastRotated?.toIso8601String(),
      'usageCount': usageCount,
      'algorithm': algorithm,
      'keySize': keySize,
      'customMetadata': customMetadata,
    };
  }

  factory SecureKeyMetadata.fromJson(Map<String, dynamic> json) {
    return SecureKeyMetadata(
      keyId: json['keyId'],
      keyType: KeyType.values.firstWhere((t) => t.name == json['keyType']),
      usage: KeyUsage.values.firstWhere((u) => u.name == json['usage']),
      status: KeyStatus.values.firstWhere((s) => s.name == json['status']),
      createdAt: DateTime.parse(json['createdAt']),
      expiresAt:
          json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : null,
      lastUsed:
          json['lastUsed'] != null ? DateTime.parse(json['lastUsed']) : null,
      lastRotated: json['lastRotated'] != null
          ? DateTime.parse(json['lastRotated'])
          : null,
      usageCount: json['usageCount'],
      algorithm: json['algorithm'],
      keySize: json['keySize'],
      customMetadata: json['customMetadata'] ?? {},
    );
  }
}

/// Key rotation configuration
class KeyRotationConfig {
  final KeyRotationPolicy policy;
  final Duration? rotationInterval;
  final int? maxUsageCount;
  final bool autoRotateBeforeExpiry;
  final Duration? preExpiryRotationWindow;
  final bool retainOldVersions;
  final int maxOldVersions;

  const KeyRotationConfig({
    this.policy = KeyRotationPolicy.manual,
    this.rotationInterval,
    this.maxUsageCount,
    this.autoRotateBeforeExpiry = true,
    this.preExpiryRotationWindow = const Duration(days: 7),
    this.retainOldVersions = true,
    this.maxOldVersions = 3,
  });

  Map<String, dynamic> toJson() {
    return {
      'policy': policy.name,
      'rotationIntervalMinutes': rotationInterval?.inMinutes,
      'maxUsageCount': maxUsageCount,
      'autoRotateBeforeExpiry': autoRotateBeforeExpiry,
      'preExpiryRotationWindowMinutes': preExpiryRotationWindow?.inMinutes,
      'retainOldVersions': retainOldVersions,
      'maxOldVersions': maxOldVersions,
    };
  }

  factory KeyRotationConfig.fromJson(Map<String, dynamic> json) {
    return KeyRotationConfig(
      policy:
          KeyRotationPolicy.values.firstWhere((p) => p.name == json['policy']),
      rotationInterval: json['rotationIntervalMinutes'] != null
          ? Duration(minutes: json['rotationIntervalMinutes'])
          : null,
      maxUsageCount: json['maxUsageCount'],
      autoRotateBeforeExpiry: json['autoRotateBeforeExpiry'] ?? true,
      preExpiryRotationWindow: json['preExpiryRotationWindowMinutes'] != null
          ? Duration(minutes: json['preExpiryRotationWindowMinutes'])
          : const Duration(days: 7),
      retainOldVersions: json['retainOldVersions'] ?? true,
      maxOldVersions: json['maxOldVersions'] ?? 3,
    );
  }
}

/// Key derivation context
class KeyDerivationContext {
  final String purpose;
  final String? userId;
  final String? sessionId;
  final Map<String, dynamic> additionalContext;

  const KeyDerivationContext({
    required this.purpose,
    this.userId,
    this.sessionId,
    this.additionalContext = const {},
  });

  String get contextString {
    final parts = <String>[purpose];
    if (userId != null) parts.add('user:$userId');
    if (sessionId != null) parts.add('session:$sessionId');

    final sortedKeys = additionalContext.keys.toList()..sort();
    for (final key in sortedKeys) {
      parts.add('$key:${additionalContext[key]}');
    }

    return parts.join('|');
  }

  Uint8List get contextBytes => utf8.encode(contextString);

  Map<String, dynamic> toJson() {
    return {
      'purpose': purpose,
      'userId': userId,
      'sessionId': sessionId,
      'additionalContext': additionalContext,
    };
  }
}

/// Key exchange result
class KeyExchangeResult {
  final String keyId;
  final Uint8List publicKey;
  final String exchangeId;
  final DateTime expiresAt;
  final Map<String, dynamic> metadata;

  const KeyExchangeResult({
    required this.keyId,
    required this.publicKey,
    required this.exchangeId,
    required this.expiresAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'keyId': keyId,
      'publicKey': base64Encode(publicKey),
      'exchangeId': exchangeId,
      'expiresAt': expiresAt.toIso8601String(),
      'metadata': metadata,
    };
  }
}

/// Secure key management service
class SecureKeyManager {
  static SecureKeyManager? _instance;
  static SecureKeyManager get instance => _instance ??= SecureKeyManager._();

  SecureKeyManager._();

  final AdvancedEncryptionService _encryptionService =
      AdvancedEncryptionService.instance;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final Map<String, SecureKeyMetadata> _keyCache = {};
  final Map<String, KeyRotationConfig> _rotationConfigs = {};
  bool _initialized = false;

  /// Initialize the key manager
  Future<void> initialize() async {
    if (_initialized) return;

    await _encryptionService.initialize();
    await _loadKeyMetadata();
    await _loadRotationConfigs();

    // Schedule automatic key rotation check
    _scheduleRotationCheck();

    _initialized = true;
    developer.log('Secure key manager initialized', name: 'SecureKeyManager');
  }

  /// Generate a new secure key
  Future<String> generateKey({
    required KeyUsage usage,
    required String algorithm,
    int? keySize,
    Duration? expiresIn,
    KeyRotationConfig? rotationConfig,
    Map<String, dynamic>? metadata,
  }) async {
    _ensureInitialized();

    final keyId = _generateKeyId();
    Uint8List keyData;
    int actualKeySize;

    // Generate key based on algorithm
    switch (algorithm.toUpperCase()) {
      case 'AES-256':
        keyData = _encryptionService.generateAESKey();
        actualKeySize = 256;
        break;
      case 'RSA-2048':
        final keyPair = await _encryptionService.generateRSAKeyPair();
        keyData = keyPair.privateKey;
        actualKeySize = 2048;
        break;
      case 'RSA-4096':
        final keyPair =
            await _encryptionService.generateRSAKeyPair(keySize: 4096);
        keyData = keyPair.privateKey;
        actualKeySize = 4096;
        break;
      default:
        throw ArgumentError('Unsupported algorithm: $algorithm');
    }

    // Create metadata
    final keyMetadata = SecureKeyMetadata(
      keyId: keyId,
      keyType: algorithm.contains('RSA')
          ? KeyType.asymmetricPrivate
          : KeyType.symmetric,
      usage: usage,
      status: KeyStatus.active,
      createdAt: DateTime.now(),
      expiresAt: expiresIn != null ? DateTime.now().add(expiresIn) : null,
      usageCount: 0,
      algorithm: algorithm,
      keySize: actualKeySize,
      customMetadata: metadata ?? {},
    );

    // Store key and metadata
    await _storeKey(keyId, keyData, keyMetadata);

    // Set rotation config if provided
    if (rotationConfig != null) {
      await _setRotationConfig(keyId, rotationConfig);
    }

    developer.log('Generated key: $keyId ($algorithm)',
        name: 'SecureKeyManager');
    return keyId;
  }

  /// Derive a key from another key
  Future<String> deriveKey({
    required String parentKeyId,
    required KeyDerivationContext context,
    required String algorithm,
    int? keySize,
    Duration? expiresIn,
    Map<String, dynamic>? metadata,
  }) async {
    _ensureInitialized();

    final parentKey = await _retrieveKey(parentKeyId);
    if (parentKey == null) {
      throw Exception('Parent key not found: $parentKeyId');
    }

    final derivedKeyId = _generateKeyId();

    // Use HKDF for key derivation
    final salt = _encryptionService.generateSalt();
    final info = context.contextBytes;
    final derivedKey = await _hkdfExpand(parentKey, salt, info, keySize ?? 32);

    // Create metadata
    final keyMetadata = SecureKeyMetadata(
      keyId: derivedKeyId,
      keyType: KeyType.derived,
      usage: KeyUsage.values.firstWhere((u) => u.name == context.purpose,
          orElse: () => KeyUsage.dataProtection),
      status: KeyStatus.active,
      createdAt: DateTime.now(),
      expiresAt: expiresIn != null ? DateTime.now().add(expiresIn) : null,
      usageCount: 0,
      algorithm: algorithm,
      keySize: (keySize ?? 32) * 8,
      customMetadata: {
        'parentKeyId': parentKeyId,
        'derivationContext': context.toJson(),
        ...?metadata,
      },
    );

    await _storeKey(derivedKeyId, derivedKey, keyMetadata);

    developer.log('Derived key: $derivedKeyId from $parentKeyId',
        name: 'SecureKeyManager');
    return derivedKeyId;
  }

  /// Get key for use
  Future<Uint8List?> getKey(String keyId) async {
    _ensureInitialized();

    final metadata = await getKeyMetadata(keyId);
    if (metadata == null || !metadata.isActive) {
      return null;
    }

    // Update usage statistics
    await _updateKeyUsage(keyId);

    // Check if rotation is needed
    await _checkAndRotateKey(keyId);

    return await _retrieveKey(keyId);
  }

  /// Get key metadata
  Future<SecureKeyMetadata?> getKeyMetadata(String keyId) async {
    _ensureInitialized();

    if (_keyCache.containsKey(keyId)) {
      return _keyCache[keyId];
    }

    final metadataJson = await _secureStorage.read(key: 'metadata_$keyId');
    if (metadataJson == null) return null;

    try {
      final metadata = SecureKeyMetadata.fromJson(jsonDecode(metadataJson));
      _keyCache[keyId] = metadata;
      return metadata;
    } catch (e) {
      developer.log('Error loading key metadata for $keyId: $e',
          name: 'SecureKeyManager');
      return null;
    }
  }

  /// List all keys
  Future<List<SecureKeyMetadata>> listKeys({
    KeyUsage? usage,
    KeyStatus? status,
    bool includeExpired = false,
  }) async {
    _ensureInitialized();

    final allKeys = await _secureStorage.readAll();
    final keys = <SecureKeyMetadata>[];

    for (final entry in allKeys.entries) {
      if (!entry.key.startsWith('metadata_')) continue;

      try {
        final metadata = SecureKeyMetadata.fromJson(jsonDecode(entry.value));

        // Apply filters
        if (usage != null && metadata.usage != usage) continue;
        if (status != null && metadata.status != status) continue;
        if (!includeExpired && metadata.isExpired) continue;

        keys.add(metadata);
      } catch (e) {
        developer.log('Error loading key metadata: $e',
            name: 'SecureKeyManager');
      }
    }

    developer.log('Listed ${keys.length} keys', name: 'SecureKeyManager');
    return keys;
  }

  /// Rotate a key
  Future<String> rotateKey(String keyId, {bool retainOldVersion = true}) async {
    _ensureInitialized();

    final oldMetadata = await getKeyMetadata(keyId);
    if (oldMetadata == null) {
      throw Exception('Key not found: $keyId');
    }

    // Generate new key with same parameters
    final newKeyId = await generateKey(
      usage: oldMetadata.usage,
      algorithm: oldMetadata.algorithm,
      keySize: oldMetadata.keySize,
      expiresIn: oldMetadata.expiresAt?.difference(DateTime.now()),
      metadata: oldMetadata.customMetadata,
    );

    // Update old key status
    if (retainOldVersion) {
      final config = _rotationConfigs[keyId];
      await _updateKeyMetadata(
          keyId,
          oldMetadata.copyWith(
            status: KeyStatus.deprecated,
            lastRotated: DateTime.now(),
          ));

      // Clean up old versions if needed
      if (config?.retainOldVersions == true) {
        await _cleanupOldKeyVersions(keyId, config!.maxOldVersions);
      }
    } else {
      await _deleteKeyData(keyId);
    }

    // Transfer rotation config
    final rotationConfig = _rotationConfigs.remove(keyId);
    if (rotationConfig != null) {
      await _setRotationConfig(newKeyId, rotationConfig);
    }

    developer.log('Rotated key: $keyId -> $newKeyId', name: 'SecureKeyManager');
    return newKeyId;
  }

  /// Set key rotation configuration
  Future<void> setRotationConfig(String keyId, KeyRotationConfig config) async {
    _ensureInitialized();
    await _setRotationConfig(keyId, config);
    developer.log('Set rotation config for key: $keyId',
        name: 'SecureKeyManager');
  }

  /// Revoke a key
  Future<void> revokeKey(String keyId) async {
    _ensureInitialized();

    final metadata = await getKeyMetadata(keyId);
    if (metadata == null) return;

    await _updateKeyMetadata(
        keyId, metadata.copyWith(status: KeyStatus.revoked));
    developer.log('Revoked key: $keyId', name: 'SecureKeyManager');
  }

  /// Delete a key permanently
  Future<void> deleteKey(String keyId) async {
    _ensureInitialized();

    await _deleteKeyData(keyId);
    _keyCache.remove(keyId);
    _rotationConfigs.remove(keyId);

    developer.log('Deleted key: $keyId', name: 'SecureKeyManager');
  }

  /// Key exchange - generate ephemeral key pair for secure communication
  Future<KeyExchangeResult> initiateKeyExchange({
    Duration? expiresIn,
    Map<String, dynamic>? metadata,
  }) async {
    _ensureInitialized();

    final keyPair = await _encryptionService.generateRSAKeyPair();
    final exchangeId = _generateExchangeId();
    final keyId = _generateKeyId();

    // Store private key temporarily
    final keyMetadata = SecureKeyMetadata(
      keyId: keyId,
      keyType: KeyType.ephemeral,
      usage: KeyUsage.keyDerivation,
      status: KeyStatus.active,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(expiresIn ?? const Duration(minutes: 30)),
      usageCount: 0,
      algorithm: 'RSA-2048',
      keySize: 2048,
      customMetadata: {
        'exchangeId': exchangeId,
        'isEphemeral': true,
        ...?metadata,
      },
    );

    await _storeKey(keyId, keyPair.privateKey, keyMetadata);

    return KeyExchangeResult(
      keyId: keyId,
      publicKey: keyPair.publicKey,
      exchangeId: exchangeId,
      expiresAt: keyMetadata.expiresAt!,
      metadata: metadata ?? {},
    );
  }

  /// Complete key exchange and derive shared secret
  Future<String> completeKeyExchange({
    required String exchangeId,
    required Uint8List peerPublicKey,
    String? derivationContext,
  }) async {
    _ensureInitialized();

    // Find ephemeral key by exchange ID
    final keys =
        await listKeys(usage: KeyUsage.keyDerivation, status: KeyStatus.active);
    final ephemeralKey = keys.firstWhere(
      (k) => k.customMetadata['exchangeId'] == exchangeId,
      orElse: () => throw Exception('Exchange not found: $exchangeId'),
    );

    final privateKey = await _retrieveKey(ephemeralKey.keyId);
    if (privateKey == null) {
      throw Exception('Private key not found for exchange: $exchangeId');
    }

    // Perform ECDH-like key agreement (simplified)
    final sharedSecret = _computeSharedSecret(privateKey, peerPublicKey);

    // Derive shared key
    final context = KeyDerivationContext(
      purpose: 'key_exchange',
      sessionId: exchangeId,
      // Include a truncated fingerprint of the secret to tie the derived key context
      // to this exchange without exposing the secret itself.
      additionalContext: {
        'context': derivationContext ?? 'default',
        'secret_fpr': base64Url
            .encode(sha256.convert(sharedSecret).bytes)
            .substring(0, 12),
      },
    );

    final sharedKeyId = await deriveKey(
      parentKeyId: ephemeralKey.keyId,
      context: context,
      algorithm: 'AES-256',
      expiresIn: const Duration(hours: 24),
      metadata: {
        'exchangeId': exchangeId,
        'isSharedKey': true,
      },
    );

    // Clean up ephemeral key
    await deleteKey(ephemeralKey.keyId);

    developer.log('Completed key exchange: $exchangeId -> $sharedKeyId',
        name: 'SecureKeyManager');
    return sharedKeyId;
  }

  /// Export key in secure format
  Future<Map<String, dynamic>> exportKey(String keyId,
      {String? password}) async {
    _ensureInitialized();

    final metadata = await getKeyMetadata(keyId);
    if (metadata == null) {
      throw Exception('Key not found: $keyId');
    }

    final keyData = await _retrieveKey(keyId);
    if (keyData == null) {
      throw Exception('Key data not found: $keyId');
    }

    EncryptionResult encryptedKey;

    if (password != null) {
      // Encrypt with password-derived key
      final salt = _encryptionService.generateSalt();
      final derivedKey = _encryptionService.deriveKeyPBKDF2(password, salt);
      encryptedKey = _encryptionService.encryptAESGCM(keyData, derivedKey);

      return {
        'keyId': keyId,
        'metadata': metadata.toJson(),
        'encryptedKey': encryptedKey.toJson(),
        'salt': base64Encode(salt),
        'isPasswordProtected': true,
      };
    } else {
      // Return base64 encoded key (not recommended for production)
      return {
        'keyId': keyId,
        'metadata': metadata.toJson(),
        'keyData': base64Encode(keyData),
        'isPasswordProtected': false,
      };
    }
  }

  /// Import key from secure format
  Future<String> importKey(Map<String, dynamic> keyExport,
      {String? password}) async {
    _ensureInitialized();

    final metadata = SecureKeyMetadata.fromJson(keyExport['metadata']);
    final newKeyId = _generateKeyId();

    Uint8List keyData;

    if (keyExport['isPasswordProtected'] == true) {
      if (password == null) {
        throw Exception('Password required for encrypted key import');
      }

      final salt = base64Decode(keyExport['salt']);
      final derivedKey = _encryptionService.deriveKeyPBKDF2(password, salt);
      final encryptedKey = EncryptionResult.fromJson(keyExport['encryptedKey']);
      keyData = _encryptionService.decryptAESGCM(encryptedKey, derivedKey);
    } else {
      keyData = base64Decode(keyExport['keyData']);
    }

    // Create new metadata with new ID
    final newMetadata = SecureKeyMetadata(
      keyId: newKeyId,
      keyType: metadata.keyType,
      usage: metadata.usage,
      status: KeyStatus.active,
      createdAt: DateTime.now(),
      expiresAt: metadata.expiresAt,
      usageCount: 0,
      algorithm: metadata.algorithm,
      keySize: metadata.keySize,
      customMetadata: {
        ...metadata.customMetadata,
        'imported': true,
        'originalKeyId': metadata.keyId,
      },
    );

    await _storeKey(newKeyId, keyData, newMetadata);

    developer.log('Imported key: ${metadata.keyId} -> $newKeyId',
        name: 'SecureKeyManager');
    return newKeyId;
  }

  /// Clear all keys
  Future<void> clearAllKeys() async {
    final allKeys = await _secureStorage.readAll();
    final keysToDelete = <String>[];

    for (final key in allKeys.keys) {
      if (key.startsWith('key_') ||
          key.startsWith('metadata_') ||
          key.startsWith('rotation_')) {
        keysToDelete.add(key);
      }
    }

    for (final key in keysToDelete) {
      await _secureStorage.delete(key: key);
    }

    _keyCache.clear();
    _rotationConfigs.clear();

    developer.log('Cleared all keys', name: 'SecureKeyManager');
  }

  // Private helper methods

  void _ensureInitialized() {
    if (!_initialized) {
      throw Exception(
          'SecureKeyManager not initialized. Call initialize() first.');
    }
  }

  String _generateKeyId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random.secure();
    final randomBytes = List.generate(8, (_) => random.nextInt(256));
    final combined = [...randomBytes, ...utf8.encode(timestamp.toString())];
    final hash = sha256.convert(combined);
    return base64Url.encode(hash.bytes).substring(0, 16);
  }

  String _generateExchangeId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  Future<void> _storeKey(
      String keyId, Uint8List keyData, SecureKeyMetadata metadata) async {
    // Store key data
    await _encryptionService.storeKey(keyId, keyData, metadata.keyType);

    // Store metadata
    await _secureStorage.write(
      key: 'metadata_$keyId',
      value: jsonEncode(metadata.toJson()),
    );

    // Cache metadata
    _keyCache[keyId] = metadata;
  }

  Future<Uint8List?> _retrieveKey(String keyId) async {
    return await _encryptionService.getKey(keyId);
  }

  Future<void> _updateKeyMetadata(
      String keyId, SecureKeyMetadata metadata) async {
    await _secureStorage.write(
      key: 'metadata_$keyId',
      value: jsonEncode(metadata.toJson()),
    );
    _keyCache[keyId] = metadata;
  }

  Future<void> _updateKeyUsage(String keyId) async {
    final metadata = _keyCache[keyId];
    if (metadata == null) return;

    final updatedMetadata = metadata.copyWith(
      lastUsed: DateTime.now(),
      usageCount: metadata.usageCount + 1,
    );

    await _updateKeyMetadata(keyId, updatedMetadata);
  }

  Future<void> _deleteKeyData(String keyId) async {
    await _encryptionService.deleteKey(keyId);
    await _secureStorage.delete(key: 'metadata_$keyId');
    await _secureStorage.delete(key: 'rotation_$keyId');
  }

  Future<void> _setRotationConfig(
      String keyId, KeyRotationConfig config) async {
    _rotationConfigs[keyId] = config;
    await _secureStorage.write(
      key: 'rotation_$keyId',
      value: jsonEncode(config.toJson()),
    );
  }

  Future<void> _loadKeyMetadata() async {
    final allKeys = await _secureStorage.readAll();

    for (final entry in allKeys.entries) {
      if (!entry.key.startsWith('metadata_')) continue;

      try {
        final keyId = entry.key.substring(9);
        final metadata = SecureKeyMetadata.fromJson(jsonDecode(entry.value));
        _keyCache[keyId] = metadata;
      } catch (e) {
        developer.log('Error loading key metadata: $e',
            name: 'SecureKeyManager');
      }
    }
  }

  Future<void> _loadRotationConfigs() async {
    final allKeys = await _secureStorage.readAll();

    for (final entry in allKeys.entries) {
      if (!entry.key.startsWith('rotation_')) continue;

      try {
        final keyId = entry.key.substring(9);
        final config = KeyRotationConfig.fromJson(jsonDecode(entry.value));
        _rotationConfigs[keyId] = config;
      } catch (e) {
        developer.log('Error loading rotation config: $e',
            name: 'SecureKeyManager');
      }
    }
  }

  void _scheduleRotationCheck() {
    // Check for key rotation every hour
    Future.delayed(const Duration(hours: 1), () {
      _performAutomaticRotation();
      _scheduleRotationCheck();
    });
  }

  Future<void> _performAutomaticRotation() async {
    for (final entry in _rotationConfigs.entries) {
      final keyId = entry.key;
      final config = entry.value;

      try {
        if (await _shouldRotateKey(keyId, config)) {
          await rotateKey(keyId);
        }
      } catch (e) {
        developer.log('Error during automatic rotation of $keyId: $e',
            name: 'SecureKeyManager');
      }
    }
  }

  Future<bool> _shouldRotateKey(String keyId, KeyRotationConfig config) async {
    final metadata = await getKeyMetadata(keyId);
    if (metadata == null || !metadata.isActive) return false;

    final now = DateTime.now();

    switch (config.policy) {
      case KeyRotationPolicy.timeBasedRotation:
        if (config.rotationInterval != null) {
          final rotateAt = (metadata.lastRotated ?? metadata.createdAt)
              .add(config.rotationInterval!);
          return now.isAfter(rotateAt);
        }
        break;

      case KeyRotationPolicy.usageBasedRotation:
        if (config.maxUsageCount != null) {
          return metadata.usageCount >= config.maxUsageCount!;
        }
        break;

      case KeyRotationPolicy.automatic:
        // Rotate before expiry
        if (config.autoRotateBeforeExpiry && metadata.expiresAt != null) {
          final rotateAt =
              metadata.expiresAt!.subtract(config.preExpiryRotationWindow!);
          return now.isAfter(rotateAt);
        }
        break;

      case KeyRotationPolicy.manual:
        return false;
    }

    return false;
  }

  Future<void> _checkAndRotateKey(String keyId) async {
    final config = _rotationConfigs[keyId];
    if (config == null) return;

    if (await _shouldRotateKey(keyId, config)) {
      await rotateKey(keyId);
    }
  }

  Future<void> _cleanupOldKeyVersions(String keyId, int maxVersions) async {
    // This would implement cleanup of old key versions
    // For now, we'll just log the action
    developer.log('Cleaning up old versions for key: $keyId',
        name: 'SecureKeyManager');
  }

  Future<Uint8List> _hkdfExpand(
      Uint8List key, Uint8List salt, Uint8List info, int length) async {
    // Simplified HKDF implementation using HMAC-SHA256
    final hmac = Hmac(sha256, salt);
    final prk = hmac.convert(key).bytes;

    final hmacPrk = Hmac(sha256, prk);
    final iterations = (length / 32).ceil();
    final result = <int>[];

    Uint8List t = Uint8List(0);

    for (int i = 1; i <= iterations; i++) {
      final input = <int>[];
      input.addAll(t);
      input.addAll(info);
      input.add(i);

      t = Uint8List.fromList(hmacPrk.convert(input).bytes);
      result.addAll(t);
    }

    return Uint8List.fromList(result.take(length).toList());
  }

  Uint8List _computeSharedSecret(Uint8List privateKey, Uint8List publicKey) {
    // Simplified shared secret computation
    // In production, use proper ECDH or similar
    final combined = <int>[];
    combined.addAll(privateKey.take(32));
    combined.addAll(publicKey.take(32));

    return Uint8List.fromList(sha256.convert(combined).bytes);
  }
}
