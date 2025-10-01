import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routing.dart';

void directNavigateUser(BuildContext context, bool isStudent) {
  final route = isStudent ? AppRoutes.studentHome : AppRoutes.mentorHome;
  // Try the simple case first. If this context is above the router (for
  // example when called from MaterialApp.builder) GoRouter.of will throw.
  try {
    GoRouter.of(context).go(route);
    return;
  } catch (_) {}

  // Fallback: try to read the router from Riverpod's provider container if
  // available in this context.
  try {
    final container = ProviderScope.containerOf(context, listen: false);
    final router = container.read(goRouterProvider);
    router.go(route);
    return;
  } catch (_) {}

  // Last resort: schedule a post-frame callback to retry navigation. This
  // gives the widget tree a chance to mount under the router.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    try {
      GoRouter.of(context).go(route);
    } catch (_) {
      // Can't navigate - nothing more we can do safely here.
    }
  });
}
