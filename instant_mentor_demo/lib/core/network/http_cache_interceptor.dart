import 'package:dio/dio.dart';
import 'http_cache.dart';
import '../utils/logger.dart';

/// HTTP cache interceptor for automatic request/response caching
class HttpCacheInterceptor extends Interceptor {
  final bool enableCache;
  final Duration defaultCacheDuration;
  final List<String> cacheableMethods;

  HttpCacheInterceptor({
    this.enableCache = true,
    this.defaultCacheDuration = const Duration(minutes: 5),
    this.cacheableMethods = const ['GET', 'HEAD'],
  });

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!enableCache || !_shouldCheckCache(options)) {
      return handler.next(options);
    }

    try {
      final cachedEntry = await HttpCache.get(options);
      
      if (cachedEntry != null) {
        if (HttpCache.isValidForRequest(cachedEntry, options)) {
          // Return cached response
          Logger.debug('Returning cached response for ${options.path}');
          
          final response = Response<dynamic>(
            data: cachedEntry.data,
            statusCode: 200,
            statusMessage: 'OK (Cached)',
            headers: Headers.fromMap(_convertHeaders(cachedEntry.headers)),
            requestOptions: options,
          );
          
          return handler.resolve(response);
        } else if (cachedEntry.etag != null || cachedEntry.lastModified != null) {
          // Add conditional headers for validation
          if (cachedEntry.etag != null) {
            options.headers['If-None-Match'] = cachedEntry.etag;
          }
          if (cachedEntry.lastModified != null) {
            options.headers['If-Modified-Since'] = 
                cachedEntry.lastModified!.toUtc().toIso8601String();
          }
          
          Logger.debug('Adding conditional headers for ${options.path}');
        }
      }
    } catch (e) {
      Logger.error('Cache lookup failed for ${options.path}: $e');
    }

    handler.next(options);
  }

  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    if (!enableCache || !_shouldCacheResponse(response)) {
      return handler.next(response);
    }

    try {
      // Handle 304 Not Modified responses
      if (response.statusCode == 304) {
        Logger.debug('Received 304 for ${response.requestOptions.path}');
        
        final cachedEntry = await HttpCache.get(response.requestOptions);
        if (cachedEntry != null) {
          final cachedResponse = Response<dynamic>(
            data: cachedEntry.data,
            statusCode: 200,
            statusMessage: 'OK (Not Modified)',
            headers: Headers.fromMap(_convertHeaders(cachedEntry.headers)),
            requestOptions: response.requestOptions,
          );
          
          return handler.resolve(cachedResponse);
        }
      }

      // Cache successful responses
      if (response.statusCode != null && 
          response.statusCode! >= 200 && 
          response.statusCode! < 300) {
        await HttpCache.put(response);
        Logger.debug('Cached response for ${response.requestOptions.path}');
      }
    } catch (e) {
      Logger.error('Failed to cache response for ${response.requestOptions.path}: $e');
    }

    handler.next(response);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!enableCache) {
      return handler.next(err);
    }

    // Try to serve stale cache on network errors
    if (_isNetworkError(err)) {
      try {
        final cachedEntry = await HttpCache.get(err.requestOptions);
        
        if (cachedEntry != null) {
          Logger.warning('Serving stale cache due to network error: ${err.message}');
          
          final response = Response<dynamic>(
            data: cachedEntry.data,
            statusCode: 200,
            statusMessage: 'OK (Stale Cache)',
            headers: Headers.fromMap(_convertHeaders(cachedEntry.headers)),
            requestOptions: err.requestOptions,
          );
          
          return handler.resolve(response);
        }
      } catch (e) {
        Logger.error('Failed to serve stale cache: $e');
      }
    }

    handler.next(err);
  }

  /// Check if request should be cached
  bool _shouldCheckCache(RequestOptions options) {
    final method = options.method.toUpperCase();
    
    // Only cache specific methods
    if (!cacheableMethods.contains(method)) {
      return false;
    }
    
    // Don't cache if explicitly disabled
    final cacheControl = options.headers['cache-control']?.toString().toLowerCase();
    if (cacheControl?.contains('no-cache') == true) {
      return false;
    }
    
    return true;
  }

  /// Check if response should be cached
  bool _shouldCacheResponse(Response response) {
    final method = response.requestOptions.method.toUpperCase();
    
    // Only cache specific methods
    if (!cacheableMethods.contains(method)) {
      return false;
    }
    
    // Don't cache error responses (except 304)
    if (response.statusCode != null && 
        response.statusCode! >= 400 && 
        response.statusCode != 304) {
      return false;
    }
    
    return true;
  }

  /// Check if error is network-related
  bool _isNetworkError(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      default:
        return false;
    }
  }

  /// Convert headers from cache format to Dio format
  Map<String, List<String>> _convertHeaders(Map<String, dynamic> headers) {
    final converted = <String, List<String>>{};
    
    for (final entry in headers.entries) {
      if (entry.value is List) {
        converted[entry.key] = List<String>.from(entry.value);
      } else if (entry.value is String) {
        converted[entry.key] = [entry.value];
      } else {
        converted[entry.key] = [entry.value.toString()];
      }
    }
    
    return converted;
  }
}

/// Cache configuration for specific requests
class CacheOptions {
  final bool useCache;
  final Duration? maxAge;
  final bool allowStale;
  final List<int> cacheableStatusCodes;

  const CacheOptions({
    this.useCache = true,
    this.maxAge,
    this.allowStale = false,
    this.cacheableStatusCodes = const [200, 201, 202, 203, 300, 301, 410],
  });

  /// Convert to request extra data
  Map<String, dynamic> toExtra() => {
    'cache_use': useCache,
    'cache_max_age': maxAge?.inSeconds,
    'cache_allow_stale': allowStale,
    'cache_status_codes': cacheableStatusCodes,
  };
}

/// Extension to add cache options to request options
extension RequestCacheOptions on RequestOptions {
  /// Add cache configuration to request
  void setCacheOptions(CacheOptions options) {
    extra.addAll(options.toExtra());
  }
  
  /// Get cache configuration from request
  CacheOptions getCacheOptions() {
    return CacheOptions(
      useCache: extra['cache_use'] ?? true,
      maxAge: extra['cache_max_age'] != null 
          ? Duration(seconds: extra['cache_max_age'])
          : null,
      allowStale: extra['cache_allow_stale'] ?? false,
      cacheableStatusCodes: extra['cache_status_codes'] ?? [200, 201, 202, 203, 300, 301, 410],
    );
  }
}
