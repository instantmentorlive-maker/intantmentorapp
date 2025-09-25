import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../mentor/incentives/incentives_bonuses_screen.dart';
import '../../mentor/performance_analytics/performance_analytics_screen.dart';
import '../../mentor/profile_management/profile_management_screen.dart';
import '../../mentor/student_history/student_history_screen.dart';
import '../../student/find_mentors/find_mentors_screen.dart';
import '../../student/free_trial/free_trial_screen.dart';
import '../../student/notes/session_notes_screen.dart';
import '../../student/quick_doubt/quick_doubt_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';

class MoreMenuScreen extends ConsumerWidget {
  const MoreMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isStudent = ref.watch(isStudentProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${isStudent ? 'Student' : 'Mentor'} Menu',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Role switcher removed: role is selected at signup and cannot be changed later

          if (isStudent)
            ..._buildStudentMenuItems(context)
          else
            ..._buildMentorMenuItems(context),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Common items
          _MenuTile(
            icon: Icons.person,
            title: 'Profile',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            ),
          ),
          _MenuTile(
            icon: Icons.settings,
            title: 'Settings',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),
          _MenuTile(
            icon: Icons.help,
            title: 'Help & Support',
            onTap: () => _showComingSoon(context, 'Help & Support'),
          ),
          _MenuTile(
            icon: Icons.network_check,
            title: 'WebSocket Demo',
            subtitle: 'Real-time features demo',
            onTap: () => context.go('/websocket-demo'),
          ),
          _MenuTile(
            icon: Icons.logout,
            title: 'Logout',
            onTap: () => _showLogoutDialog(context, ref),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStudentMenuItems(BuildContext context) {
    return [
      _MenuTile(
        icon: Icons.search,
        title: 'Find Mentors',
        subtitle: 'Browse and search mentors',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FindMentorsScreen()),
        ),
      ),
      _MenuTile(
        icon: Icons.note,
        title: 'Session Notes',
        subtitle: 'View your session recordings and notes',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SessionNotesScreen()),
        ),
      ),
      _MenuTile(
        icon: Icons.flash_on,
        title: 'Quick Doubt Sessions',
        subtitle: '5-10 min urgent help sessions',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const QuickDoubtScreen()),
        ),
      ),
      _MenuTile(
        icon: Icons.leaderboard,
        title: 'Leaderboard',
        subtitle: 'See top performing students',
        onTap: () => _showLeaderboard(context),
      ),
      _MenuTile(
        icon: Icons.card_giftcard,
        title: 'Free Trial Session',
        subtitle: 'Book your first free session',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const FreeTrialSessionScreen()),
        ),
      ),
    ];
  }

  List<Widget> _buildMentorMenuItems(BuildContext context) {
    return [
      _MenuTile(
        icon: Icons.edit,
        title: 'Profile Management',
        subtitle: 'Update your teaching profile',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const ProfileManagementScreen()),
        ),
      ),
      _MenuTile(
        icon: Icons.history,
        title: 'Student History',
        subtitle: 'View past sessions and notes',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const StudentHistoryScreen()),
        ),
      ),
      _MenuTile(
        icon: Icons.analytics,
        title: 'Performance Analytics',
        subtitle: 'View your teaching metrics',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const PerformanceAnalyticsScreen()),
        ),
      ),
      _MenuTile(
        icon: Icons.leaderboard,
        title: 'Mentor Rankings',
        subtitle: 'See top performing mentors',
        onTap: () => _showLeaderboard(context),
      ),
      _MenuTile(
        icon: Icons.emoji_events,
        title: 'Incentives & Bonuses',
        subtitle: 'View reward opportunities',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const IncentivesBonusesScreen()),
        ),
      ),
    ];
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showLeaderboard(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leaderboard'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView(
            children: const [
              _LeaderboardTile(
                  '🥇', 'Sarah Chen', '2,450 pts', 'Top Performer'),
              _LeaderboardTile(
                  '🥈', 'Alex Kumar', '2,180 pts', 'Mathematics Expert'),
              _LeaderboardTile(
                  '🥉', 'Maria Garcia', '1,920 pts', 'Physics Specialist'),
              _LeaderboardTile('4', 'James Wilson', '1,750 pts', 'Rising Star'),
              _LeaderboardTile('5', 'You', '1,680 pts', 'Keep going!'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                // Properly sign out through auth provider
                await ref.read(authProvider.notifier).signOut();
                // Navigation will be handled by router redirect logic automatically
                if (context.mounted) {
                  Navigator.of(context).pop(); // Close loading
                  // Don't manually navigate - let the router's redirect logic handle it
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop(); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logout failed: $e')),
                  );
                }
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final String rank;
  final String name;
  final String points;
  final String badge;

  const _LeaderboardTile(this.rank, this.name, this.points, this.badge);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(rank),
      ),
      title: Text(name),
      subtitle: Text(badge),
      trailing:
          Text(points, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
