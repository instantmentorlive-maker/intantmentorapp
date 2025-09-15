import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Test helper class for setting up integration test environment
class IntegrationTestHelper {
  /// Wait for all providers to settle
  static Future<void> waitForProviders(WidgetTester tester,
      {Duration? timeout}) async {
    await tester.pumpAndSettle(timeout ?? const Duration(seconds: 5));
  }

  /// Simulate network delay
  static Future<void> simulateNetworkDelay([Duration? delay]) async {
    await Future.delayed(delay ?? const Duration(milliseconds: 500));
  }

  /// Find widget by text content
  static Finder findByTextContaining(String text) {
    return find.byWidgetPredicate((widget) {
      if (widget is Text) {
        return widget.data?.contains(text) == true;
      }
      return false;
    });
  }

  /// Verify widget exists with timeout
  static Future<void> verifyWidgetExists(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      await tester.pump();
      if (finder.evaluate().isNotEmpty) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    throw TestFailure('Widget not found within timeout: $finder');
  }
}
