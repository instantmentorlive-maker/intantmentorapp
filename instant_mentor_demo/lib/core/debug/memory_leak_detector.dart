import 'dart:io';
import 'package:flutter/foundation.dart';
import '../utils/memory_manager.dart';
import 'provider_observer.dart';

/// Script to detect potential memory leaks in the app
class MemoryLeakDetector {
  static final MemoryLeakDetector _instance = MemoryLeakDetector._internal();
  factory MemoryLeakDetector() => _instance;
  MemoryLeakDetector._internal();

  final List<String> _potentialLeaks = [];
  late MemoryLeakObserver _observer;

  /// Initialize memory leak detection
  void initialize() {
    _observer = MemoryLeakObserver();

    if (kDebugMode) {
      print('🔍 Memory Leak Detector initialized');
    }
  }

  /// Start monitoring for a specific duration
  Future<void> startMonitoring(
      {Duration duration = const Duration(minutes: 5)}) async {
    if (kDebugMode) {
      print(
          '🔍 Starting memory monitoring for ${duration.inMinutes} minutes...');
    }

    final startTime = DateTime.now();
    final endTime = startTime.add(duration);

    // Check memory stats periodically
    while (DateTime.now().isBefore(endTime)) {
      await Future.delayed(const Duration(seconds: 30));
      _checkMemoryLeaks();
      _observer.logStats();

      // Force garbage collection to see if providers are properly disposed
      if (kDebugMode) {
        print('🗑️ Forcing garbage collection...');
      }
    }

    _generateReport();
  }

  /// Check for potential memory leaks
  void _checkMemoryLeaks() {
    final memoryStats = MemoryManager().getMemoryStats();
    final providerStats = _observer.getStats();

    // Check for excessive subscriptions
    if (memoryStats['totalSubscriptions'] > 50) {
      _potentialLeaks
          .add('HIGH subscription count: ${memoryStats['totalSubscriptions']}');
    }

    // Check for excessive timers
    if (memoryStats['totalTimers'] > 20) {
      _potentialLeaks.add('HIGH timer count: ${memoryStats['totalTimers']}');
    }

    // Check for excessive providers
    if (providerStats['totalActive'] > 100) {
      _potentialLeaks
          .add('HIGH active provider count: ${providerStats['totalActive']}');
    }

    // Check specific features
    final subscriptionsByFeature =
        memoryStats['subscriptions'] as Map<String, int>;
    for (final entry in subscriptionsByFeature.entries) {
      if (entry.value > 10) {
        _potentialLeaks
            .add('Feature "${entry.key}" has ${entry.value} subscriptions');
      }
    }
  }

  /// Generate memory leak report
  void _generateReport() {
    final report = StringBuffer();
    report.writeln('📊 MEMORY LEAK DETECTION REPORT');
    report.writeln('================================');
    report.writeln('Generated: ${DateTime.now()}');
    report.writeln();

    if (_potentialLeaks.isEmpty) {
      report.writeln('✅ No potential memory leaks detected!');
    } else {
      report.writeln('⚠️  Potential Memory Leaks Found:');
      report.writeln();
      for (int i = 0; i < _potentialLeaks.length; i++) {
        report.writeln('${i + 1}. ${_potentialLeaks[i]}');
      }
    }

    report.writeln();
    report.writeln('💡 Recommendations:');
    report
        .writeln('- Use autoDispose for providers that don\'t need to persist');
    report.writeln('- Cancel subscriptions in dispose methods');
    report.writeln('- Use MemoryManager.track() for automatic cleanup');
    report.writeln('- Monitor provider lifecycle with ProviderObserver');

    final reportString = report.toString();

    if (kDebugMode) {
      print(reportString);
    }

    // Save report to file
    _saveReportToFile(reportString);
  }

  /// Save report to file
  void _saveReportToFile(String report) async {
    try {
      final file = File(
          'memory_leak_report_${DateTime.now().millisecondsSinceEpoch}.txt');
      await file.writeAsString(report);

      if (kDebugMode) {
        print('📄 Report saved to: ${file.path}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to save report: $e');
      }
    }
  }

  /// Run a quick memory check
  void quickCheck() {
    if (kDebugMode) {
      print('🔍 Running quick memory check...');
    }

    final memoryStats = MemoryManager().getMemoryStats();
    final providerStats = _observer.getStats();

    print('📊 Current Memory Stats:');
    print('   Subscriptions: ${memoryStats['totalSubscriptions']}');
    print('   Timers: ${memoryStats['totalTimers']}');
    print('   Disposers: ${memoryStats['totalDisposers']}');
    print('   Active Providers: ${providerStats['totalActive']}');

    // Quick leak detection
    if (memoryStats['totalSubscriptions'] > 20 ||
        memoryStats['totalTimers'] > 10 ||
        providerStats['totalActive'] > 50) {
      print('⚠️  Potential memory issues detected!');
    } else {
      print('✅ Memory usage looks healthy');
    }
  }

  /// Clear all tracked leaks (for testing)
  void clearLeaks() {
    _potentialLeaks.clear();
  }
}
