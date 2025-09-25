import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/models/user.dart'; // User, UserRole
import 'core/providers/auth_provider.dart'; // authProvider
import 'core/providers/user_provider.dart';
import 'core/routing/routing.dart';

class MainNavigation extends ConsumerWidget {
  final Widget child;

  const MainNavigation({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final authState = ref.watch(authProvider); // Supabase auth state
    final isStudent = ref.watch(isStudentProvider);

    // Fallback: if authenticated via Supabase but domain user not yet synced, create a minimal one
    if (user == null && authState.isAuthenticated && authState.user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final supaUser = authState.user!;
        // Try to get role from user metadata or email domain, default to mentor
        final userRole = (supaUser.userMetadata?['role'] == 'student')
            ? UserRole.student
            : UserRole.mentor;

        ref.read(userProvider.notifier).updateUser(
              User(
                id: supaUser.id,
                name: (supaUser.userMetadata?['full_name'] ??
                        supaUser.email?.split('@').first ??
                        'User')
                    .toString(),
                email: supaUser.email ?? '',
                role: userRole,
                createdAt: DateTime.now(),
                lastLoginAt: DateTime.now(),
              ),
            );
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_getScreenTitle(context, isStudent)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              _showNotifications(context);
            },
            tooltip: 'Notifications',
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => context.go(AppRoutes.more),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: _buildBottomNavigation(context, ref, isStudent),
    );
  }

  String _getScreenTitle(BuildContext context, bool isStudent) {
    final location = GoRouterState.of(context).uri.path;
    final role = isStudent ? 'Student' : 'Mentor';

    switch (location) {
      case '/student/home':
      case '/mentor/home':
        return '$role - Home';
      case '/student/booking':
        return 'Book Session';
      case '/student/chat':
      case '/mentor/chat':
        return 'Chat & Resources';
      case '/student/progress':
        return 'Progress';
      case '/student/wallet':
        return 'Wallet';
      case '/mentor/requests':
        return 'Session Requests';
      case '/mentor/earnings':
        return 'Earnings';
      case '/mentor/availability':
        return 'Availability';
      case '/more':
        return 'More Options';
      default:
        return 'Instant Mentor';
    }
  }

  Widget _buildBottomNavigation(
      BuildContext context, WidgetRef ref, bool isStudent) {
    final location = GoRouterState.of(context).uri.path;

    if (isStudent) {
      return BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _getStudentTabIndex(location),
        onTap: (index) => _onStudentTabTapped(context, index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_online),
            label: 'Book Session',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
        ],
      );
    } else {
      return BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _getMentorTabIndex(location),
        onTap: (index) => _onMentorTabTapped(context, index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_active),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum),
            label: 'Inbox',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monetization_on),
            label: 'Earnings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Availability',
          ),
        ],
      );
    }
  }

  int _getStudentTabIndex(String location) {
    switch (location) {
      case '/student/home':
        return 0;
      case '/student/booking':
        return 1;
      case '/student/chat':
        return 2;
      case '/student/progress':
        return 3;
      case '/student/wallet':
        return 4;
      default:
        return 0;
    }
  }

  int _getMentorTabIndex(String location) {
    switch (location) {
      case '/mentor/home':
        return 0;
      case '/mentor/requests':
        return 1;
      case '/mentor/chat':
        return 2;
      case '/mentor/earnings':
        return 3;
      case '/mentor/availability':
        return 4;
      default:
        return 0;
    }
  }

  void _onStudentTabTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.studentHome);
        break;
      case 1:
        context.go(AppRoutes.studentBooking);
        break;
      case 2:
        context.go(AppRoutes.studentChat);
        break;
      case 3:
        context.go(AppRoutes.studentProgress);
        break;
      case 4:
        context.go(AppRoutes.studentWallet);
        break;
    }
  }

  void _onMentorTabTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.mentorHome);
        break;
      case 1:
        context.go(AppRoutes.mentorRequests);
        break;
      case 2:
        context.go(AppRoutes.mentorChat);
        break;
      case 3:
        context.go(AppRoutes.mentorEarnings);
        break;
      case 4:
        context.go(AppRoutes.mentorAvailability);
        break;
    }
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.withOpacity(0.1),
                        shape: const CircleBorder(),
                      ),
                    ),
                  ],
                ),
              ),

              // Notifications list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _getNotificationItems().length,
                  itemBuilder: (context, index) {
                    final notification = _getNotificationItems()[index];
                    return _buildNotificationItem(
                      icon: notification['icon'],
                      title: notification['title'],
                      message: notification['message'],
                      time: notification['time'],
                      isNew: notification['isNew'],
                    );
                  },
                ),
              ),

              // Bottom spacing for safe area
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getNotificationItems() {
    return [
      {
        'icon': Icons.schedule,
        'title': 'Session Reminder',
        'message':
            'Your Mathematics session with Dr. Sarah Smith starts in 15 minutes',
        'time': '5 min ago',
        'isNew': true,
      },
      {
        'icon': Icons.message,
        'title': 'New Message',
        'message':
            'Prof. Raj Kumar sent you a message about tomorrow\'s Physics session',
        'time': '1 hour ago',
        'isNew': true,
      },
      {
        'icon': Icons.grade,
        'title': 'Session Completed',
        'message':
            'Your English session with Dr. Priya Sharma has been completed. Please rate your experience.',
        'time': '2 hours ago',
        'isNew': false,
      },
      {
        'icon': Icons.payment,
        'title': 'Payment Successful',
        'message':
            'Payment of ₹500 for Mathematics session has been processed successfully',
        'time': '1 day ago',
        'isNew': false,
      },
      {
        'icon': Icons.event_available,
        'title': 'Session Scheduled',
        'message':
            'Your Chemistry session with Dr. Anjali Gupta has been scheduled for tomorrow 2:00 PM',
        'time': '2 days ago',
        'isNew': false,
      },
    ];
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required String title,
    required String message,
    required String time,
    required bool isNew,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isNew ? Colors.blue.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNew
              ? Colors.blue.withOpacity(0.2)
              : Colors.grey.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isNew ? Colors.blue : Colors.grey[400],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: isNew ? FontWeight.bold : FontWeight.w600,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (isNew)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  time,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
