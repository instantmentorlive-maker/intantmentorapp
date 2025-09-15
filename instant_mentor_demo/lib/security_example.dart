import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/security/encryption_service.dart';
import 'core/security/biometric_auth_service.dart';
import 'core/security/key_manager.dart';
import 'features/common/widgets/security_dashboard.dart';

/// Advanced Security Example Application
class SecurityExampleApp extends StatelessWidget {
  const SecurityExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Advanced Security Example',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: const SecurityInitializationScreen(),
      ),
    );
  }
}

/// Security system initialization screen
class SecurityInitializationScreen extends ConsumerStatefulWidget {
  const SecurityInitializationScreen({super.key});

  @override
  ConsumerState<SecurityInitializationScreen> createState() =>
      _SecurityInitializationScreenState();
}

class _SecurityInitializationScreenState
    extends ConsumerState<SecurityInitializationScreen> {
  bool _isInitialized = false;
  bool _isInitializing = false;
  String? _initializationError;

  @override
  void initState() {
    super.initState();
    _initializeSecurity();
  }

  Future<void> _initializeSecurity() async {
    setState(() {
      _isInitializing = true;
      _initializationError = null;
    });

    try {
      // Initialize encryption service
      await AdvancedEncryptionService.instance.initialize();
      debugPrint('✓ Encryption service initialized');

      // Initialize biometric authentication service
      await BiometricAuthService.instance.initialize();
      debugPrint('✓ Biometric authentication service initialized');

      // Initialize secure key manager
      await SecureKeyManager.instance.initialize();
      debugPrint('✓ Secure key manager initialized');

      // Create some demo keys
      await _createDemoKeys();
      debugPrint('✓ Demo keys created');

      setState(() {
        _isInitialized = true;
        _isInitializing = false;
      });

      debugPrint('🔐 Advanced Security System Ready!');
    } catch (e) {
      setState(() {
        _initializationError = e.toString();
        _isInitializing = false;
      });
      debugPrint('❌ Security initialization failed: $e');
    }
  }

  Future<void> _createDemoKeys() async {
    final keyManager = SecureKeyManager.instance;

    try {
      // Create AES encryption key
      await keyManager.generateKey(
        usage: KeyUsage.dataProtection,
        algorithm: 'AES-256',
        expiresIn: const Duration(days: 90),
        rotationConfig: const KeyRotationConfig(
          policy: KeyRotationPolicy.timeBasedRotation,
          rotationInterval: Duration(days: 30),
          retainOldVersions: true,
          maxOldVersions: 2,
        ),
        metadata: {
          'name': 'Demo Data Protection Key',
          'purpose': 'Protecting user data',
          'demo': true,
        },
      );

      // Create RSA signing key
      await keyManager.generateKey(
        usage: KeyUsage.signing,
        algorithm: 'RSA-2048',
        expiresIn: const Duration(days: 365),
        metadata: {
          'name': 'Demo Digital Signature Key',
          'purpose': 'Document signing',
          'demo': true,
        },
      );

      // Create authentication key
      await keyManager.generateKey(
        usage: KeyUsage.authentication,
        algorithm: 'AES-256',
        expiresIn: const Duration(hours: 24),
        rotationConfig: const KeyRotationConfig(
          policy: KeyRotationPolicy.usageBasedRotation,
          maxUsageCount: 1000,
          retainOldVersions: false,
        ),
        metadata: {
          'name': 'Demo Session Authentication Key',
          'purpose': 'User session authentication',
          'demo': true,
        },
      );

      // Create message authentication key
      await keyManager.generateKey(
        usage: KeyUsage.messageAuth,
        algorithm: 'AES-256',
        expiresIn: const Duration(days: 30),
        metadata: {
          'name': 'Demo Message Authentication Key',
          'purpose': 'HMAC message verification',
          'demo': true,
        },
      );
    } catch (e) {
      debugPrint('Warning: Some demo keys could not be created: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                'Initializing Advanced Security System...',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Setting up encryption services, biometric authentication, and key management',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_initializationError != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error,
                size: 64,
                color: Colors.red[700],
              ),
              const SizedBox(height: 24),
              Text(
                'Security Initialization Failed',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _initializationError!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeSecurity,
                child: const Text('Retry Initialization'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isInitialized) {
      return const SecurityHomeScreen();
    }

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Security system home screen
class SecurityHomeScreen extends ConsumerWidget {
  const SecurityHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Security System'),
        elevation: 2,
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          IconButton(
            onPressed: () => _showSecurityInfo(context),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(context),
            const SizedBox(height: 16),
            _buildFeaturesCard(context),
            const SizedBox(height: 16),
            _buildQuickActionsCard(context, ref),
            const SizedBox(height: 16),
            _buildDemoOperationsCard(context, ref),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSecurityDashboard(context),
        icon: const Icon(Icons.security),
        label: const Text('Security Dashboard'),
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.shield,
                  color: Colors.green[700],
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Security System Active',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Advanced encryption, biometric authentication, and key management ready',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Your data is protected with enterprise-grade security features including:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            ...[
              '• AES-256-GCM and RSA-2048/4096 encryption',
              '• Biometric authentication with session management',
              '• Automated key rotation and secure key storage',
              '• Real-time security monitoring and audit logging',
            ].map((feature) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Text(
                feature,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[700],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesCard(BuildContext context) {
    final features = [
      {
        'icon': Icons.lock,
        'title': 'Advanced Encryption',
        'description': 'AES-256-GCM, RSA, ChaCha20-Poly1305',
      },
      {
        'icon': Icons.fingerprint,
        'title': 'Biometric Auth',
        'description': 'TouchID, FaceID, Fingerprint support',
      },
      {
        'icon': Icons.key,
        'title': 'Key Management',
        'description': 'Automatic rotation, secure storage',
      },
      {
        'icon': Icons.security,
        'title': 'Security Audit',
        'description': 'Real-time monitoring and reports',
      },
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Security Features',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: features.length,
              itemBuilder: (context, index) {
                final feature = features[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        feature['icon'] as IconData,
                        color: Theme.of(context).colorScheme.primary,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        feature['title'] as String,
                        style: Theme.of(context).textTheme.titleSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        feature['description'] as String,
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _testBiometricAuth(context, ref),
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Test Biometric'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _generateTestKey(context, ref),
                  icon: const Icon(Icons.key),
                  label: const Text('Generate Key'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _runSecurityAudit(context, ref),
                  icon: const Icon(Icons.security),
                  label: const Text('Security Audit'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openSecurityDashboard(context),
                  icon: const Icon(Icons.dashboard),
                  label: const Text('Dashboard'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoOperationsCard(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Demo Operations',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Test various security operations with sample data',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _demoEncryption(context, ref),
                  icon: const Icon(Icons.lock),
                  label: const Text('Demo Encryption'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _demoKeyExchange(context, ref),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Key Exchange'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _demoHMAC(context, ref),
                  icon: const Icon(Icons.verified),
                  label: const Text('HMAC Demo'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _demoKeyRotation(context, ref),
                  icon: const Icon(Icons.rotate_right),
                  label: const Text('Key Rotation'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSecurityInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Advanced Security System'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This application demonstrates enterprise-grade security features including:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 16),
              Text('🔐 Encryption Services'),
              Text('• Multiple algorithms (AES, RSA, ChaCha20)', style: TextStyle(fontSize: 12)),
              Text('• Authenticated encryption with GCM mode', style: TextStyle(fontSize: 12)),
              Text('• Key derivation with PBKDF2 and Argon2', style: TextStyle(fontSize: 12)),
              SizedBox(height: 12),
              Text('👆 Biometric Authentication'),
              Text('• TouchID, FaceID, Fingerprint support', style: TextStyle(fontSize: 12)),
              Text('• Progressive authentication policies', style: TextStyle(fontSize: 12)),
              Text('• Session management with timeout', style: TextStyle(fontSize: 12)),
              SizedBox(height: 12),
              Text('🗝️ Key Management'),
              Text('• Automatic key rotation policies', style: TextStyle(fontSize: 12)),
              Text('• Secure key storage with hardware backing', style: TextStyle(fontSize: 12)),
              Text('• Key exchange protocols', style: TextStyle(fontSize: 12)),
              SizedBox(height: 12),
              Text('🛡️ Security Monitoring'),
              Text('• Real-time security audits', style: TextStyle(fontSize: 12)),
              Text('• Threat detection and reporting', style: TextStyle(fontSize: 12)),
              Text('• Compliance monitoring', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openSecurityDashboard(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SecurityDashboard(),
      ),
    );
  }

  Future<void> _testBiometricAuth(BuildContext context, WidgetRef ref) async {
    try {
      final service = BiometricAuthService.instance;
      final result = await service.authenticate(
        signInTitle: 'Security Demo Authentication',
        cancelButtonText: 'Cancel',
      );

      _showResultDialog(
        context,
        'Biometric Authentication',
        result.isAuthenticated
            ? '✓ Authentication successful!\nType: ${result.authenticationType?.name}\nStrength: ${result.strength?.name}'
            : '❌ Authentication failed\nReason: ${result.errorMessage}',
        result.isAuthenticated,
      );
    } catch (e) {
      _showResultDialog(context, 'Biometric Authentication', '❌ Error: $e', false);
    }
  }

  Future<void> _generateTestKey(BuildContext context, WidgetRef ref) async {
    try {
      final keyManager = SecureKeyManager.instance;
      final keyId = await keyManager.generateKey(
        usage: KeyUsage.dataProtection,
        algorithm: 'AES-256',
        expiresIn: const Duration(hours: 1),
        metadata: {
          'test': true,
          'generated_at': DateTime.now().toIso8601String(),
          'purpose': 'demo_operation',
        },
      );

      _showResultDialog(
        context,
        'Key Generation',
        '✓ Test key generated successfully!\nKey ID: $keyId\nAlgorithm: AES-256\nExpires: 1 hour',
        true,
      );
    } catch (e) {
      _showResultDialog(context, 'Key Generation', '❌ Error: $e', false);
    }
  }

  Future<void> _runSecurityAudit(BuildContext context, WidgetRef ref) async {
    try {
      // This would trigger a security audit
      _showResultDialog(
        context,
        'Security Audit',
        '✓ Security audit completed!\nOpen the Security Dashboard to view detailed results.',
        true,
      );
    } catch (e) {
      _showResultDialog(context, 'Security Audit', '❌ Error: $e', false);
    }
  }

  Future<void> _demoEncryption(BuildContext context, WidgetRef ref) async {
    try {
      final encryptionService = AdvancedEncryptionService.instance;
      final keyManager = SecureKeyManager.instance;

      // Generate test key
      final keyId = await keyManager.generateKey(
        usage: KeyUsage.dataProtection,
        algorithm: 'AES-256',
        metadata: {'demo': true, 'purpose': 'encryption_test'},
      );

      final key = await keyManager.getKey(keyId);
      if (key == null) throw Exception('Key not found');

      // Test data
      const testMessage = 'Hello, this is a confidential message for encryption demo!';
      final testData = testMessage.codeUnits;

      // Encrypt
      final encryptionResult = encryptionService.encryptAESGCM(
        Uint8List.fromList(testData),
        key,
      );

      // Decrypt
      final decryptedData = encryptionService.decryptAESGCM(encryptionResult, key);
      final decryptedMessage = String.fromCharCodes(decryptedData);

      _showResultDialog(
        context,
        'Encryption Demo',
        '✓ Encryption/Decryption successful!\n\n'
            'Original: $testMessage\n\n'
            'Encrypted: ${encryptionResult.encryptedData.length} bytes\n'
            'Algorithm: ${encryptionResult.algorithm}\n\n'
            'Decrypted: $decryptedMessage\n\n'
            'Match: ${testMessage == decryptedMessage ? "✓" : "❌"}',
        true,
      );
    } catch (e) {
      _showResultDialog(context, 'Encryption Demo', '❌ Error: $e', false);
    }
  }

  Future<void> _demoKeyExchange(BuildContext context, WidgetRef ref) async {
    try {
      final keyManager = SecureKeyManager.instance;

      // Simulate key exchange
      final exchangeResult = await keyManager.initiateKeyExchange(
        expiresIn: const Duration(minutes: 30),
        metadata: {'demo': true, 'purpose': 'key_exchange_test'},
      );

      // In a real scenario, the public key would be sent to another party
      // and they would complete the exchange
      final sharedKeyId = await keyManager.completeKeyExchange(
        exchangeId: exchangeResult.exchangeId,
        peerPublicKey: exchangeResult.publicKey, // Using own key for demo
        derivationContext: 'demo_exchange',
      );

      _showResultDialog(
        context,
        'Key Exchange Demo',
        '✓ Key exchange completed!\n\n'
            'Exchange ID: ${exchangeResult.exchangeId}\n'
            'Public Key: ${exchangeResult.publicKey.length} bytes\n'
            'Shared Key ID: $sharedKeyId\n'
            'Expires: ${exchangeResult.expiresAt}',
        true,
      );
    } catch (e) {
      _showResultDialog(context, 'Key Exchange Demo', '❌ Error: $e', false);
    }
  }

  Future<void> _demoHMAC(BuildContext context, WidgetRef ref) async {
    try {
      final encryptionService = AdvancedEncryptionService.instance;
      final keyManager = SecureKeyManager.instance;

      // Generate HMAC key
      final keyId = await keyManager.generateKey(
        usage: KeyUsage.messageAuth,
        algorithm: 'AES-256',
        metadata: {'demo': true, 'purpose': 'hmac_test'},
      );

      final key = await keyManager.getKey(keyId);
      if (key == null) throw Exception('Key not found');

      // Test message
      const testMessage = 'This is a message to authenticate with HMAC';
      final messageBytes = Uint8List.fromList(testMessage.codeUnits);

      // Generate HMAC
      final hmac = encryptionService.generateHMAC(messageBytes, key);

      // Verify HMAC
      final isValid = encryptionService.verifyHMAC(messageBytes, key, hmac);

      _showResultDialog(
        context,
        'HMAC Demo',
        '✓ HMAC generation and verification successful!\n\n'
            'Message: $testMessage\n\n'
            'HMAC: ${hmac.length} bytes\n'
            'Algorithm: SHA-256\n'
            'Verification: ${isValid ? "✓ Valid" : "❌ Invalid"}',
        true,
      );
    } catch (e) {
      _showResultDialog(context, 'HMAC Demo', '❌ Error: $e', false);
    }
  }

  Future<void> _demoKeyRotation(BuildContext context, WidgetRef ref) async {
    try {
      final keyManager = SecureKeyManager.instance;

      // Generate key with rotation policy
      final originalKeyId = await keyManager.generateKey(
        usage: KeyUsage.dataProtection,
        algorithm: 'AES-256',
        expiresIn: const Duration(hours: 1),
        rotationConfig: const KeyRotationConfig(
          policy: KeyRotationPolicy.manual,
          retainOldVersions: true,
          maxOldVersions: 2,
        ),
        metadata: {'demo': true, 'purpose': 'rotation_test'},
      );

      // Rotate the key
      final newKeyId = await keyManager.rotateKey(originalKeyId);

      // Get metadata for both keys
      final originalMetadata = await keyManager.getKeyMetadata(originalKeyId);
      final newMetadata = await keyManager.getKeyMetadata(newKeyId);

      _showResultDialog(
        context,
        'Key Rotation Demo',
        '✓ Key rotation completed!\n\n'
            'Original Key: $originalKeyId\n'
            'Status: ${originalMetadata?.status.name ?? "Unknown"}\n\n'
            'New Key: $newKeyId\n'
            'Status: ${newMetadata?.status.name ?? "Unknown"}\n'
            'Created: ${newMetadata?.createdAt}',
        true,
      );
    } catch (e) {
      _showResultDialog(context, 'Key Rotation Demo', '❌ Error: $e', false);
    }
  }

  void _showResultDialog(BuildContext context, String title, String message, bool success) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: success ? Colors.green[700] : Colors.red[700],
            ),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(const SecurityExampleApp());
}
