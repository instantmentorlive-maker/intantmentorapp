import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/providers/mentor_provider.dart';
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
          Card(
            child: Column(
              children: [
                _UpcomingSessionTile(
                  mentorName: 'Dr. Sarah Smith',
                  subject: 'Mathematics',
                  time: 'Today, 3:00 PM',
                  duration: '60 min',
                  onJoin: () => context.go(AppRoutes.session('demo_session_1')),
                ),
                const Divider(height: 1),
                _UpcomingSessionTile(
                  mentorName: 'Prof. Raj Kumar',
                  subject: 'Physics',
                  time: 'Tomorrow, 10:00 AM',
                  duration: '45 min',
                  onJoin: () => context.go(AppRoutes.session('demo_session_2')),
                ),
              ],
            ),
          ),

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
  final String subject;
  final String time;
  final String duration;
  final VoidCallback onJoin;

  const _UpcomingSessionTile({
    required this.mentorName,
    required this.subject,
    required this.time,
    required this.duration,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(mentorName.split(' ').map((n) => n[0]).join()),
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
