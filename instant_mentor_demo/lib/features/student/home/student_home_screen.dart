import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/session.dart' as app_session;
import '../../../core/providers/mentor_provider.dart';
import '../../../core/providers/sessions_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/routing/app_routes.dart';

class StudentHomeScreen extends ConsumerWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final topMentors = ref.watch(topRatedMentorsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Card(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primaryContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, ${user?.name ?? 'Mohit'}!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ready to learn something new today?',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimary
                              .withOpacity(0.9),
                        ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Quick Actions
          Text('Quick Actions',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _QuickActionCard(
                icon: Icons.book_online,
                title: 'Book Session',
                color: Colors.blue,
                onTap: () => context.go(AppRoutes.studentBooking),
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _QuickActionCard(
                icon: Icons.help_outline,
                title: 'Ask Mentor',
                color: Colors.orange,
                onTap: () => context.go(AppRoutes.studentChat),
              )),
            ],
          ),

          const SizedBox(height: 24),

          // Upcoming Sessions
          Text('Upcoming Sessions',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const _UpcomingSessionsWidget(),

          const SizedBox(height: 24),

          // Top Mentors
          Text('Top Mentors',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: topMentors.length,
              itemBuilder: (context, index) {
                final mentor = topMentors[index];
                return _MentorCard(
                  mentor: mentor,
                  onTap: () => context.go(AppRoutes.mentorProfile(mentor.id)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingSessionTile extends StatelessWidget {
  final String mentorName;
  final String mentorId;
  final String subject;
  final String time;
  final String duration;
  final VoidCallback onJoin;

  const _UpcomingSessionTile({
    required this.mentorName,
    required this.mentorId,
    required this.subject,
    required this.time,
    required this.duration,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: GestureDetector(
        onTap: () => context.go(AppRoutes.mentorProfile(mentorId)),
        child: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            mentorName.split(' ').map((n) => n[0]).join(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      title: Text('$subject with $mentorName'),
      subtitle: Text('$time • $duration'),
      trailing: ElevatedButton(
        onPressed: onJoin,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(60, 32),
        ),
        child: const Text('Join', style: TextStyle(fontSize: 12)),
      ),
    );
  }
}

class _MentorCard extends StatelessWidget {
  final mentor;
  final VoidCallback onTap;

  const _MentorCard({
    required this.mentor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(mentor.name.split(' ').map((n) => n[0]).join()),
                ),
                const SizedBox(height: 8),
                Text(
                  mentor.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  mentor.specializations.first,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, size: 14, color: Colors.amber[600]),
                    const SizedBox(width: 2),
                    Text('${mentor.rating}',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
                const Spacer(),
                Text(
                  '\$${mentor.hourlyRate}/hr',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpcomingSessionsWidget extends ConsumerWidget {
  const _UpcomingSessionsWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingSessionsAsync = ref.watch(simpleUpcomingSessionsProvider);

    return upcomingSessionsAsync.when(
      data: (sessions) {
        if (sessions.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No upcoming sessions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Book a session with a mentor to get started!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          child: Column(
            children: sessions
                .cast<app_session.Session>()
                .map<Widget>(
                    (session) => _buildSessionTile(context, ref, session))
                .expand((widget) => [widget, const Divider(height: 1)])
                .take(sessions.length * 2 - 1) // Remove last divider
                .toList(),
          ),
        );
      },
      loading: () => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                'Loading your sessions...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
      error: (error, stack) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red[400],
              ),
              const SizedBox(height: 12),
              Text(
                'Failed to load sessions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.red[600],
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please check your connection and try again.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.refresh(simpleUpcomingSessionsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionTile(
      BuildContext context, WidgetRef ref, app_session.Session session) {
    final mentors = ref.watch(mentorsProvider);
    final matched = mentors.where((m) => m.id == session.mentorId).toList();
    final mentor = matched.isNotEmpty ? matched.first : null;

    // Handle demo mentors
    String displayName;
    if (mentor != null) {
      displayName = mentor.name;
    } else if (session.mentorId.startsWith('mentor_')) {
      // Demo mentor - get name from known demo mentors
      final demoMentorNames = {
        'mentor_1': 'Dr. Sarah Smith',
        'mentor_2': 'Prof. Raj Kumar',
        'mentor_3': 'Dr. Priya Sharma',
        'mentor_4': 'Mr. Vikash Singh',
        'mentor_5': 'Dr. Anjali Gupta',
      };
      displayName = demoMentorNames[session.mentorId] ?? 'Demo Mentor';
    } else {
      displayName = 'Mentor (${session.mentorId})';
    }

    final now = DateTime.now();
    final sessionTime = session.scheduledTime;
    final isToday = sessionTime.year == now.year &&
        sessionTime.month == now.month &&
        sessionTime.day == now.day;
    final isTomorrow = sessionTime.year == now.year &&
        sessionTime.month == now.month &&
        sessionTime.day == now.day + 1;

    String timeText;
    if (isToday) {
      timeText = 'Today, ${DateFormat('h:mm a').format(sessionTime)}';
    } else if (isTomorrow) {
      timeText = 'Tomorrow, ${DateFormat('h:mm a').format(sessionTime)}';
    } else {
      timeText = DateFormat('MMM d, h:mm a').format(sessionTime);
    }

    // Check if session is starting soon (within 15 minutes)
    final isStartingSoon = sessionTime.difference(now).inMinutes <= 15 &&
        sessionTime.difference(now).inMinutes >= -5; // Allow 5 minutes late

    final displayMentorId = mentor?.id ?? session.mentorId;
    final displaySubject = session.subject;

    return ListTile(
      leading: GestureDetector(
        onTap: () => context.go(AppRoutes.mentorProfile(displayMentorId)),
        child: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            displayName.split(' ').map((n) => n.isNotEmpty ? n[0] : '').join(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      title: Text('$displaySubject with $displayName'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$timeText • ${session.durationMinutes} min'),
          if (isStartingSoon)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Starting soon!',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.green[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      trailing: ElevatedButton(
        onPressed: () => context.go(AppRoutes.session(session.id)),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(60, 32),
          backgroundColor: isStartingSoon
              ? Colors.green
              : Theme.of(context).colorScheme.primary,
        ),
        child: Text(
          isStartingSoon ? 'Join Now' : 'Join',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}
