import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/user_provider.dart';

import '../../../core/routing/routing.dart';

class MentorHomeScreen extends ConsumerWidget {
  const MentorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);

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
                    'Welcome, ${user?.name ?? 'Mentor'}!',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ready to help students today?',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimary
                              .withOpacity(0.9),
                        ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Status changed to Available'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Go Available'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          // Quick Actions (Book / Ask)
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: InkWell(
                    onTap: () => context.go(AppRoutes.studentBooking),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today,
                              size: 28, color: Colors.blue),
                          SizedBox(height: 8),
                          Text('Book Session'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: InkWell(
                    onTap: () => context.go(AppRoutes.mentorChat),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat, size: 28, color: Colors.orange),
                          SizedBox(height: 8),
                          Text('Ask Mentor'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Today's Stats
          Text(
            'Today\'s Overview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Sessions',
                  value: '5',
                  icon: Icons.school,
                  color: Colors.blue,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Earnings',
                  value: '\$250',
                  icon: Icons.monetization_on,
                  color: Colors.green,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Rating',
                  value: '4.8',
                  icon: Icons.star,
                  color: Colors.amber,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Upcoming Sessions
          Text(
            'Upcoming Sessions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Column(
              children: [
                _SessionTile(
                  studentName: 'Alex Johnson',
                  subject: 'Mathematics',
                  time: 'In 30 minutes',
                  duration: '60 min',
                  amount: '\$50',
                ),
                Divider(height: 1),
                _SessionTile(
                  studentName: 'Maria Garcia',
                  subject: 'Mathematics',
                  time: '2:00 PM',
                  duration: '45 min',
                  amount: '\$37.5',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final String studentName;
  final String subject;
  final String time;
  final String duration;
  final String amount;

  const _SessionTile({
    required this.studentName,
    required this.subject,
    required this.time,
    required this.duration,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(studentName.split(' ').map((n) => n[0]).join()),
      ),
      title: Text('$subject with $studentName'),
      subtitle: Text('$time • $duration • $amount'),
      trailing: ElevatedButton(
        onPressed: () => context.go(AppRoutes.session('demo_session_1')),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(60, 32),
        ),
        child: const Text('Start', style: TextStyle(fontSize: 12)),
      ),
    );
  }
}
