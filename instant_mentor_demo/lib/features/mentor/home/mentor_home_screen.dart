import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/session.dart' as app_session;
import '../../../core/providers/sessions_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/routing/routing.dart';
import '../../../core/services/supabase_service.dart';
import '../../common/widgets/mentor_status_widget.dart';

final _studentNameProvider =
    FutureProvider.autoDispose.family<String, String>((ref, studentId) async {
  if (studentId.isEmpty) {
    return 'Student';
  }

  if (studentId.startsWith('demo_student_')) {
    return 'Demo Student';
  }

  try {
    final supabase = SupabaseService.instance;
    if (!supabase.isInitialized) {
      await supabase.init();
    }

    final client = supabase.client;

    final profile = await client
        .from('user_profiles')
        .select('full_name')
        .eq('id', studentId)
        .maybeSingle();

    final fullName = (profile?['full_name'] as String?)?.trim();
    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }

    final fallbackUser = await client
        .from('users')
        .select('email')
        .eq('id', studentId)
        .maybeSingle();

    final email = (fallbackUser?['email'] as String?)?.trim();
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }
  } catch (e) {
    debugPrint('⚠️ Failed to resolve student name for $studentId: $e');
  }

  return 'Student';
});

class MentorHomeScreen extends ConsumerStatefulWidget {
  const MentorHomeScreen({super.key});

  @override
  ConsumerState<MentorHomeScreen> createState() => _MentorHomeScreenState();
}

class _MentorHomeScreenState extends ConsumerState<MentorHomeScreen> {
  @override
  Widget build(BuildContext context) {
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
                              .withValues(alpha: 0.9),
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
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withValues(alpha: 0.3),
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
                  value: '₹250',
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
          const _MentorUpcomingSessionsWidget(),
        ],
      ),
    );
  }
}

class _MentorUpcomingSessionsWidget extends ConsumerWidget {
  const _MentorUpcomingSessionsWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final sessionsAsync = ref.watch(simpleUpcomingSessionsProvider);

    return sessionsAsync.when(
      data: (sessions) {
        final relevantSessions = _filterMentorSessions(
          sessions,
          mentorId: user?.id,
          isMentor: user?.role.isMentor ?? true,
        );

        if (relevantSessions.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No upcoming sessions yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When a student books time with you, it will show up here automatically.',
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

        final tiles = <Widget>[];
        for (var i = 0; i < relevantSessions.length; i++) {
          tiles.add(_MentorSessionTile(session: relevantSessions[i]));
          if (i < relevantSessions.length - 1) {
            tiles.add(const Divider(height: 1));
          }
        }

        return Card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: tiles,
          ),
        );
      },
      loading: () => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                'Loading your upcoming sessions...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
      error: (error, stackTrace) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red[400],
              ),
              const SizedBox(height: 12),
              Text(
                'We couldn\'t load sessions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.red[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please refresh to try again.',
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
}

class _MentorSessionTile extends ConsumerWidget {
  final app_session.Session session;

  const _MentorSessionTile({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentNameAsync = ref.watch(_studentNameProvider(session.studentId));

    return studentNameAsync.when(
      data: (studentName) {
        final subtitleParts = <String>[
          _formatSessionDate(session.scheduledTime),
          '${session.durationMinutes} min',
        ];

        final amountText = _formatAmount(session.amount);
        if (amountText.isNotEmpty) {
          subtitleParts.add(amountText);
        }

        final isStartingSoon = _isSessionStartingSoon(session.scheduledTime);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              _initialsFromName(studentName),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text('${session.subject} with $studentName'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitleParts.join(' • ')),
              if (isStartingSoon)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
              isStartingSoon ? 'Join Now' : 'Start',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        );
      },
      loading: () => ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        title: const Text('Loading student...'),
        subtitle: Text(
          '${_formatSessionDate(session.scheduledTime)} • ${session.durationMinutes} min',
        ),
      ),
      error: (error, stackTrace) {
        debugPrint(
            '⚠️ Failed to load student name for ${session.studentId}: $error');
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: const Icon(Icons.person_outline),
          ),
          title: Text('${session.subject} with Student'),
          subtitle: Text(
            '${_formatSessionDate(session.scheduledTime)} • ${session.durationMinutes} min',
          ),
          trailing: ElevatedButton(
            onPressed: () => context.go(AppRoutes.session(session.id)),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(60, 32),
            ),
            child: const Text('Start', style: TextStyle(fontSize: 12)),
          ),
        );
      },
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

List<app_session.Session> _filterMentorSessions(
  List<app_session.Session> sessions, {
  required String? mentorId,
  required bool isMentor,
}) {
  if (mentorId == null) {
    final demoSessions = sessions
        .where((session) => session.mentorId.startsWith('mentor_'))
        .toList();
    demoSessions.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return demoSessions;
  }

  final matchesAsMentor = sessions
      .where((session) => session.mentorId == mentorId)
      .toList()
    ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

  if (matchesAsMentor.isNotEmpty || isMentor) {
    return matchesAsMentor;
  }

  final matchesAsStudent = sessions
      .where((session) => session.studentId == mentorId)
      .toList()
    ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

  return matchesAsStudent;
}

String _formatSessionDate(DateTime sessionTime) {
  final now = DateTime.now();
  final isToday = sessionTime.year == now.year &&
      sessionTime.month == now.month &&
      sessionTime.day == now.day;

  final isTomorrow = sessionTime.year == now.year &&
      sessionTime.month == now.month &&
      sessionTime.day == now.day + 1;

  if (isToday) {
    return 'Today, ${DateFormat('h:mm a').format(sessionTime)}';
  }

  if (isTomorrow) {
    return 'Tomorrow, ${DateFormat('h:mm a').format(sessionTime)}';
  }

  return DateFormat('MMM d, h:mm a').format(sessionTime);
}

bool _isSessionStartingSoon(DateTime sessionTime) {
  final diff = sessionTime.difference(DateTime.now()).inMinutes;
  return diff <= 15 && diff >= -5;
}

String _initialsFromName(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  final initials = parts
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase())
      .take(2)
      .join();

  return initials.isEmpty ? '?' : initials;
}

String _formatAmount(double amount) {
  if (amount <= 0) {
    return '';
  }

  final hasDecimals = amount % 1 != 0;
  final formatted =
      hasDecimals ? amount.toStringAsFixed(2) : amount.toStringAsFixed(0);

  return '₹$formatted';
}
