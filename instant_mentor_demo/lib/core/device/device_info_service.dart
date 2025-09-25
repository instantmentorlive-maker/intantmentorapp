import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../error/app_error.dart';
import '../utils/logger.dart';
import '../utils/result.dart';

/// Simplified device information class
class DeviceInfo {
  final String deviceId;
  final String platform;
  final String platformVersion;
  final String appVersion;
  final String appBuildNumber;
  final String deviceModel;
  final String deviceBrand;

  const DeviceInfo({
    required this.deviceId,
    required this.platform,
    required this.platformVersion,
    required this.appVersion,
    required this.appBuildNumber,
    required this.deviceModel,
    required this.deviceBrand,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'platform': platform,
        'platformVersion': platformVersion,
        'appVersion': appVersion,
        'appBuildNumber': appBuildNumber,
        'deviceModel': deviceModel,
        'deviceBrand': deviceBrand,
      };

  /// Create from JSON
  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      deviceId: json['deviceId'] as String,
      platform: json['platform'] as String,
      platformVersion: json['platformVersion'] as String,
      appVersion: json['appVersion'] as String,
      appBuildNumber: json['appBuildNumber'] as String,
      deviceModel: json['deviceModel'] as String,
      deviceBrand: json['deviceBrand'] as String,
    );
  }

  @override
  String toString() =>
      'DeviceInfo(platform: $platform, model: $deviceModel, brand: $deviceBrand)';
}

/// Simplified device information service
class DeviceInfoService {
  static final DeviceInfoService _instance = DeviceInfoService._internal();
  factory DeviceInfoService() => _instance;
  DeviceInfoService._internal();

  /// Get comprehensive device information
  Future<Result<DeviceInfo>> getDeviceInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final deviceId = await _generateSecureDeviceId();

      final deviceInfo = DeviceInfo(
        deviceId: deviceId,
        platform: Platform.operatingSystem,
        platformVersion: Platform.operatingSystemVersion,
        appVersion: packageInfo.version,
        appBuildNumber: packageInfo.buildNumber,
        deviceModel: _getSimplifiedModel(),
        deviceBrand: _getSimplifiedBrand(),
      );

      Logger.info('DeviceInfoService: Device info retrieved successfully');
      return Success(deviceInfo);
    } catch (e) {
      Logger.error('DeviceInfoService: Error getting device info - $e');
      return Failure(
        AppGeneralError.unknown(e),
      );
    }
  }

  /// Get unique device ID (simplified secure approach)
  Future<String> _generateSecureDeviceId() async {
    try {
      // Create a unique identifier using platform info and app info
      final packageInfo = await PackageInfo.fromPlatform();
      final platformInfo =
          '${Platform.operatingSystem}-${Platform.operatingSystemVersion}';
      final appInfo = '${packageInfo.packageName}-${packageInfo.version}';

      // Create a hash from available system information
      final combinedInfo =
          '$platformInfo-$appInfo-${DateTime.now().millisecondsSinceEpoch}';
      final bytes = utf8.encode(combinedInfo);
      final digest = sha256.convert(bytes);

      return digest.toString().substring(0, 32); // Use first 32 characters
    } catch (e) {
      Logger.warning(
          'DeviceInfoService: Error generating device ID, using fallback');
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  /// Get device ID only
  Future<Result<String>> getDeviceId() async {
    try {
      final deviceId = await _generateSecureDeviceId();
      return Success(deviceId);
    } catch (e) {
      Logger.error('DeviceInfoService: Error getting device ID - $e');
      return Failure(
        AppGeneralError.unknown(e),
      );
    }
  }

  /// Get simplified model name
  String _getSimplifiedModel() {
    if (Platform.isIOS) {
      return 'iOS Device';
    } else if (Platform.isAndroid) {
      return 'Android Device';
    } else if (Platform.isWindows) {
      return 'Windows Device';
    } else if (Platform.isMacOS) {
      return 'macOS Device';
    } else if (Platform.isLinux) {
      return 'Linux Device';
    }
    return 'Unknown Device';
  }

  /// Get simplified brand name
  String _getSimplifiedBrand() {
    if (Platform.isIOS || Platform.isMacOS) {
      return 'Apple';
    } else if (Platform.isAndroid) {
      return 'Android';
    } else if (Platform.isWindows) {
      return 'Microsoft';
    }
    return 'Unknown';
  }

  /// Check if device supports biometric authentication
  bool get supportsBiometrics => Platform.isIOS || Platform.isAndroid;

  /// Get platform-specific information
  Map<String, String> getPlatformInfo() {
    return {
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
      'supportsBiometrics': supportsBiometrics.toString(),
    };
  }
}
