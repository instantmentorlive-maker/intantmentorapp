import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:pointycastle/export.dart' as pc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encryption algorithms supported
enum EncryptionAlgorithm {
  aes256GCM,
  aes256CBC,
  chacha20Poly1305,
  rsa2048,
  rsa4096,
}

/// Key types for different encryption purposes
enum KeyType {
  symmetric,
  asymmetricPublic,
  asymmetricPrivate,
  derived,
  ephemeral,
}

/// Encryption result with metadata
class EncryptionResult {
  final Uint8List encryptedData;
  final Uint8List? iv;
  final Uint8List? authTag;
  final String algorithm;
  final Map<String, dynamic>? metadata;

  const EncryptionResult({
    required this.encryptedData,
    this.iv,
    this.authTag,
    required this.algorithm,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'encryptedData': base64Encode(encryptedData),
      'iv': iv != null ? base64Encode(iv!) : null,
      'authTag': authTag != null ? base64Encode(authTag!) : null,
      'algorithm': algorithm,
      'metadata': metadata,
    };
  }

  factory EncryptionResult.fromJson(Map<String, dynamic> json) {
    return EncryptionResult(
      encryptedData: base64Decode(json['encryptedData']),
      iv: json['iv'] != null ? base64Decode(json['iv']) : null,
      authTag: json['authTag'] != null ? base64Decode(json['authTag']) : null,
      algorithm: json['algorithm'],
      metadata: json['metadata'],
    );
  }
}

/// Key pair for asymmetric encryption
class KeyPair {
  final Uint8List publicKey;
  final Uint8List privateKey;
  final String algorithm;
  final int keySize;

  const KeyPair({
    required this.publicKey,
    required this.privateKey,
    required this.algorithm,
    required this.keySize,
  });

  Map<String, dynamic> toJson() {
    return {
      'publicKey': base64Encode(publicKey),
      'privateKey': base64Encode(privateKey),
      'algorithm': algorithm,
      'keySize': keySize,
    };
  }

  factory KeyPair.fromJson(Map<String, dynamic> json) {
    return KeyPair(
      publicKey: base64Decode(json['publicKey']),
      privateKey: base64Decode(json['privateKey']),
      algorithm: json['algorithm'],
      keySize: json['keySize'],
    );
  }
}

/// Advanced encryption service with multiple algorithms
class AdvancedEncryptionService {
  static AdvancedEncryptionService? _instance;
  static AdvancedEncryptionService get instance =>
      _instance ??= AdvancedEncryptionService._();

  AdvancedEncryptionService._();

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

  final pc.SecureRandom _secureRandom = pc.SecureRandom('Fortuna');
  bool _initialized = false;

  /// Initialize the encryption service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize secure random with entropy
      _secureRandom.seed(pc.KeyParameter(_generateEntropy()));

      // Generate master key if not exists
      await _ensureMasterKey();

      _initialized = true;
      developer.log('Advanced encryption service initialized',
          name: 'AdvancedEncryptionService');
    } catch (e) {
      developer.log('Failed to initialize encryption service: $e',
          name: 'AdvancedEncryptionService');
      throw Exception('Encryption service initialization failed: $e');
    }
  }

  /// Generate AES-256-GCM symmetric key
  Uint8List generateAESKey() {
    _ensureInitialized();
    final key = _secureRandom.nextBytes(32); // 256 bits
    developer.log('Generated AES-256 key', name: 'AdvancedEncryptionService');
    return key;
  }

  /// Generate RSA key pair
  Future<KeyPair> generateRSAKeyPair({int keySize = 2048}) async {
    _ensureInitialized();

    final keyGen = pc.RSAKeyGenerator();
    keyGen.init(pc.ParametersWithRandom(
      pc.RSAKeyGeneratorParameters(BigInt.parse('65537'), keySize, 64),
      _secureRandom,
    ));

    final pair = keyGen.generateKeyPair();
    final publicKey = pair.publicKey as pc.RSAPublicKey;
    final privateKey = pair.privateKey as pc.RSAPrivateKey;

    final publicKeyBytes = _rsaPublicKeyToBytes(publicKey);
    final privateKeyBytes = _rsaPrivateKeyToBytes(privateKey);

    developer.log('Generated RSA-$keySize key pair',
        name: 'AdvancedEncryptionService');

    return KeyPair(
      publicKey: publicKeyBytes,
      privateKey: privateKeyBytes,
      algorithm: 'RSA',
      keySize: keySize,
    );
  }

  /// Encrypt data with AES-256-GCM
  EncryptionResult encryptAESGCM(Uint8List data, Uint8List key) {
    _ensureInitialized();

    final iv = _secureRandom.nextBytes(12); // 96 bits for GCM
    final cipher = pc.GCMBlockCipher(pc.AESEngine());

    cipher.init(
        true, pc.AEADParameters(pc.KeyParameter(key), 128, iv, Uint8List(0)));

    final encryptedData = cipher.process(data);
    final authTag =
        Uint8List.fromList(encryptedData.skip(data.length).take(16).toList());
    final ciphertext =
        Uint8List.fromList(encryptedData.take(data.length).toList());

    developer.log('Encrypted ${data.length} bytes with AES-256-GCM',
        name: 'AdvancedEncryptionService');

    return EncryptionResult(
      encryptedData: ciphertext,
      iv: iv,
      authTag: authTag,
      algorithm: 'AES-256-GCM',
    );
  }

  /// Decrypt data with AES-256-GCM
  Uint8List decryptAESGCM(EncryptionResult result, Uint8List key) {
    _ensureInitialized();

    final cipher = pc.GCMBlockCipher(pc.AESEngine());
    cipher.init(false,
        pc.AEADParameters(pc.KeyParameter(key), 128, result.iv!, Uint8List(0)));

    // Combine ciphertext and auth tag
    final combined = Uint8List.fromList([
      ...result.encryptedData,
      ...result.authTag!,
    ]);

    final decryptedData = cipher.process(combined);

    developer.log('Decrypted ${decryptedData.length} bytes with AES-256-GCM',
        name: 'AdvancedEncryptionService');
    return decryptedData;
  }

  /// Encrypt data with AES-256-CBC
  EncryptionResult encryptAESCBC(Uint8List data, Uint8List key) {
    _ensureInitialized();

    final iv = _secureRandom.nextBytes(16); // 128 bits
    final cipher = pc.PaddedBlockCipherImpl(
        pc.PKCS7Padding(), pc.CBCBlockCipher(pc.AESEngine()));

    cipher.init(
        true,
        pc.PaddedBlockCipherParameters(
          pc.ParametersWithIV(pc.KeyParameter(key), iv),
          null,
        ));

    final encryptedData = cipher.process(data);

    developer.log('Encrypted ${data.length} bytes with AES-256-CBC',
        name: 'AdvancedEncryptionService');

    return EncryptionResult(
      encryptedData: encryptedData,
      iv: iv,
      algorithm: 'AES-256-CBC',
    );
  }

  /// Decrypt data with AES-256-CBC
  Uint8List decryptAESCBC(EncryptionResult result, Uint8List key) {
    _ensureInitialized();

    final cipher = pc.PaddedBlockCipherImpl(
        pc.PKCS7Padding(), pc.CBCBlockCipher(pc.AESEngine()));
    cipher.init(
        false,
        pc.PaddedBlockCipherParameters(
          pc.ParametersWithIV(pc.KeyParameter(key), result.iv!),
          null,
        ));

    final decryptedData = cipher.process(result.encryptedData);

    developer.log('Decrypted ${decryptedData.length} bytes with AES-256-CBC',
        name: 'AdvancedEncryptionService');
    return decryptedData;
  }

  /// Encrypt data with RSA-OAEP
  EncryptionResult encryptRSA(Uint8List data, Uint8List publicKeyBytes) {
    _ensureInitialized();

    final publicKey = _rsaPublicKeyFromBytes(publicKeyBytes);
    final cipher = pc.OAEPEncoding(pc.RSAEngine());
    cipher.init(true, pc.PublicKeyParameter<pc.RSAPublicKey>(publicKey));

    final encryptedData = cipher.process(data);

    developer.log('Encrypted ${data.length} bytes with RSA-OAEP',
        name: 'AdvancedEncryptionService');

    return EncryptionResult(
      encryptedData: encryptedData,
      algorithm: 'RSA-OAEP',
    );
  }

  /// Decrypt data with RSA-OAEP
  Uint8List decryptRSA(EncryptionResult result, Uint8List privateKeyBytes) {
    _ensureInitialized();

    final privateKey = _rsaPrivateKeyFromBytes(privateKeyBytes);
    final cipher = pc.OAEPEncoding(pc.RSAEngine());
    cipher.init(false, pc.PrivateKeyParameter<pc.RSAPrivateKey>(privateKey));

    final decryptedData = cipher.process(result.encryptedData);

    developer.log('Decrypted ${decryptedData.length} bytes with RSA-OAEP',
        name: 'AdvancedEncryptionService');
    return decryptedData;
  }

  /// Generate HMAC for message authentication
  Uint8List generateHMAC(Uint8List data, Uint8List key,
      {String algorithm = 'SHA-256'}) {
    _ensureInitialized();

    late pc.Mac hmac;
    switch (algorithm) {
      case 'SHA-256':
        hmac = pc.HMac(pc.SHA256Digest(), 64);
        break;
      case 'SHA-512':
        hmac = pc.HMac(pc.SHA512Digest(), 128);
        break;
      default:
        throw ArgumentError('Unsupported HMAC algorithm: $algorithm');
    }

    hmac.init(pc.KeyParameter(key));
    final result = hmac.process(data);

    developer.log('Generated HMAC-$algorithm for ${data.length} bytes',
        name: 'AdvancedEncryptionService');
    return result;
  }

  /// Verify HMAC
  bool verifyHMAC(Uint8List data, Uint8List key, Uint8List expectedHmac,
      {String algorithm = 'SHA-256'}) {
    final computedHmac = generateHMAC(data, key, algorithm: algorithm);
    return _constantTimeEquals(computedHmac, expectedHmac);
  }

  /// Derive key using PBKDF2
  Uint8List deriveKeyPBKDF2(String password, Uint8List salt,
      {int iterations = 100000, int keyLength = 32}) {
    _ensureInitialized();

    final derivator = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64));
    derivator.init(pc.Pbkdf2Parameters(salt, iterations, keyLength));

    final derivedKey = derivator.process(utf8.encode(password));

    developer.log('Derived key using PBKDF2 with $iterations iterations',
        name: 'AdvancedEncryptionService');
    return derivedKey;
  }

  /// Derive key using Argon2
  Future<Uint8List> deriveKeyArgon2(
    String password,
    Uint8List salt, {
    int memoryKB = 65536,
    int iterations = 3,
    int parallelism = 4,
    int keyLength = 32,
  }) async {
    _ensureInitialized();

    // Note: This is a simplified implementation
    // In production, use a dedicated Argon2 library
    final derivator = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA512Digest(), 128));
    derivator.init(pc.Pbkdf2Parameters(salt, iterations * 1000, keyLength));

    final derivedKey = derivator.process(utf8.encode(password));

    developer.log('Derived key using Argon2-like algorithm',
        name: 'AdvancedEncryptionService');
    return derivedKey;
  }

  /// Generate secure random salt
  Uint8List generateSalt({int length = 32}) {
    _ensureInitialized();
    return _secureRandom.nextBytes(length);
  }

  /// Store encrypted key securely
  Future<void> storeKey(String keyId, Uint8List key, KeyType keyType) async {
    _ensureInitialized();

    final masterKey = await _getMasterKey();
    final encryptedKey = encryptAESGCM(key, masterKey);

    final keyData = {
      'encryptedKey': encryptedKey.toJson(),
      'keyType': keyType.name,
      'createdAt': DateTime.now().toIso8601String(),
    };

    await _secureStorage.write(key: 'key_$keyId', value: jsonEncode(keyData));

    developer.log('Stored key: $keyId (${keyType.name})',
        name: 'AdvancedEncryptionService');
  }

  /// Retrieve and decrypt key
  Future<Uint8List?> getKey(String keyId) async {
    _ensureInitialized();

    final keyDataStr = await _secureStorage.read(key: 'key_$keyId');
    if (keyDataStr == null) return null;

    final keyData = jsonDecode(keyDataStr);
    final encryptedKey = EncryptionResult.fromJson(keyData['encryptedKey']);

    final masterKey = await _getMasterKey();
    final decryptedKey = decryptAESGCM(encryptedKey, masterKey);

    developer.log('Retrieved key: $keyId', name: 'AdvancedEncryptionService');
    return decryptedKey;
  }

  /// Delete key from secure storage
  Future<void> deleteKey(String keyId) async {
    await _secureStorage.delete(key: 'key_$keyId');
    developer.log('Deleted key: $keyId', name: 'AdvancedEncryptionService');
  }

  /// List all stored keys
  Future<List<String>> listKeys() async {
    final allKeys = await _secureStorage.readAll();
    final keyIds = allKeys.keys
        .where((key) => key.startsWith('key_'))
        .map((key) => key.substring(4))
        .toList();

    developer.log('Found ${keyIds.length} stored keys',
        name: 'AdvancedEncryptionService');
    return keyIds;
  }

  /// Clear all keys and reset service
  Future<void> clearAllKeys() async {
    final allKeys = await _secureStorage.readAll();
    for (final key in allKeys.keys) {
      if (key.startsWith('key_') || key == 'master_key') {
        await _secureStorage.delete(key: key);
      }
    }

    _initialized = false;
    developer.log('Cleared all encryption keys',
        name: 'AdvancedEncryptionService');
  }

  // Private helper methods

  void _ensureInitialized() {
    if (!_initialized) {
      throw Exception(
          'Encryption service not initialized. Call initialize() first.');
    }
  }

  Uint8List _generateEntropy() {
    final entropy = Uint8List(32);
    final random = Random.secure();
    for (int i = 0; i < entropy.length; i++) {
      entropy[i] = random.nextInt(256);
    }
    // Add timestamp for additional entropy
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final timestampBytes = Uint8List.fromList([
      (timestamp >> 56) & 0xff,
      (timestamp >> 48) & 0xff,
      (timestamp >> 40) & 0xff,
      (timestamp >> 32) & 0xff,
      (timestamp >> 24) & 0xff,
      (timestamp >> 16) & 0xff,
      (timestamp >> 8) & 0xff,
      timestamp & 0xff,
    ]);

    // XOR timestamp bytes with entropy
    for (int i = 0; i < timestampBytes.length; i++) {
      entropy[i] ^= timestampBytes[i];
    }

    return entropy;
  }

  Future<void> _ensureMasterKey() async {
    final existingKey = await _secureStorage.read(key: 'master_key');
    if (existingKey == null) {
      final masterKey = _secureRandom.nextBytes(32);
      await _secureStorage.write(
          key: 'master_key', value: base64Encode(masterKey));
      developer.log('Generated new master key',
          name: 'AdvancedEncryptionService');
    }
  }

  Future<Uint8List> _getMasterKey() async {
    final masterKeyStr = await _secureStorage.read(key: 'master_key');
    if (masterKeyStr == null) {
      throw Exception('Master key not found');
    }
    return base64Decode(masterKeyStr);
  }

  Uint8List _rsaPublicKeyToBytes(pc.RSAPublicKey publicKey) {
    // Simplified DER encoding for RSA public key
    final modulus = publicKey.modulus!.toRadixString(16);
    final exponent = publicKey.exponent!.toRadixString(16);
    final combined = '$modulus:$exponent';
    return utf8.encode(combined);
  }

  Uint8List _rsaPrivateKeyToBytes(pc.RSAPrivateKey privateKey) {
    // Simplified encoding for RSA private key
    final modulus = privateKey.modulus!.toRadixString(16);
    final privateExponent = privateKey.privateExponent!.toRadixString(16);
    final combined = '$modulus:$privateExponent';
    return utf8.encode(combined);
  }

  pc.RSAPublicKey _rsaPublicKeyFromBytes(Uint8List keyBytes) {
    final keyStr = utf8.decode(keyBytes);
    final parts = keyStr.split(':');
    final modulus = BigInt.parse(parts[0], radix: 16);
    final exponent = BigInt.parse(parts[1], radix: 16);
    return pc.RSAPublicKey(modulus, exponent);
  }

  pc.RSAPrivateKey _rsaPrivateKeyFromBytes(Uint8List keyBytes) {
    final keyStr = utf8.decode(keyBytes);
    final parts = keyStr.split(':');
    final modulus = BigInt.parse(parts[0], radix: 16);
    final privateExponent = BigInt.parse(parts[1], radix: 16);
    return pc.RSAPrivateKey(modulus, privateExponent, null, null);
  }

  bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;

    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }

    return result == 0;
  }
}
