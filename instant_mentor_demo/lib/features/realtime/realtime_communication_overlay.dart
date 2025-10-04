import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/routing/routing.dart';
import '../common/widgets/call_notification_widget.dart';
import '../common/widgets/mentor_status_widget.dart';
import '../common/widgets/student_help_request_widget.dart';

/// Overlay widget that manages all real-time communication features
class RealtimeCommunicationOverlay extends ConsumerWidget {
  final Widget child;

  const RealtimeCommunicationOverlay({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final userRole = user?.userMetadata?['role'];
    final goRouter = ref.watch(goRouterProvider);
    final currentRoute = goRouter.routerDelegate.currentConfiguration.uri.path;

    // Debug logging to verify route detection
    print(
        '🔍 RealtimeCommunicationOverlay: currentRoute = $currentRoute, userRole = $userRole');

    // Note: Do NOT call GoRouterState.of(context) here because this widget
    // is inserted via MaterialApp.router's `builder` and the provided
    // `context` is above the router. Access the router state from a
    // descendant context (see usage below with a Builder).

    return Stack(
      children: [
        // Main app content
        child,

        // Call notifications (appears on top for all users)
        const Positioned(
          top: 100,
          left: 0,
          right: 0,
          child: CallNotificationWidget(),
        ),

        // Mentor-specific widgets - DISABLED FOR TESTING
        // if (userRole == 'mentor' && currentRoute == '/mentor/home') ...[
        //   const Positioned(
        //     bottom: 20,
        //     right: 16,
        //     child: _MinimizableMentorStatus(),
        //   ),
        // ],

        // Student-specific widgets - DISABLED FOR TESTING
        // if (userRole == 'student' && currentRoute == '/student/home') ...[
        //   Positioned(
        //     bottom: 20,
        //     right: 16,
        //     child: _FloatingHelpButton(),
        //   ),
        // ],
      ],
    );
  }
}

/// Minimizable mentor status widget
class _MinimizableMentorStatus extends ConsumerStatefulWidget {
  const _MinimizableMentorStatus();

  @override
  ConsumerState<_MinimizableMentorStatus> createState() =>
      _MinimizableMentorStatusState();
}

class _MinimizableMentorStatusState
    extends ConsumerState<_MinimizableMentorStatus>
    with TickerProviderStateMixin {
  bool _isExpanded = false;
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 260),
    vsync: this,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: animation,
        child: child,
      ),
      child: _isExpanded
          ? _buildExpanded(context)
          : Semantics(
              button: true,
              label: 'Show mentor status panel',
              child: _CircleIconButton(
                key: const ValueKey('mentor_status_fab'),
                onPressed: _toggle,
                backgroundColor: Theme.of(context).colorScheme.primary,
                icon: Icons.person,
                semanticLabel: 'Open mentor status panel',
              ),
            ),
    );
  }

  Widget _buildExpanded(BuildContext context) {
    if (!_controller.isAnimating && !_controller.isCompleted) {
      _controller.forward(from: 0);
    }

    final theme = Theme.of(context);
    final hasOverlay = Overlay.maybeOf(context) != null;

    return Material(
      key: const ValueKey('mentor_status_panel'),
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        height: 420,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.25),
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: MentorStatusWidget(),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Semantics(
                button: true,
                label: 'Close mentor status panel',
                child: IconButton(
                  tooltip: hasOverlay ? 'Close mentor status' : null,
                  splashRadius: 20,
                  onPressed: _toggle,
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: Tooltip(
                message:
                    hasOverlay ? 'Minimize' : 'Minimize mentor status panel',
                child: _CircleIconButton(
                  key: const ValueKey('mentor_status_minimize'),
                  onPressed: _toggle,
                  backgroundColor: theme.colorScheme.primary,
                  icon: Icons.arrow_downward,
                  semanticLabel: 'Minimize mentor status panel',
                  size: 48,
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggle() {
    setState(() {
      if (_isExpanded) {
        _controller.reverse(from: 1);
      } else {
        _controller.forward(from: 0);
      }
      _isExpanded = !_isExpanded;
    });
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.onPressed,
    required this.backgroundColor,
    required this.icon,
    required this.semanticLabel,
    this.size = 56,
    this.elevation = 6,
    super.key,
  });

  final VoidCallback onPressed;
  final Color backgroundColor;
  final IconData icon;
  final double size;
  final double elevation;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: backgroundColor,
        elevation: elevation,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Floating help request button for students
class _FloatingHelpButton extends ConsumerStatefulWidget {
  @override
  ConsumerState<_FloatingHelpButton> createState() =>
      _FloatingHelpButtonState();
}

class _FloatingHelpButtonState extends ConsumerState<_FloatingHelpButton>
    with TickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.75).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Expanded help widget
        if (_isExpanded)
          Container(
            width: 300, // Made slightly smaller
            constraints:
                const BoxConstraints(maxHeight: 400), // Added height constraint
            margin: const EdgeInsets.only(bottom: 16),
            child: const StudentHelpRequestWidget(),
          ),

        // Floating action button
        RotationTransition(
          turns: _rotationAnimation,
          child: FloatingActionButton(
            onPressed: _toggleExpanded,
            backgroundColor: Theme.of(context).primaryColor,
            child: Icon(
              _isExpanded ? Icons.close : Icons.help_outline,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });

    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }
}

/// Notification overlay for help requests and call updates
class RealtimeNotificationOverlay extends ConsumerWidget {
  const RealtimeNotificationOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This widget listens to WebSocket messages and shows appropriate notifications
    return Container(); // Implementation would show toast notifications
  }
}
