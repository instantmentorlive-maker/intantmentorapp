import 'dart:collection';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';

/// Offline request queue entry
class QueuedRequest {
  final String id;
  final RequestOptions options;
  final DateTime createdAt;
  final int priority;
  final Map<String, dynamic> metadata;

  QueuedRequest({
    required this.id,
    required this.options,
    required this.createdAt,
    this.priority = 0,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': options.method,
        'path': options.path,
        'baseUrl': options.baseUrl,
        'headers': options.headers,
        'queryParameters': options.queryParameters,
        'data': options.data,
        'createdAt': createdAt.toIso8601String(),
        'priority': priority,
        'metadata': metadata,
      };

  static QueuedRequest fromJson(Map<String, dynamic> json) {
    final options = RequestOptions(
      path: json['path'],
      method: json['method'],
      baseUrl: json['baseUrl'],
      headers: Map<String, dynamic>.from(json['headers'] ?? {}),
      queryParameters: Map<String, dynamic>.from(json['queryParameters'] ?? {}),
      data: json['data'],
    );

    return QueuedRequest(
      id: json['id'],
      options: options,
      createdAt: DateTime.parse(json['createdAt']),
      priority: json['priority'] ?? 0,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
}

/// Offline capability manager for HTTP requests
class OfflineManager {
  static const String _queueKey = 'offline_request_queue';
  static const int _maxQueueSize = 100;
  static const Duration _maxRetentionTime = Duration(days: 7);

  static SharedPreferences? _prefs;
  static final Connectivity _connectivity = Connectivity();
  static bool _isOnline = true;
  static bool _isInitialized = false;

  static final Queue<QueuedRequest> _requestQueue = Queue<QueuedRequest>();
  static final Set<String> _processingIds = <String>{};

  /// Initialize offline manager
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadQueueFromStorage();
      await _checkConnectivity();
      _setupConnectivityListener();
      _isInitialized = true;

      Logger.info(
          'Offline manager initialized with ${_requestQueue.length} queued requests');
    } catch (e) {
      Logger.error('Failed to initialize offline manager: $e');
    }
  }

  /// Check current connectivity status
  static Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isOnline = result != ConnectivityResult.none;
      Logger.debug('Connectivity status: ${_isOnline ? "online" : "offline"}');

      if (_isOnline) {
        await _processQueue();
      }
    } catch (e) {
      Logger.error('Failed to check connectivity: $e');
    }
  }

  /// Setup connectivity change listener
  static void _setupConnectivityListener() {
    _connectivity.onConnectivityChanged.listen((result) async {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;

      Logger.info('Connectivity changed: ${_isOnline ? "online" : "offline"}');

      if (!wasOnline && _isOnline) {
        Logger.info('Back online - processing queued requests');
        await _processQueue();
      }
    });
  }

  /// Add request to offline queue
  static Future<void> queueRequest(
    RequestOptions options, {
    int priority = 0,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isInitialized) await initialize();

    // Generate unique ID
    final id = '${DateTime.now().millisecondsSinceEpoch}_${options.hashCode}';

    final queuedRequest = QueuedRequest(
      id: id,
      options: options,
      createdAt: DateTime.now(),
      priority: priority,
      metadata: metadata ?? {},
    );

    // Add to in-memory queue
    _requestQueue.add(queuedRequest);

    // Maintain queue size limit
    while (_requestQueue.length > _maxQueueSize) {
      final removed = _requestQueue.removeFirst();
      Logger.warning(
          'Queue size exceeded - removing oldest request: ${removed.id}');
    }

    // Save to persistent storage
    await _saveQueueToStorage();

    Logger.info(
        'Request queued for offline processing: ${options.method} ${options.path}');
  }

  /// Process all queued requests
  static Future<void> _processQueue() async {
    if (!_isOnline || _requestQueue.isEmpty) return;

    final requests = List<QueuedRequest>.from(_requestQueue);

    // Sort by priority (higher priority first) and then by creation time
    requests.sort((a, b) {
      final priorityComparison = b.priority.compareTo(a.priority);
      if (priorityComparison != 0) return priorityComparison;
      return a.createdAt.compareTo(b.createdAt);
    });

    Logger.info('Processing ${requests.length} queued requests');

    for (final request in requests) {
      if (_processingIds.contains(request.id)) continue;

      try {
        _processingIds.add(request.id);
        await _processRequest(request);

        // Remove from queue on success
        _requestQueue.removeWhere((r) => r.id == request.id);
        Logger.debug('Successfully processed queued request: ${request.id}');
      } catch (e) {
        Logger.error('Failed to process queued request ${request.id}: $e');

        // Remove old requests that have exceeded retention time
        if (DateTime.now().difference(request.createdAt) > _maxRetentionTime) {
          _requestQueue.removeWhere((r) => r.id == request.id);
          Logger.warning('Removed expired queued request: ${request.id}');
        }
      } finally {
        _processingIds.remove(request.id);
      }
    }

    // Save updated queue
    await _saveQueueToStorage();
    Logger.info(
        'Finished processing queue. ${_requestQueue.length} requests remaining');
  }

  /// Process a single queued request
  static Future<void> _processRequest(QueuedRequest request) async {
    final dio = Dio();

    // Configure dio with basic settings
    dio.options.connectTimeout = const Duration(seconds: 10);
    dio.options.receiveTimeout = const Duration(seconds: 30);
    dio.options.sendTimeout = const Duration(seconds: 30);

    try {
      final response = await dio.fetch(request.options);
      Logger.debug(
          'Queued request successful: ${request.options.method} ${request.options.path} - Status: ${response.statusCode}');
    } catch (e) {
      if (e is DioException) {
        // Don't retry client errors (4xx)
        if (e.response?.statusCode != null &&
            e.response!.statusCode! >= 400 &&
            e.response!.statusCode! < 500) {
          Logger.warning(
              'Removing failed client request from queue: ${request.id}');
          return; // Don't rethrow, so it gets removed from queue
        }
      }
      rethrow; // Server errors and network issues should be retried
    }
  }

  /// Load request queue from persistent storage
  static Future<void> _loadQueueFromStorage() async {
    if (_prefs == null) return;

    try {
      final queueJson = _prefs!.getString(_queueKey);
      if (queueJson != null) {
        final List<dynamic> queueData = jsonDecode(queueJson);

        for (final item in queueData) {
          try {
            final request = QueuedRequest.fromJson(item);

            // Skip expired requests
            if (DateTime.now().difference(request.createdAt) <=
                _maxRetentionTime) {
              _requestQueue.add(request);
            }
          } catch (e) {
            Logger.warning('Failed to deserialize queued request: $e');
          }
        }
      }
    } catch (e) {
      Logger.error('Failed to load request queue from storage: $e');
      // Clear corrupted data
      await _prefs!.remove(_queueKey);
    }
  }

  /// Save request queue to persistent storage
  static Future<void> _saveQueueToStorage() async {
    if (_prefs == null) return;

    try {
      final queueData = _requestQueue.map((r) => r.toJson()).toList();
      final queueJson = jsonEncode(queueData);
      await _prefs!.setString(_queueKey, queueJson);
    } catch (e) {
      Logger.error('Failed to save request queue to storage: $e');
    }
  }

  /// Check if device is currently online
  static bool get isOnline => _isOnline;

  /// Get current queue size
  static int get queueSize => _requestQueue.length;

  /// Get queue statistics
  static Map<String, dynamic> getStats() {
    final now = DateTime.now();
    final requestsByAge = <String, int>{};
    final requestsByPriority = <int, int>{};

    for (final request in _requestQueue) {
      final age = now.difference(request.createdAt);

      String ageCategory;
      if (age.inMinutes < 5) {
        ageCategory = '<5min';
      } else if (age.inHours < 1) {
        ageCategory = '<1h';
      } else if (age.inDays < 1) {
        ageCategory = '<1d';
      } else {
        ageCategory = '≥1d';
      }

      requestsByAge[ageCategory] = (requestsByAge[ageCategory] ?? 0) + 1;
      requestsByPriority[request.priority] =
          (requestsByPriority[request.priority] ?? 0) + 1;
    }

    return {
      'isOnline': _isOnline,
      'queueSize': _requestQueue.length,
      'maxQueueSize': _maxQueueSize,
      'processingCount': _processingIds.length,
      'requestsByAge': requestsByAge,
      'requestsByPriority': requestsByPriority,
    };
  }

  /// Clear all queued requests
  static Future<void> clearQueue() async {
    _requestQueue.clear();
    _processingIds.clear();

    if (_prefs != null) {
      await _prefs!.remove(_queueKey);
    }

    Logger.info('Request queue cleared');
  }

  /// Force process queue (even if offline)
  static Future<void> forceProcessQueue() async {
    if (!_isInitialized) await initialize();

    final wasOnline = _isOnline;
    _isOnline = true; // Temporarily mark as online

    try {
      await _processQueue();
    } finally {
      _isOnline = wasOnline; // Restore original state
    }
  }
}

/// Offline interceptor for automatic request queuing
class OfflineInterceptor extends Interceptor {
  final bool enableQueueing;
  final int defaultPriority;
  final List<String> queueableMethods;

  OfflineInterceptor({
    this.enableQueueing = true,
    this.defaultPriority = 0,
    this.queueableMethods = const ['POST', 'PUT', 'PATCH', 'DELETE'],
  });

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!enableQueueing || !_shouldQueue(err)) {
      return handler.next(err);
    }

    // Check if error is due to network connectivity
    if (_isNetworkError(err) && !OfflineManager.isOnline) {
      try {
        final priority = err.requestOptions.extra['offline_priority'] as int? ??
            defaultPriority;
        final metadata = err.requestOptions.extra['offline_metadata']
                as Map<String, dynamic>? ??
            {};

        await OfflineManager.queueRequest(
          err.requestOptions,
          priority: priority,
          metadata: metadata,
        );

        Logger.info(
            'Request queued for offline processing: ${err.requestOptions.method} ${err.requestOptions.path}');

        // Return a custom success response indicating the request was queued
        final response = Response<Map<String, dynamic>>(
          data: {
            'queued': true,
            'message': 'Request queued for offline processing',
          },
          statusCode: 202, // Accepted
          statusMessage: 'Queued for offline processing',
          requestOptions: err.requestOptions,
        );

        return handler.resolve(response);
      } catch (e) {
        Logger.error('Failed to queue request for offline processing: $e');
      }
    }

    handler.next(err);
  }

  /// Check if request should be queued
  bool _shouldQueue(DioException error) {
    final method = error.requestOptions.method.toUpperCase();

    // Only queue specific HTTP methods
    if (!queueableMethods.contains(method)) {
      return false;
    }

    // Don't queue if explicitly disabled
    if (error.requestOptions.extra['offline_disable'] == true) {
      return false;
    }

    return true;
  }

  /// Check if error is network-related
  bool _isNetworkError(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
        return true;
      default:
        return false;
    }
  }
}

/// Extension for offline configuration on requests
extension RequestOfflineOptions on RequestOptions {
  /// Set offline processing priority
  void setOfflinePriority(int priority) {
    extra['offline_priority'] = priority;
  }

  /// Set offline metadata
  void setOfflineMetadata(Map<String, dynamic> metadata) {
    extra['offline_metadata'] = metadata;
  }

  /// Disable offline queuing for this request
  void disableOfflineQueuing() {
    extra['offline_disable'] = true;
  }

  /// Get offline priority
  int get offlinePriority => (extra['offline_priority'] as int?) ?? 0;

  /// Check if offline queuing is disabled
  bool get isOfflineQueuingDisabled => extra['offline_disable'] == true;
}
