// Centralized test setup re-export.
// This file delegates to `test/helpers/setup_test_helper.dart` so tests can
// continue to import `test/setup.dart` while we keep a single canonical
// implementation of test harness configuration and ProviderScope overrides.

export 'helpers/setup_test_helper.dart'
    show configureTestHarness, widgetTestProviderScope;
