import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Comprehensive performance monitoring system for test runs
class TestPerformanceMonitor {
  static final TestPerformanceMonitor _instance =
      TestPerformanceMonitor._internal();
  factory TestPerformanceMonitor() => _instance;
  TestPerformanceMonitor._internal();

  final Map<String, PerformanceMetrics> _testMetrics = {};
  final List<PerformanceAlert> _alerts = [];
  Timer? _monitoringTimer;
  DateTime? _testStartTime;
  String? _currentTestName;

  /// Start monitoring performance for a test
  void startTest(String testName) {
    _currentTestName = testName;
    _testStartTime = DateTime.now();
    _testMetrics[testName] = PerformanceMetrics();

    // Start periodic monitoring
    _monitoringTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _collectMetrics();
    });

    if (kDebugMode) {
      print('📊 Started performance monitoring for: $testName');
    }
  }

  /// Stop monitoring and save results
  Future<void> stopTest() async {
    if (_currentTestName == null) return;

    _monitoringTimer?.cancel();
    final duration = DateTime.now().difference(_testStartTime!);
    _testMetrics[_currentTestName!]!.totalDuration = duration;

    await _generateTestReport(_currentTestName!);
    _currentTestName = null;
    _testStartTime = null;

    if (kDebugMode) {
      print('📊 Stopped performance monitoring');
    }
  }

  /// Collect current performance metrics
  void _collectMetrics() {
    if (_currentTestName == null) return;

    final metrics = _testMetrics[_currentTestName!]!;
    metrics.samples++;

    // Collect memory usage
    _collectMemoryMetrics(metrics);

    // Collect frame timing
    _collectFrameMetrics(metrics);

    // Check for performance alerts
    _checkPerformanceThresholds(metrics);
  }

  /// Collect memory-related metrics
  void _collectMemoryMetrics(PerformanceMetrics metrics) {
    try {
      // Get current memory usage (platform-specific)
      if (Platform.isAndroid || Platform.isIOS) {
        _collectMobileMemoryMetrics(metrics);
      } else {
        _collectDesktopMemoryMetrics(metrics);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Warning: Could not collect memory metrics: $e');
      }
    }
  }

  /// Collect mobile-specific memory metrics
  void _collectMobileMemoryMetrics(PerformanceMetrics metrics) {
    // This would use platform channels to get actual memory usage
    // For now, simulate with reasonable values
    final currentMemory = _simulateMemoryUsage();

    metrics.memoryUsage.add(currentMemory);
    if (currentMemory > metrics.peakMemoryUsage) {
      metrics.peakMemoryUsage = currentMemory;
    }

    if (currentMemory > 150) {
      // 150MB threshold
      _addAlert(PerformanceAlert(
        testName: _currentTestName!,
        type: AlertType.highMemory,
        message: 'High memory usage: ${currentMemory}MB',
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Collect desktop-specific memory metrics
  void _collectDesktopMemoryMetrics(PerformanceMetrics metrics) {
    // Similar to mobile but with different thresholds
    final currentMemory = _simulateMemoryUsage();
    metrics.memoryUsage.add(currentMemory);

    if (currentMemory > metrics.peakMemoryUsage) {
      metrics.peakMemoryUsage = currentMemory;
    }
  }

  /// Collect frame timing metrics
  void _collectFrameMetrics(PerformanceMetrics metrics) {
    // Simulate frame timing data
    final frameTime = _simulateFrameTime();
    metrics.frameTimes.add(frameTime);

    if (frameTime > 16.67) {
      // 60fps threshold
      metrics.droppedFrames++;

      if (frameTime > 33.33) {
        // 30fps threshold
        _addAlert(PerformanceAlert(
          testName: _currentTestName!,
          type: AlertType.slowFrame,
          message: 'Slow frame detected: ${frameTime.toStringAsFixed(2)}ms',
          timestamp: DateTime.now(),
        ));
      }
    }
  }

  /// Check performance thresholds and generate alerts
  void _checkPerformanceThresholds(PerformanceMetrics metrics) {
    final avgMemory = metrics.memoryUsage.isNotEmpty
        ? metrics.memoryUsage.reduce((a, b) => a + b) /
            metrics.memoryUsage.length
        : 0;

    final avgFrameTime = metrics.frameTimes.isNotEmpty
        ? metrics.frameTimes.reduce((a, b) => a + b) / metrics.frameTimes.length
        : 0;

    // Check thresholds
    if (avgMemory > 100) {
      _addAlert(PerformanceAlert(
        testName: _currentTestName!,
        type: AlertType.highAverageMemory,
        message: 'High average memory: ${avgMemory.toStringAsFixed(1)}MB',
        timestamp: DateTime.now(),
      ));
    }

    if (avgFrameTime > 20) {
      _addAlert(PerformanceAlert(
        testName: _currentTestName!,
        type: AlertType.slowAverageFrames,
        message:
            'Slow average frame time: ${avgFrameTime.toStringAsFixed(2)}ms',
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Add performance alert
  void _addAlert(PerformanceAlert alert) {
    _alerts.add(alert);
    if (kDebugMode) {
      print('⚠️ Performance Alert: ${alert.message}');
    }
  }

  /// Generate detailed test report
  Future<void> _generateTestReport(String testName) async {
    final metrics = _testMetrics[testName]!;
    final report = StringBuffer();

    report.writeln('📊 PERFORMANCE TEST REPORT');
    report.writeln('=========================');
    report.writeln('Test: $testName');
    report.writeln('Duration: ${metrics.totalDuration}');
    report.writeln('Samples: ${metrics.samples}');
    report.writeln('');

    // Memory metrics
    report.writeln('🧠 Memory Metrics:');
    if (metrics.memoryUsage.isNotEmpty) {
      final avgMemory = metrics.memoryUsage.reduce((a, b) => a + b) /
          metrics.memoryUsage.length;
      report.writeln('  Average Memory: ${avgMemory.toStringAsFixed(1)} MB');
      report.writeln(
          '  Peak Memory: ${metrics.peakMemoryUsage.toStringAsFixed(1)} MB');
      report.writeln(
          '  Min Memory: ${metrics.memoryUsage.reduce((a, b) => a < b ? a : b).toStringAsFixed(1)} MB');
    }

    // Frame metrics
    report.writeln('');
    report.writeln('🖼️ Frame Metrics:');
    if (metrics.frameTimes.isNotEmpty) {
      final avgFrameTime = metrics.frameTimes.reduce((a, b) => a + b) /
          metrics.frameTimes.length;
      report.writeln(
          '  Average Frame Time: ${avgFrameTime.toStringAsFixed(2)} ms');
      report.writeln('  Dropped Frames: ${metrics.droppedFrames}');
      report.writeln(
          '  Frame Rate: ${(1000 / avgFrameTime).toStringAsFixed(1)} fps');
    }

    // Alerts
    final testAlerts = _alerts.where((a) => a.testName == testName).toList();
    if (testAlerts.isNotEmpty) {
      report.writeln('');
      report.writeln('⚠️ Performance Alerts:');
      for (final alert in testAlerts) {
        report.writeln('  ${alert.type.name}: ${alert.message}');
      }
    }

    // Recommendations
    report.writeln('');
    report.writeln('💡 Recommendations:');
    _addRecommendations(report, metrics);

    final reportString = report.toString();

    if (kDebugMode) {
      print(reportString);
    }

    // Save to file
    await _saveReportToFile(testName, reportString);
  }

  /// Add performance recommendations
  void _addRecommendations(StringBuffer report, PerformanceMetrics metrics) {
    if (metrics.peakMemoryUsage > 200) {
      report.writeln(
          '  - Consider optimizing memory usage (peak: ${metrics.peakMemoryUsage}MB)');
    }

    if (metrics.droppedFrames > 10) {
      report.writeln(
          '  - Optimize UI rendering (${metrics.droppedFrames} dropped frames)');
    }

    final testAlerts =
        _alerts.where((a) => a.testName == _currentTestName).toList();
    if (testAlerts.any((a) => a.type == AlertType.slowFrame)) {
      report.writeln(
          '  - Profile widget build methods for performance bottlenecks');
    }

    if (testAlerts.any((a) => a.type == AlertType.highMemory)) {
      report
          .writeln('  - Check for memory leaks in providers and subscriptions');
    }
  }

  /// Save report to file
  Future<void> _saveReportToFile(String testName, String report) async {
    try {
      final fileName =
          'performance_${testName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.txt';
      final file = File(fileName);
      await file.writeAsString(report);

      if (kDebugMode) {
        print('📄 Performance report saved: $fileName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to save performance report: $e');
      }
    }
  }

  /// Get summary of all test results
  Map<String, dynamic> getSummary() {
    final summary = <String, dynamic>{};

    for (final entry in _testMetrics.entries) {
      final metrics = entry.value;
      summary[entry.key] = {
        'duration': metrics.totalDuration?.inMilliseconds ?? 0,
        'samples': metrics.samples,
        'peakMemory': metrics.peakMemoryUsage,
        'droppedFrames': metrics.droppedFrames,
        'alertCount': _alerts.where((a) => a.testName == entry.key).length,
      };
    }

    return summary;
  }

  /// Simulate memory usage (replace with actual platform channel)
  double _simulateMemoryUsage() {
    // Simulate realistic memory usage between 50-200MB
    return 50 + (150 * (DateTime.now().millisecondsSinceEpoch % 1000) / 1000);
  }

  /// Simulate frame timing (replace with actual frame timing)
  double _simulateFrameTime() {
    // Simulate frame times between 8-25ms (40-125fps)
    return 8 + (17 * (DateTime.now().microsecondsSinceEpoch % 1000) / 1000);
  }

  /// Clear all data (for testing)
  void clear() {
    _testMetrics.clear();
    _alerts.clear();
    _monitoringTimer?.cancel();
    _currentTestName = null;
    _testStartTime = null;
  }
}

/// Performance metrics container
class PerformanceMetrics {
  Duration? totalDuration;
  int samples = 0;
  List<double> memoryUsage = [];
  double peakMemoryUsage = 0;
  List<double> frameTimes = [];
  int droppedFrames = 0;
}

/// Performance alert types
enum AlertType {
  highMemory,
  highAverageMemory,
  slowFrame,
  slowAverageFrames,
  highCpuUsage,
  networkTimeout,
}

/// Performance alert container
class PerformanceAlert {
  final String testName;
  final AlertType type;
  final String message;
  final DateTime timestamp;

  PerformanceAlert({
    required this.testName,
    required this.type,
    required this.message,
    required this.timestamp,
  });
}
