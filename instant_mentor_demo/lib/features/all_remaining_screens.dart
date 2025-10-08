// This file contains all the remaining screens for both Student and Mentor features
// to complete the Instant Mentor app implementation

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/scheduling_providers.dart';
import '../../core/providers/user_provider.dart';
import '../core/providers/ui_state_provider.dart';

// ============================================================================
// MENTOR SCREENS
// ============================================================================

class SessionRequestsScreen extends StatelessWidget {
  const SessionRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Incoming Requests',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          ...List.generate(3, (index) {
            final students = ['Alex Johnson', 'Maria Garcia', 'James Wilson'];
            final subjects = ['Mathematics', 'Physics', 'Mathematics'];
            final times = ['Now', '30 min ago', '1 hour ago'];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child:
                      Text(students[index].split(' ').map((n) => n[0]).join()),
                ),
                title: Text('${subjects[index]} Session'),
                subtitle:
                    Text('${students[index]} • Requested ${times[index]}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () =>
                          _showRequestResponse(context, students[index], false),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () =>
                          _showRequestResponse(context, students[index], true),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showRequestResponse(
      BuildContext context, String studentName, bool accepted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${accepted ? 'Accepted' : 'Declined'} request from $studentName'),
        backgroundColor: accepted ? Colors.green : Colors.red,
      ),
    );
  }
}

class MentorChatScreen extends StatelessWidget {
  const MentorChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Templates Section
        Container(
          margin: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.add_box,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Resource Templates',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Quickly share reusable resources with students'),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showTemplatesDialog(context),
                      icon: const Icon(Icons.folder),
                      label: const Text('Manage Templates'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Chat Threads
        Expanded(
          child: ListView.builder(
            itemCount: 3,
            itemBuilder: (context, index) {
              final students = ['Alex Johnson', 'Maria Garcia', 'James Wilson'];
              final subjects = ['Mathematics', 'Physics', 'Chemistry'];
              final times = ['5 min ago', '2 hours ago', '1 day ago'];
              final unread = [2, 0, 1];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                            students[index].split(' ').map((n) => n[0]).join()),
                      ),
                      if (unread[index] > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                                minWidth: 16, minHeight: 16),
                            child: Text(
                              '${unread[index]}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(students[index]),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subjects[index],
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12)),
                      const Text('Can you help me with this problem?'),
                    ],
                  ),
                  trailing: Text(times[index],
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  onTap: () => _openChat(context, students[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showTemplatesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resource Templates'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView(
            children: [
              const _TemplateItem(
                  'Quadratic Equations Formula', 'Mathematics', 15),
              const _TemplateItem('Newton\'s Laws Summary', 'Physics', 8),
              const _TemplateItem('Organic Chemistry Basics', 'Chemistry', 12),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Create New Template'),
                onTap: () {
                  Navigator.pop(context);
                  _showCreateTemplateDialog(context);
                },
              ),
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

  void _showCreateTemplateDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Template creation coming soon!')),
    );
  }

  void _openChat(BuildContext context, String studentName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening chat with $studentName')),
    );
  }
}

class _TemplateItem extends StatelessWidget {
  final String title;
  final String subject;
  final int usageCount;

  const _TemplateItem(this.title, this.subject, this.usageCount);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text('$subject • Used $usageCount times'),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: () {},
    );
  }
}

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Earnings Overview
          const Row(
            children: [
              Expanded(child: _EarningsCard('Today', '₹250', Colors.green)),
              SizedBox(width: 12),
              Expanded(
                  child: _EarningsCard('This Week', '₹1,250', Colors.blue)),
              SizedBox(width: 12),
              Expanded(
                  child: _EarningsCard('This Month', '₹4,800', Colors.purple)),
            ],
          ),

          const SizedBox(height: 24),
          Text(
            'Recent Earnings',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          const Card(
            child: Column(
              children: [
                _EarningsTile(
                    'Alex Johnson', 'Mathematics', 50.0, 'Today, 2:00 PM'),
                Divider(height: 1),
                _EarningsTile(
                    'Maria Garcia', 'Mathematics', 37.5, 'Today, 10:00 AM'),
                Divider(height: 1),
                _EarningsTile(
                    'James Wilson', 'Physics', 50.0, 'Yesterday, 4:00 PM'),
              ],
            ),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showWithdrawDialog(context),
              icon: const Icon(Icons.account_balance),
              label: const Text('Withdraw Earnings'),
            ),
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Withdrawal feature coming soon!')),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;

  const _EarningsCard(this.title, this.amount, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(amount,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _EarningsTile extends StatelessWidget {
  final String studentName;
  final String subject;
  final double amount;
  final String date;

  const _EarningsTile(this.studentName, this.subject, this.amount, this.date);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.green.withOpacity(0.1),
        child: const Icon(Icons.monetization_on, color: Colors.green),
      ),
      title: Text('Session with $studentName'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$subject • 1 hour'),
          Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
      trailing: Text(
        '+₹${amount.toStringAsFixed(2)}',
        style: const TextStyle(
            fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
      ),
    );
  }
}

class AvailabilityScreen extends ConsumerStatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen> {
  late Map<String, bool> weeklySchedule;
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    // Initialize with default values
    weeklySchedule = {
      'Monday': true,
      'Tuesday': true,
      'Wednesday': true,
      'Thursday': true,
      'Friday': true,
      'Saturday': true,
      'Sunday': false,
    };
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    setState(() => isLoading = true);
    try {
      final authState = ref.read(authProvider);
      if (authState.user == null) return;

      // Get mentor profile ID
      final mentorProfile = await Supabase.instance.client
          .from('mentor_profiles')
          .select('id')
          .eq('user_id', authState.user!.id)
          .maybeSingle();

      if (mentorProfile != null) {
        final mentorId = mentorProfile['id'] as String;

        // Load existing availability
        final availability = await ref
            .read(schedulingServiceProvider)
            .getWeeklyAvailability(mentorId);

        // Convert to our format (0=Monday, 1=Tuesday, etc.)
        final days = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ];
        for (int i = 0; i < days.length; i++) {
          final dayData = availability[i];
          if (dayData != null) {
            weeklySchedule[days[i]] = dayData.enabled;
          }
        }
      }
    } catch (e) {
      setState(() => errorMessage = 'Failed to load availability: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _saveAvailability() async {
    setState(() => isSaving = true);
    try {
      final authState = ref.read(authProvider);
      if (authState.user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to save availability')),
        );
        return;
      }

      // Get mentor profile ID
      final mentorProfile = await Supabase.instance.client
          .from('mentor_profiles')
          .select('id')
          .eq('user_id', authState.user!.id)
          .maybeSingle();

      if (mentorProfile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Mentor profile not found. Please complete your profile first.')),
        );
        return;
      }

      final mentorId = mentorProfile['id'] as String;

      // Convert our format to the service format
      final days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      final availabilityMap =
          <int, ({TimeOfDay start, TimeOfDay end, bool enabled})>{};

      for (int i = 0; i < days.length; i++) {
        availabilityMap[i] = (
          start: const TimeOfDay(hour: 9, minute: 0), // Default 9 AM
          end: const TimeOfDay(hour: 18, minute: 0), // Default 6 PM
          enabled: weeklySchedule[days[i]] ?? false,
        );
      }

      await ref.read(schedulingServiceProvider).setWeeklyAvailability(
            mentorId: mentorId,
            days: availabilityMap,
          );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Availability saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save availability: $e')),
      );
    } finally {
      setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAvailable = ref.watch(mentorAvailabilityProvider);

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Status',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => ref
                              .read(mentorAvailabilityProvider.notifier)
                              .state = true,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isAvailable
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color:
                                      isAvailable ? Colors.green : Colors.grey),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color:
                                      isAvailable ? Colors.green : Colors.grey,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Available',
                                  style: TextStyle(
                                    color: isAvailable
                                        ? Colors.green
                                        : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => ref
                              .read(mentorAvailabilityProvider.notifier)
                              .state = false,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: !isAvailable
                                  ? Colors.red.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color:
                                      !isAvailable ? Colors.red : Colors.grey),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.do_not_disturb,
                                  color:
                                      !isAvailable ? Colors.red : Colors.grey,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Busy',
                                  style: TextStyle(
                                    color:
                                        !isAvailable ? Colors.red : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          Text(
            'Weekly Schedule',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          ...weeklySchedule.entries.map((entry) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(entry.key),
                subtitle: const Text('9:00 AM - 6:00 PM'),
                trailing: Switch(
                  value: entry.value,
                  onChanged: (value) {
                    setState(() {
                      weeklySchedule[entry.key] = value;
                    });
                  },
                ),
              ),
            );
          }),

          const SizedBox(height: 24),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSaving ? null : _saveAvailability,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Save Availability',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),

          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// SHARED SCREENS
// ============================================================================

class LiveSessionScreen extends StatelessWidget {
  final String sessionId;

  const LiveSessionScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Session'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.mic_off),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.videocam_off),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.call_end),
            color: Colors.red,
            onPressed: () => context.pop(),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Video Area
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              color: Colors.grey[900],
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam, size: 64, color: Colors.white54),
                    SizedBox(height: 16),
                    Text(
                      'Video call will be available here',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Whiteboard Area
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey),
              ),
              child: Column(
                children: [
                  // Whiteboard Toolbar
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {},
                          tooltip: 'Pen',
                        ),
                        IconButton(
                          icon: const Icon(Icons.crop_square),
                          onPressed: () {},
                          tooltip: 'Rectangle',
                        ),
                        IconButton(
                          icon: const Icon(Icons.circle_outlined),
                          onPressed: () {},
                          tooltip: 'Circle',
                        ),
                        IconButton(
                          icon: const Icon(Icons.text_fields),
                          onPressed: () {},
                          tooltip: 'Text',
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {},
                          tooltip: 'Clear',
                        ),
                        IconButton(
                          icon: const Icon(Icons.download),
                          onPressed: () => _exportWhiteboard(context),
                          tooltip: 'Export',
                        ),
                      ],
                    ),
                  ),

                  // Whiteboard Canvas
                  const Expanded(
                    child: SizedBox(
                      width: double.infinity,
                      child: Center(
                        child: Text(
                          'Interactive Whiteboard\n(Drawing functionality will be implemented here)',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Chat Panel
          Container(
            height: 150,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.chat),
                      SizedBox(width: 8),
                      Text('Session Chat'),
                    ],
                  ),
                ),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Center(
                      child: Text(
                        'Session chat messages will appear here',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _exportWhiteboard(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Whiteboard exported as PDF!'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

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
            onTap: () => _showComingSoon(context, 'Profile management'),
          ),
          _MenuTile(
            icon: Icons.settings,
            title: 'Settings',
            onTap: () => _showComingSoon(context, 'Settings'),
          ),
          _MenuTile(
            icon: Icons.help,
            title: 'Help & Support',
            onTap: () => _showComingSoon(context, 'Help & Support'),
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
        onTap: () => _showComingSoon(context, 'Advanced mentor search'),
      ),
      _MenuTile(
        icon: Icons.note,
        title: 'Session Notes',
        subtitle: 'View your session recordings and notes',
        onTap: () => _showComingSoon(context, 'Session notes'),
      ),
      _MenuTile(
        icon: Icons.flash_on,
        title: 'Quick Doubt Sessions',
        subtitle: '5-10 min urgent help sessions',
        onTap: () => _showComingSoon(context, 'Quick doubt sessions'),
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
        onTap: () => _showComingSoon(context, 'Free trial booking'),
      ),
    ];
  }

  List<Widget> _buildMentorMenuItems(BuildContext context) {
    return [
      _MenuTile(
        icon: Icons.edit,
        title: 'Profile Management',
        subtitle: 'Update your teaching profile',
        onTap: () => _showComingSoon(context, 'Profile management'),
      ),
      _MenuTile(
        icon: Icons.history,
        title: 'Student History',
        subtitle: 'View past sessions and notes',
        onTap: () => _showComingSoon(context, 'Student history'),
      ),
      _MenuTile(
        icon: Icons.analytics,
        title: 'Performance Analytics',
        subtitle: 'View your teaching metrics',
        onTap: () => _showComingSoon(context, 'Performance analytics'),
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
        onTap: () => _showComingSoon(context, 'Incentives program'),
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
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('Logout'),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout?\n\nYour session will end and you\'ll need to login again.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              // Close dialog first
              Navigator.pop(dialogContext);

              // Show loading indicator
              if (!context.mounted) return;

              // Use a simpler loading approach
              final navigator = Navigator.of(context, rootNavigator: true);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loadingContext) => PopScope(
                  canPop: false,
                  child: Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Logging out...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );

              try {
                debugPrint('🚀 Starting logout process...');

                // Sign out through auth provider
                await ref.read(authProvider.notifier).signOut();

                debugPrint('✅ Logout successful, waiting for state update...');

                // Give auth state time to update
                await Future.delayed(const Duration(milliseconds: 500));

                // Try to close loading dialog safely
                try {
                  if (navigator.mounted) {
                    navigator.pop();
                  }
                } catch (e) {
                  debugPrint('⚠️ Could not close loading dialog: $e');
                }

                // Let GoRouter's redirect handle navigation automatically
                // No need to manually navigate - the auth state change will trigger redirect
                debugPrint('✅ Logout completed, GoRouter will handle redirect');
              } catch (e, stackTrace) {
                debugPrint('❌ Logout error: $e');
                debugPrint('Stack trace: $stackTrace');

                // Close loading dialog
                try {
                  if (navigator.mounted) {
                    navigator.pop();
                  }
                } catch (_) {
                  // Ignore if can't close
                }

                // Show error
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Logout failed: $e'),
                      backgroundColor: Colors.red,
                      action: SnackBarAction(
                        label: 'Retry',
                        textColor: Colors.white,
                        onPressed: () => _showLogoutDialog(context, ref),
                      ),
                    ),
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

class LegacyMentorProfileScreen extends StatelessWidget {
  final String mentorId;

  const LegacyMentorProfileScreen({super.key, required this.mentorId});

  @override
  Widget build(BuildContext context) {
    // Mock mentor data - in real app, this would be fetched based on mentorId
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mentor Profile'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: const Text(
                        'DS',
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Dr. Sarah Smith',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Mathematics Expert • 8+ years experience',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Icon(Icons.star, color: Colors.amber[600]),
                            const Text('4.8',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const Text('Rating',
                                style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        const Column(
                          children: [
                            Icon(Icons.school, color: Colors.blue),
                            Text('245',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('Sessions', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        const Column(
                          children: [
                            Icon(Icons.verified, color: Colors.green),
                            Text('Verified',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('Expert', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // About Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'About',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Experienced mathematics mentor with 8+ years of teaching JEE and NEET aspirants. PhD in Mathematics from IIT Delhi. Specialized in helping students overcome math anxiety and build strong problem-solving skills.',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Specializations',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        'Mathematics',
                        'JEE',
                        'NEET',
                        'Calculus',
                        'Algebra'
                      ].map((tag) {
                        return Chip(label: Text(tag));
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/student/booking'),
                    icon: const Icon(Icons.book_online),
                    label: const Text('Book Session'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/student/chat'),
                    icon: const Icon(Icons.chat),
                    label: const Text('Send Message'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
