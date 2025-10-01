import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/user_provider.dart';
import '../../common/widgets/mentor_status_widget.dart';

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
                  const SizedBox(height: 12),
                  // Current Status Indicator
                  Consumer(
                    builder: (context, ref, child) {
                      final mentorStatus = ref.watch(mentorStatusProvider);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimary
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: mentorStatus.isAvailable
                                    ? Colors.green
                                    : Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Current Status: ${mentorStatus.statusMessage}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Consumer(
                    builder: (context, ref, child) {
                      final mentorStatus = ref.watch(mentorStatusProvider);
                      final isAvailable = mentorStatus.isAvailable;

                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // Toggle availability status
                            final newAvailability = !isAvailable;
                            final newMessage = newAvailability
                                ? 'Available for sessions'
                                : 'Currently busy';

                            // Always update local status first
                            ref
                                .read(mentorStatusProvider.notifier)
                                .updateStatus(
                                  newAvailability,
                                  newMessage,
                                );

                            // Show immediate feedback for local status update
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '✅ Status changed to ${newAvailability ? 'Available' : 'Busy'}'),
                                  backgroundColor: newAvailability
                                      ? Colors.green
                                      : Colors.orange,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }

                            // Try to send update via WebSocket (non-blocking)
                            try {
                              final webSocketService =
                                  ref.read(webSocketServiceProvider);
                              await webSocketService.updateMentorStatus(
                                isAvailable: newAvailability,
                                statusMessage: newMessage,
                                statusData: {
                                  'userId': ref.read(userProvider)?.id,
                                  'timestamp': DateTime.now().toIso8601String(),
                                },
                              );
                              debugPrint(
                                  '✅ WebSocket status update sent successfully');
                            } catch (e) {
                              // WebSocket error - don't show error to user since local update worked
                              debugPrint(
                                  '⚠️ WebSocket update failed (local status still updated): $e');
                              // Optional: Could show a subtle warning
                              // ScaffoldMessenger.of(context).showSnackBar(
                              //   SnackBar(
                              //     content: Text('Status updated locally (sync may be delayed)'),
                              //     backgroundColor: Colors.amber,
                              //     duration: const Duration(seconds: 1),
                              //   ),
                              // );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isAvailable
                                ? Colors.orange
                                : Theme.of(context).colorScheme.onPrimary,
                            foregroundColor: isAvailable
                                ? Colors.white
                                : Theme.of(context).colorScheme.primary,
                          ),
                          icon: Icon(
                            isAvailable
                                ? Icons.pause_circle
                                : Icons.check_circle,
                          ),
                          label: Text(
                            isAvailable ? 'Go Busy' : 'Go Available',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
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
