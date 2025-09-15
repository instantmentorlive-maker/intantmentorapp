import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../common/widgets/call_notification_widget.dart';
import '../common/widgets/mentor_status_widget.dart';
import '../common/widgets/student_help_request_widget.dart';
import '../../core/providers/auth_provider.dart';

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

        // Mentor-specific widgets
        if (userRole == 'mentor') ...[
          // Mentor status widget (bottom-right, can be minimized)
          const Positioned(
            bottom: 20,
            right: 16,
            child: _MinimizableMentorStatus(),
          ),
        ],

        // Student-specific widgets
        if (userRole == 'student') ...[
          // Floating help request button
          Positioned(
            bottom: 20,
            right: 16,
            child: _FloatingHelpButton(),
          ),
        ],
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
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _isExpanded ? 320 : 60,
      height: _isExpanded ? 400 : 60,
      child: _isExpanded
          ? ScaleTransition(
              scale: _scaleAnimation,
              child: Stack(
                children: [
                  const MentorStatusWidget(),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      onPressed: _toggleExpanded,
                      icon: const Icon(Icons.close),
                      iconSize: 20,
                    ),
                  ),
                ],
              ),
            )
          : FloatingActionButton(
              onPressed: _toggleExpanded,
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.person, color: Colors.white),
            ),
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
