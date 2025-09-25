import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart' as http_parser;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';

/// HTTP response cache entry
class CacheEntry {
  final String key;
  final Map<String, dynamic> headers;
  final dynamic data;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? etag;
  final DateTime? lastModified;

  CacheEntry({
    required this.key,
    required this.headers,
    required this.data,
    required this.createdAt,
    this.expiresAt,
    this.etag,
    this.lastModified,
  });

  bool get isExpired {
    if (expiresAt != null) {
      return DateTime.now().isAfter(expiresAt!);
    }
    return false;
  }

  bool get isStale {
    // Consider data stale after 5 minutes without explicit expiry
    final maxAge = expiresAt ?? createdAt.add(const Duration(minutes: 5));
    return DateTime.now().isAfter(maxAge);
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'headers': headers,
        'data': data,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'etag': etag,
        'lastModified': lastModified?.toIso8601String(),
      };

  static CacheEntry fromJson(Map<String, dynamic> json) => CacheEntry(
        key: json['key'],
        headers: Map<String, dynamic>.from(json['headers']),
        data: json['data'],
        createdAt: DateTime.parse(json['createdAt']),
        expiresAt: json['expiresAt'] != null
            ? DateTime.parse(json['expiresAt'])
            : null,
        etag: json['etag'],
        lastModified: json['lastModified'] != null
            ? DateTime.parse(json['lastModified'])
            : null,
      );
}

/// HTTP response cache management with multiple storage strategies
class HttpCache {
  // Reserved for future use (LRU markers); avoid unused warning
  // static const String _memoryPrefix = 'http_cache_memory_';
  static const String _diskPrefix = 'http_cache_disk_';
  static const int _maxMemoryEntries = 100;
  static const int _maxDiskSizeMB = 50;

  // Memory cache for frequently accessed data
  static final Map<String, CacheEntry> _memoryCache = {};
  static SharedPreferences? _prefs;

  /// Initialize the cache system
  static Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _cleanupExpiredEntries();
      Logger.info('HTTP Cache initialized');
    } catch (e) {
      Logger.error('Failed to initialize HTTP cache: $e');
    }
  }

  /// Generate cache key from request options
  static String _generateCacheKey(RequestOptions options) {
    final uri = options.uri.toString();
    final method = options.method;
    final headers = _normalizeHeaders(options.headers);
    final data = options.data?.toString() ?? '';

    final combined = '$method|$uri|$headers|$data';
    return sha256.convert(utf8.encode(combined)).toString();
  }

  /// Normalize headers for consistent caching
  static String _normalizeHeaders(Map<String, dynamic> headers) {
    final normalized = Map<String, String>.from(headers);
    // Remove headers that shouldn't affect caching
    normalized.remove('Authorization');
    normalized.remove('User-Agent');
    normalized.remove('X-Request-ID');

    final keys = normalized.keys.toList()..sort();
    return keys.map((key) => '$key:${normalized[key]}').join('|');
  }

  /// Check if response should be cached
  static bool _shouldCache(Response response) {
    final statusCode = response.statusCode;
    final headers = response.headers;

    // Don't cache error responses
    if (statusCode == null || statusCode >= 400) {
      return false;
    }

    // Don't cache if explicitly told not to
    final cacheControl = headers.value('cache-control')?.toLowerCase();
    if (cacheControl?.contains('no-cache') == true ||
        cacheControl?.contains('no-store') == true) {
      return false;
    }

    // Cache GET requests by default
    return response.requestOptions.method.toUpperCase() == 'GET';
  }

  /// Parse cache control headers
  static DateTime? _parseCacheExpiry(Response response) {
    final headers = response.headers;
    final cacheControl = headers.value('cache-control');

    if (cacheControl != null) {
      final maxAgeMatch = RegExp(r'max-age=(\d+)').firstMatch(cacheControl);
      if (maxAgeMatch != null) {
        final maxAge = int.parse(maxAgeMatch.group(1)!);
        return DateTime.now().add(Duration(seconds: maxAge));
      }
    }

    final expiresHeader = headers.value('expires');
    if (expiresHeader != null) {
      try {
        return http_parser.parseHttpDate(expiresHeader);
      } catch (e) {
        Logger.warning('Failed to parse expires header: $expiresHeader');
      }
    }

    return null;
  }

  /// Store response in cache
  static Future<void> put(Response response) async {
    if (!_shouldCache(response)) return;

    try {
      final key = _generateCacheKey(response.requestOptions);
      final headers = response.headers.map;
      final expiresAt = _parseCacheExpiry(response);
      final etag = headers['etag']?.first;
      final lastModified = headers['last-modified']?.first;

      final entry = CacheEntry(
        key: key,
        headers: Map<String, dynamic>.from(headers),
        data: response.data,
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
        etag: etag,
        lastModified: lastModified != null
            ? http_parser.parseHttpDate(lastModified)
            : null,
      );

      // Store in memory cache first
      await _putMemory(key, entry);

      // Store in disk cache for persistence
      await _putDisk(key, entry);

      Logger.debug('Cached response for key: ${key.substring(0, 8)}...');
    } catch (e) {
      Logger.error('Failed to cache response: $e');
    }
  }

  /// Get cached response
  static Future<CacheEntry?> get(RequestOptions options) async {
    final key = _generateCacheKey(options);

    // Try memory cache first
    CacheEntry? entry = _getMemory(key);

    // Try disk cache if not in memory
    entry ??= await _getDisk(key);

    if (entry != null) {
      // Move to memory cache if found on disk
      if (!_memoryCache.containsKey(key)) {
        await _putMemory(key, entry);
      }

      Logger.debug('Cache hit for key: ${key.substring(0, 8)}...');
      return entry;
    }

    Logger.debug('Cache miss for key: ${key.substring(0, 8)}...');
    return null;
  }

  /// Check if cached response is valid
  static bool isValidForRequest(CacheEntry entry, RequestOptions options) {
    // Check if entry is expired
    if (entry.isExpired) {
      return false;
    }

    // Check cache control headers from original request
    final cacheControl = options.headers['cache-control']?.toLowerCase();
    if (cacheControl?.contains('no-cache') == true) {
      return false;
    }

    return true;
  }

  /// Store in memory cache
  static Future<void> _putMemory(String key, CacheEntry entry) async {
    // Implement LRU eviction if memory cache is full
    if (_memoryCache.length >= _maxMemoryEntries) {
      final oldestKey = _memoryCache.keys.first;
      _memoryCache.remove(oldestKey);
    }

    _memoryCache[key] = entry;
  }

  /// Get from memory cache
  static CacheEntry? _getMemory(String key) {
    final entry = _memoryCache[key];
    if (entry != null && !entry.isExpired) {
      return entry;
    } else if (entry != null) {
      _memoryCache.remove(key);
    }
    return null;
  }

  /// Store in disk cache
  static Future<void> _putDisk(String key, CacheEntry entry) async {
    if (_prefs == null) return;

    try {
      final json = jsonEncode(entry.toJson());
      await _prefs!.setString('$_diskPrefix$key', json);

      // Manage disk cache size
      await _manageDiskCacheSize();
    } catch (e) {
      Logger.error('Failed to store in disk cache: $e');
    }
  }

  /// Get from disk cache
  static Future<CacheEntry?> _getDisk(String key) async {
    if (_prefs == null) return null;

    try {
      final json = _prefs!.getString('$_diskPrefix$key');
      if (json != null) {
        final data = jsonDecode(json);
        final entry = CacheEntry.fromJson(data);

        if (!entry.isExpired) {
          return entry;
        } else {
          await _prefs!.remove('$_diskPrefix$key');
        }
      }
    } catch (e) {
      Logger.error('Failed to get from disk cache: $e');
      await _prefs!.remove('$_diskPrefix$key');
    }

    return null;
  }

  /// Manage disk cache size
  static Future<void> _manageDiskCacheSize() async {
    if (_prefs == null) return;

    try {
      final keys =
          _prefs!.getKeys().where((key) => key.startsWith(_diskPrefix));
      final entries = <String, DateTime>{};

      for (final key in keys) {
        final json = _prefs!.getString(key);
        if (json != null) {
          try {
            final data = jsonDecode(json);
            entries[key] = DateTime.parse(data['createdAt']);
          } catch (e) {
            // Remove corrupted entries
            await _prefs!.remove(key);
          }
        }
      }

      // Sort by creation time and remove oldest if over size limit
      final sortedKeys = entries.keys.toList()
        ..sort((a, b) => entries[a]!.compareTo(entries[b]!));

      const maxEntries =
          (_maxDiskSizeMB * 1024 * 1024) ~/ (1024); // Rough estimate
      if (sortedKeys.length > maxEntries) {
        final keysToRemove = sortedKeys.take(sortedKeys.length - maxEntries);
        for (final key in keysToRemove) {
          await _prefs!.remove(key);
        }
        Logger.info('Cleaned up ${keysToRemove.length} old cache entries');
      }
    } catch (e) {
      Logger.error('Failed to manage disk cache size: $e');
    }
  }

  /// Clean up expired entries
  static Future<void> _cleanupExpiredEntries() async {
    if (_prefs == null) return;

    try {
      final keys =
          _prefs!.getKeys().where((key) => key.startsWith(_diskPrefix));
      final expiredKeys = <String>[];

      for (final key in keys) {
        final json = _prefs!.getString(key);
        if (json != null) {
          try {
            final data = jsonDecode(json);
            final entry = CacheEntry.fromJson(data);
            if (entry.isExpired) {
              expiredKeys.add(key);
            }
          } catch (e) {
            expiredKeys.add(key); // Remove corrupted entries
          }
        }
      }

      for (final key in expiredKeys) {
        await _prefs!.remove(key);
      }

      // Also clean memory cache
      _memoryCache.removeWhere((key, entry) => entry.isExpired);

      if (expiredKeys.isNotEmpty) {
        Logger.info('Cleaned up ${expiredKeys.length} expired cache entries');
      }
    } catch (e) {
      Logger.error('Failed to cleanup expired entries: $e');
    }
  }

  /// Clear all cache
  static Future<void> clear() async {
    try {
      _memoryCache.clear();

      if (_prefs != null) {
        final keys =
            _prefs!.getKeys().where((key) => key.startsWith(_diskPrefix));
        for (final key in keys) {
          await _prefs!.remove(key);
        }
      }

      Logger.info('HTTP cache cleared');
    } catch (e) {
      Logger.error('Failed to clear cache: $e');
    }
  }

  /// Get cache statistics
  static Future<Map<String, dynamic>> getStats() async {
    final memoryCount = _memoryCache.length;
    int diskCount = 0;
    int expiredCount = 0;

    if (_prefs != null) {
      final keys =
          _prefs!.getKeys().where((key) => key.startsWith(_diskPrefix));
      diskCount = keys.length;

      for (final key in keys) {
        final json = _prefs!.getString(key);
        if (json != null) {
          try {
            final data = jsonDecode(json);
            final entry = CacheEntry.fromJson(data);
            if (entry.isExpired) {
              expiredCount++;
            }
          } catch (e) {
            expiredCount++;
          }
        }
      }
    }

    return {
      'memoryEntries': memoryCount,
      'diskEntries': diskCount,
      'expiredEntries': expiredCount,
      'maxMemoryEntries': _maxMemoryEntries,
      'maxDiskSizeMB': _maxDiskSizeMB,
    };
  }
}
